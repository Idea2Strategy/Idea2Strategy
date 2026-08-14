[CmdletBinding()]
param(
    [string]$BackupRoot = 'D:\Idea2Strategy-backups\baseline-2026-08-13',
    [switch]$Force,
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $BackupRoot 'backup-manifest.json'
$dumpPath = Join-Path $BackupRoot 'database.dump'
$receiptPath = Join-Path $BackupRoot 's3-current-receipts.json'
$minioReceiptPath = Join-Path $BackupRoot 'local-minio-import-receipt.json'
$currentObjects = Join-Path $BackupRoot 's3-current'
$envPath = Join-Path $root '.env.docker'
$composePath = Join-Path $root 'compose.back.yml'

foreach ($required in @($manifestPath, $dumpPath, $receiptPath, $minioReceiptPath, $currentObjects, $envPath, $composePath)) {
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
    throw 'Restoring replaces only the active PostgreSQL and LocalStack volumes. Re-run with -Force after reviewing the validated backup.'
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
$databaseCredential = Get-EnvValue 'POSTGRES_PASSWORD'
$localBucket = [string]$minioReceipt.target_bucket
if ([string]::IsNullOrWhiteSpace($localBucket)) { throw 'The MinIO import receipt has no target bucket.' }
$expectedVolumes = @('idea2strategy-postgres-data', 'idea2strategy-localstack-data')

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
    docker compose --env-file $envPath -f $composePath rm -f flyway | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Unable to clear the completed Flyway one-shot container.' }
    docker compose --env-file $envPath -f $composePath up --no-deps flyway
    if ($LASTEXITCODE -ne 0) { throw 'Flyway could not apply the rebased V1.' }

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
        -v "backup_user=$user" -v "backup_password=$databaseCredential" -v "local_bucket=$localBucket" `
        -U $user -d $database -f /tmp/restore-local-baseline-data.sql | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Legacy baseline transformation failed.' }
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
        $expected = [string]$manifest.database.row_counts.$name
        if ($LASTEXITCODE -ne 0 -or $actual -cne $expected) {
            throw "Restored row count mismatch for ${name}: expected $expected, found $actual"
        }
    }

    [pscustomobject]@{
        status = 'restored'
        database_sha256 = $dumpHash
        flyway_version = '1'
        current_object_backup_count = $currentFiles.Count
        minio_volume = 'preserved'
    } | ConvertTo-Json -Compress
} finally {
    Pop-Location
}
