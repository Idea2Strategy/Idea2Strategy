[CmdletBinding()]
param(
    [string]$BackupRoot,
    [switch]$Force,
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($BackupRoot)) {
    $BackupRoot = Join-Path $root '.harness/local/artifacts/backups/baseline-2026-08-13'
}
$BackupRoot = [System.IO.Path]::GetFullPath($BackupRoot)
$manifestPath = Join-Path $BackupRoot 'backup-manifest.json'
$dumpPath = Join-Path $BackupRoot 'database.dump'
$receiptPath = Join-Path $BackupRoot 's3-current-receipts.json'
$minioReceiptPath = Join-Path $BackupRoot 'local-minio-import-receipt.json'
$currentObjects = Join-Path $BackupRoot 's3-current'
$envPath = Join-Path $root '.env.docker'
$composePath = Join-Path $root 'compose.back.yml'
$policySeedPath = Join-Path $root 'proposals/development-runtime-policy/artifacts/policy-seed.sql'

foreach ($required in @($manifestPath, $dumpPath, $receiptPath, $minioReceiptPath, $currentObjects, $envPath, $composePath, $policySeedPath)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Required local baseline artifact is missing: $required"
    }
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.schema_version -ne 1) {
    throw "Unsupported backup manifest version: $($manifest.schema_version)"
}
$dumpHash = (Get-FileHash -LiteralPath $dumpPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($dumpHash -cne [string]$manifest.database.sha256) {
    throw "Database dump checksum mismatch: $dumpHash"
}
$currentReceipts = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
$minioReceipt = Get-Content -LiteralPath $minioReceiptPath -Raw | ConvertFrom-Json
$currentFiles = @(Get-ChildItem -LiteralPath $currentObjects -Filter '*.object' -File)
if ($currentReceipts.Count -ne [int]$manifest.s3.current_versions -or
    $currentFiles.Count -ne [int]$manifest.s3.current_versions) {
    throw "S3 current-object count does not match the backup manifest."
}

if ($ValidateOnly) {
    [pscustomobject]@{
        status = 'validated'
        database_sha256 = $dumpHash
        current_objects = $currentFiles.Count
        current_bytes = [long]$manifest.s3.current_bytes
    } | ConvertTo-Json -Compress
    exit 0
}

if (-not $Force) {
    throw 'Restoring replaces only the active PostgreSQL, MinIO, and LocalStack volumes. Re-run with -Force after reviewing the validated backup.'
}

function Get-EnvValue([string]$Name) {
    $line = Get-Content -LiteralPath $envPath | Where-Object { $_ -match "^$([regex]::Escape($Name))=" } | Select-Object -Last 1
    if ([string]::IsNullOrWhiteSpace($line)) {
        throw "Missing $Name in .env.docker"
    }
    return $line.Substring($line.IndexOf('=') + 1)
}

$database = Get-EnvValue 'POSTGRES_DB'
$user = Get-EnvValue 'POSTGRES_USER'
$postgresCredential = Get-EnvValue 'POSTGRES_PASSWORD'
$minioUser = Get-EnvValue 'MINIO_ROOT_USER'
$minioCredential = Get-EnvValue 'MINIO_ROOT_PASSWORD'
$localBucket = Get-EnvValue 'S3_MARKET_DATA_BUCKET'
if ([string]::IsNullOrWhiteSpace($localBucket)) { throw 'S3_MARKET_DATA_BUCKET must name the local Backtest input bucket.' }
$expectedVolumes = @(
    'idea2strategy-postgres-data',
    'idea2strategy-minio-data',
    'idea2strategy-localstack-data'
)
$importSuffix = [guid]::NewGuid().ToString('N').Substring(0, 12)
$importVolume = "idea2strategy-baseline-import-$importSuffix"
$mappingPath = Join-Path $root ".harness/local/tmp/baseline-import-$importSuffix.tsv"
$versionListingPath = Join-Path $root ".harness/local/tmp/baseline-minio-versions-$importSuffix.jsonl"
$versionMappingPath = Join-Path $root ".harness/local/tmp/baseline-object-versions-$importSuffix.tsv"
$importScriptPath = Join-Path $root ".harness/local/tmp/baseline-import-$importSuffix.sh"
$minioImportScriptPath = Join-Path $root ".harness/local/tmp/baseline-minio-import-$importSuffix.sh"
$importVolumeCreated = $false

& (Join-Path $PSScriptRoot 'prepare-flyway-bundle.ps1') | Out-Host
if ($LASTEXITCODE -ne 0) { throw 'Unable to prepare the rebased Flyway bundle.' }

Push-Location $root
try {
    docker compose --env-file $envPath -f $composePath down --remove-orphans
    if ($LASTEXITCODE -ne 0) { throw 'Unable to stop the local backend stack.' }

    foreach ($volume in $expectedVolumes) {
        $present = docker volume ls --quiet --filter "name=^${volume}$"
        if (-not [string]::IsNullOrWhiteSpace(($present -join ''))) {
            docker volume rm $volume | Out-Host
            if ($LASTEXITCODE -ne 0) { throw "Unable to remove exact local volume: $volume" }
        }
    }

    docker compose --env-file $envPath -f $composePath up -d --wait postgres minio localstack
    if ($LASTEXITCODE -ne 0) { throw 'Local storage services did not become healthy.' }
    $minioNetworks = @(docker inspect --format '{{range $name, $network := .NetworkSettings.Networks}}{{$name}}{{println}}{{end}}' idea2strategy-minio) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($LASTEXITCODE -ne 0 -or $minioNetworks.Count -ne 1) {
        throw "Expected exactly one MinIO container network, found: $($minioNetworks -join ', ')"
    }
    $minioNetwork = ([string]($minioNetworks | Select-Object -First 1)).Trim()
    docker compose --env-file $envPath -f $composePath rm -f flyway | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Unable to clear the completed Flyway one-shot container.' }
    docker compose --env-file $envPath -f $composePath up --no-deps flyway
    if ($LASTEXITCODE -ne 0) { throw 'Flyway could not apply the rebased V1.' }

    $mappingLines = foreach ($receipt in $currentReceipts) {
        $relativeFile = [string]$receipt.file
        $objectKey = [string]$receipt.key
        if (-not $relativeFile.StartsWith('s3-current/') -or
            [string]::IsNullOrWhiteSpace($objectKey) -or
            $relativeFile.Contains("`t") -or $relativeFile.Contains("`n") -or $relativeFile.Contains("`r") -or
            $objectKey.Contains("`t") -or $objectKey.Contains("`n") -or $objectKey.Contains("`r")) {
            throw "Unsafe S3 current-object receipt: $relativeFile"
        }
        $sourceName = $relativeFile.Substring('s3-current/'.Length)
        $sourcePath = Join-Path $currentObjects $sourceName
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            throw "S3 current-object payload is missing: $sourcePath"
        }
        "$sourceName`t$objectKey"
    }
    $mappingEncoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($mappingPath, ($mappingLines -join "`n") + "`n", $mappingEncoding)
    $importScript = @'
set -eu
tab="$(printf '\t')"
while IFS="$tab" read -r file key; do
    target="/import/$key"
    mkdir -p "$(dirname "$target")"
    cp "/backup/$file" "$target"
done < /mapping.tsv
'@
    [System.IO.File]::WriteAllText($importScriptPath, $importScript.Replace("`r`n", "`n"), $mappingEncoding)
    $minioImportScript = @'
set -eu
mc alias set local http://minio:9000 "$MINIO_ALIAS_USER" "$MINIO_ALIAS_PASSWORD" >/dev/null
mc mb --ignore-existing "local/$MINIO_ALIAS_BUCKET" >/dev/null
mc version enable "local/$MINIO_ALIAS_BUCKET" >/dev/null
mc mirror --quiet --overwrite /import "local/$MINIO_ALIAS_BUCKET"
mc ls --versions --recursive --json "local/$MINIO_ALIAS_BUCKET" > /versions/objects.jsonl
mc find "local/$MINIO_ALIAS_BUCKET" --print '{key}' | wc -l
'@
    [System.IO.File]::WriteAllText($minioImportScriptPath, $minioImportScript.Replace("`r`n", "`n"), $mappingEncoding)

    docker volume create --label 'com.idea2strategy.local-baseline-import=true' $importVolume | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Unable to create the temporary baseline import volume.' }
    $importVolumeCreated = $true
    docker run --rm `
        -v "${currentObjects}:/backup:ro" `
        -v "${mappingPath}:/mapping.tsv:ro" `
        -v "${importScriptPath}:/import.sh:ro" `
        -v "${importVolume}:/import" `
        alpine:3.20 sh /import.sh
    if ($LASTEXITCODE -ne 0) { throw 'Unable to reconstruct the S3 object-key tree.' }

    [System.IO.File]::WriteAllText($versionListingPath, '', $mappingEncoding)
    $minioImportOutput = @(docker run --rm --network $minioNetwork `
        -e "MINIO_ALIAS_USER=$minioUser" `
        -e "MINIO_ALIAS_PASSWORD=$minioCredential" `
        -e "MINIO_ALIAS_BUCKET=$localBucket" `
        -v "${importVolume}:/import:ro" `
        -v "${versionListingPath}:/versions/objects.jsonl" `
        -v "${minioImportScriptPath}:/minio-import.sh:ro" `
        --entrypoint /bin/sh minio/mc /minio-import.sh)
    $minioImportExitCode = $LASTEXITCODE
    $importedObjectCount = if ($minioImportOutput.Count -gt 0) {
        [int](([string]($minioImportOutput | Select-Object -Last 1)).Trim())
    } else { 0 }
    if ($minioImportExitCode -ne 0 -or $importedObjectCount -ne [int]$manifest.s3.current_versions) {
        throw "Imported MinIO object count mismatch: expected $($manifest.s3.current_versions), found $importedObjectCount"
    }
    $versionLines = foreach ($line in Get-Content -LiteralPath $versionListingPath) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $entry = $line | ConvertFrom-Json
        if ($entry.type -eq 'file' -and $entry.versionId -and $entry.versionId -ne 'null') {
            if ([string]$entry.key -match "`t|`r|`n" -or [string]$entry.versionId -match "`t|`r|`n") {
                throw 'MinIO returned an unsafe object key or version identifier.'
            }
            "$($entry.key)`t$($entry.versionId)"
        }
    }
    if ($versionLines.Count -ne $importedObjectCount) {
        throw "MinIO immutable-version count mismatch: expected $importedObjectCount, found $($versionLines.Count)"
    }
    [System.IO.File]::WriteAllText($versionMappingPath, ($versionLines -join "`n") + "`n", $mappingEncoding)

    docker cp $dumpPath 'idea2strategy-postgres:/tmp/idea2strategy-baseline.dump'
    if ($LASTEXITCODE -ne 0) { throw 'Unable to copy the database dump into PostgreSQL.' }
    docker exec idea2strategy-postgres dropdb -U $user --if-exists idea2strategy_backup_stage
    docker exec idea2strategy-postgres createdb -U $user idea2strategy_backup_stage
    docker exec idea2strategy-postgres pg_restore --exit-on-error --no-owner --no-privileges `
        -U $user -d idea2strategy_backup_stage /tmp/idea2strategy-baseline.dump | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Unable to restore the legacy backup into the staging database.' }

    $transformPath = Join-Path $root 'scripts/sql/restore-local-baseline-data.sql'
    docker cp $transformPath 'idea2strategy-postgres:/tmp/restore-local-baseline-data.sql'
    if ($LASTEXITCODE -ne 0) { throw 'Unable to copy the baseline transformation into PostgreSQL.' }
    docker exec idea2strategy-postgres psql -v ON_ERROR_STOP=1 `
        -v "backup_user=$user" -v "backup_password=$postgresCredential" -v "local_bucket=$localBucket" `
        -U $user -d $database -f /tmp/restore-local-baseline-data.sql | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Legacy baseline transformation failed.' }

    $versionSqlPath = Join-Path $root 'scripts/sql/rebind-local-object-versions.sql'
    docker cp $versionMappingPath 'idea2strategy-postgres:/tmp/local-object-versions.tsv'
    docker cp $versionSqlPath 'idea2strategy-postgres:/tmp/rebind-local-object-versions.sql'
    if ($LASTEXITCODE -ne 0) { throw 'Unable to copy the MinIO version mapping into PostgreSQL.' }
    docker exec idea2strategy-postgres psql -v ON_ERROR_STOP=1 `
        -v "local_bucket=$localBucket" -U $user -d $database `
        -f /tmp/rebind-local-object-versions.sql | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Unable to bind restored storage rows to immutable MinIO versions.' }

    $encodedCredential = [uri]::EscapeDataString($postgresCredential)
    $env:LOCAL_FEATURE_DATABASE_URL = "postgresql+psycopg://${user}:${encodedCredential}@127.0.0.1:15432/${database}"
    uv run --project (Join-Path $root 'backtest-engine') python `
        (Join-Path $root 'scripts/local/full_range_manifest.py') | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Full-range adjusted 30m manifest registration failed.' }

    # V1 intentionally contains schema/reference data only. Restore the reviewed
    # development execution-policy catalog after importing the retired AWS data;
    # otherwise a strategy can validate but cannot release or enqueue its
    # automatic official backtest.
    docker cp $policySeedPath 'idea2strategy-postgres:/tmp/local-backtest-policy-seed.sql'
    if ($LASTEXITCODE -ne 0) { throw 'Unable to copy the local backtest policy seed into PostgreSQL.' }
    docker exec idea2strategy-postgres psql -v ON_ERROR_STOP=1 `
        -U $user -d $database -f /tmp/local-backtest-policy-seed.sql | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Local backtest policy seed failed.' }
    docker exec idea2strategy-postgres dropdb -U $user idea2strategy_backup_stage

    $checks = @{
        storage_objects = 'SELECT count(*) FROM storage.objects;'
        dataset_manifests = 'SELECT count(*) FROM market_data.dataset_manifests;'
        dataset_objects = 'SELECT count(*) FROM market_data.dataset_objects;'
        dataset_lineage = 'SELECT count(*) FROM market_data.dataset_lineage;'
        quality_incidents = 'SELECT count(*) FROM market_data.quality_incidents;'
        pipeline_runs = 'SELECT count(*) FROM market_data.pipeline_runs;'
    }
    foreach ($name in $checks.Keys) {
        $actual = (docker exec idea2strategy-postgres psql -U $user -d $database -Atc $checks[$name]).Trim()
        $expectedValue = [long]$manifest.database.row_counts.$name
        if ($name -eq 'dataset_manifests') { $expectedValue += 1 }
        if ($name -eq 'dataset_objects') { $expectedValue += 88 }
        if ($name -eq 'dataset_lineage') { $expectedValue += 11 }
        $expected = [string]$expectedValue
        if ($LASTEXITCODE -ne 0 -or $actual -cne $expected) {
            throw "Restored row count mismatch for ${name}: expected $expected, found $actual"
        }
    }

    docker compose --env-file $envPath -f $composePath up -d --wait redis
    if ($LASTEXITCODE -ne 0) { throw 'Local Redis did not become healthy for market-history projection.' }
    $env:LOCAL_HISTORY_DATABASE_URL = $env:LOCAL_FEATURE_DATABASE_URL
    $env:LOCAL_HISTORY_STATE_ROOT = Join-Path $root '.harness/local/tmp/market-history-projection'
    $env:LOCAL_HISTORY_S3_ENDPOINT = 'http://127.0.0.1:19000'
    $env:LOCAL_HISTORY_S3_BUCKET = $localBucket
    $env:LOCAL_HISTORY_REDIS_URI = 'redis://127.0.0.1:16379/0'
    $env:AWS_ACCESS_KEY_ID = $minioUser
    $env:AWS_SECRET_ACCESS_KEY = $minioCredential
    $env:AWS_REGION = 'ap-northeast-2'
    uv run --project (Join-Path $root 'data-pipeline') python `
        (Join-Path $root 'scripts/local/project-local-market-history.py') | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Local three-month market-history projection failed.' }

    # The UI publishes RSI at four strategy clocks. Materialize the compact AAPL/MSFT
    # development window locally so a clean restore can release and backtest those cards
    # without the retired D: drive or an AWS feature worker.
    $env:LOCAL_FEATURE_ROOT = Join-Path $root '.harness/local/tmp/feature-materialization'
    $env:LOCAL_FEATURE_S3_ENDPOINT = 'http://127.0.0.1:19000'
    $env:LOCAL_FEATURE_S3_BUCKET = $localBucket
    uv run --project (Join-Path $root 'data-pipeline') python `
        (Join-Path $root 'scripts/local/materialize-local-strategy-features.py') | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Local strategy feature materialization failed.' }

    [pscustomobject]@{
        status = 'restored'
        database_sha256 = $dumpHash
        flyway_version = '1'
        current_object_backup_count = $currentFiles.Count
        minio_object_count = $importedObjectCount
    } | ConvertTo-Json -Compress
} finally {
    if (Test-Path -LiteralPath $mappingPath -PathType Leaf) {
        Remove-Item -LiteralPath $mappingPath -Force
    }
    if (Test-Path -LiteralPath $importScriptPath -PathType Leaf) {
        Remove-Item -LiteralPath $importScriptPath -Force
    }
    if (Test-Path -LiteralPath $minioImportScriptPath -PathType Leaf) {
        Remove-Item -LiteralPath $minioImportScriptPath -Force
    }
    if (Test-Path -LiteralPath $versionListingPath -PathType Leaf) {
        Remove-Item -LiteralPath $versionListingPath -Force
    }
    if (Test-Path -LiteralPath $versionMappingPath -PathType Leaf) {
        Remove-Item -LiteralPath $versionMappingPath -Force
    }
    if ($importVolumeCreated) {
        docker volume rm $importVolume | Out-Null
    }
    Pop-Location
}
