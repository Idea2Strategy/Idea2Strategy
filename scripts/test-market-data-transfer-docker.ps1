$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw "Docker is required for the market-data transfer E2E test."
}

$suffix = [guid]::NewGuid().ToString("N").Substring(0, 10)
$network = "i2s-baseline-test-$suffix"
$sourceDb = "i2s-source-db-$suffix"
$targetDb = "i2s-target-db-$suffix"
$collisionDb = "i2s-collision-db-$suffix"
$failureDb = "i2s-failure-db-$suffix"
$sourceMinio = "i2s-source-minio-$suffix"
$targetMinio = "i2s-target-minio-$suffix"
$transferRoot = Join-Path ([System.IO.Path]::GetTempPath()) "i2s-transfer-$suffix"
$baseline = Join-Path $transferRoot "baseline"
$password = "transfer-$suffix"
$accessKey = "transferadmin"
$secretKey = "transfer-secret-$suffix"
$sourceBucket = "source-market-data"
$targetBucket = "target-market-data"
$failureBucket = "failure-market-data"
$logicalId = "22222222-2222-4222-8222-222222222222"
$manifestId = "33333333-3333-4333-8333-333333333333"
$relationId = "44444444-4444-4444-8444-444444444444"
$objectKey = "historical/provider=fixture/feed=sip/manifest_id=$manifestId/part-00001.parquet"
$objectBytes = [byte[]](0x50, 0x41, 0x52, 0x31, 0x10, 0x20, 0x30, 0x40)

function Invoke-Docker {
    param([Parameter(Mandatory = $true)][string[]]$Arguments, [switch]$Capture)
    if ($Capture) { $output = & docker @Arguments 2>&1 } else { & docker @Arguments | Out-Null; $output = @() }
    if ($LASTEXITCODE -ne 0) { throw "docker failed: $($Arguments -join ' ')`n$(($output | Out-String).Trim())" }
    if ($Capture) { return $output }
}

function Wait-Postgres {
    param([Parameter(Mandatory = $true)][string]$Container)
    $consecutiveReady = 0
    for ($attempt = 0; $attempt -lt 80; $attempt++) {
        & docker exec $Container pg_isready -U idea2strategy -d idea2strategy *> $null
        if ($LASTEXITCODE -eq 0) {
            $consecutiveReady++
            if ($consecutiveReady -ge 5) { return }
        }
        else {
            $consecutiveReady = 0
        }
        Start-Sleep -Milliseconds 500
    }
    throw "PostgreSQL did not become ready: $Container"
}

function Invoke-Psql {
    param([Parameter(Mandatory = $true)][string]$Container, [Parameter(Mandatory = $true)][string]$Sql, [switch]$Capture)
    $arguments = @("exec", $Container, "psql", "-v", "ON_ERROR_STOP=1", "-U", "idea2strategy", "-d", "idea2strategy", "-At", "-c", $Sql)
    return Invoke-Docker -Arguments $arguments -Capture:$Capture
}

function Wait-MinIO {
    param([Parameter(Mandatory = $true)][string]$Alias, [Parameter(Mandatory = $true)][string]$Container)
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        & docker run --rm --network $network quay.io/minio/mc:RELEASE.2025-08-13T08-35-41Z `
            alias set $Alias "http://${Container}:9000" $accessKey $secretKey *> $null
        if ($LASTEXITCODE -eq 0) { return }
        Start-Sleep -Milliseconds 500
    }
    throw "MinIO did not become ready: $Container"
}

$schemaSql = @"
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE SCHEMA IF NOT EXISTS storage;
CREATE SCHEMA IF NOT EXISTS market_data;
CREATE SCHEMA IF NOT EXISTS strategy;
CREATE TYPE storage.object_status AS ENUM ('UPLOADING','AVAILABLE','QUARANTINED','SUPERSEDED','DELETED');
CREATE TYPE market_data.dataset_status AS ENUM ('BUILDING','AVAILABLE','QUARANTINED','SUPERSEDED','DELETED');
CREATE TYPE market_data.partition_granularity AS ENUM ('DAY','WEEK','MONTH','YEAR');
CREATE TABLE storage.objects (
  id uuid PRIMARY KEY, status storage.object_status NOT NULL, storage_provider varchar(40) NOT NULL,
  bucket_name varchar(160) NOT NULL, object_key varchar(900) NOT NULL, provider_version_id varchar(300) NOT NULL,
  content_hash varchar(128) NOT NULL, byte_size bigint NOT NULL, file_format varchar(40) NOT NULL,
  compression_codec varchar(40) NOT NULL, media_type varchar(120) NOT NULL, schema_version varchar(40) NOT NULL,
  row_count bigint, period_start timestamptz, period_end timestamptz, encryption_key_ref varchar(300),
  retention_policy_version varchar(80) NOT NULL, retention_until timestamptz, legal_hold boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(), verified_at timestamptz, quarantined_at timestamptz,
  superseded_at timestamptz, deleted_at timestamptz
);
CREATE TABLE market_data.dataset_manifests (
  id uuid PRIMARY KEY, feed_id uuid NOT NULL, instrument_id uuid, data_layer varchar(40) NOT NULL,
  resolution varchar(30) NOT NULL, revision_number int NOT NULL, status market_data.dataset_status NOT NULL,
  period_start timestamptz NOT NULL, period_end timestamptz NOT NULL, schema_version varchar(40) NOT NULL,
  dataset_hash varchar(128) NOT NULL, object_count bigint NOT NULL DEFAULT 0,
  supersedes_manifest_id uuid, created_at timestamptz NOT NULL DEFAULT now(), available_at timestamptz
);
CREATE TABLE market_data.dataset_objects (
  id uuid PRIMARY KEY, dataset_manifest_id uuid NOT NULL, object_id uuid NOT NULL, object_kind varchar(40) NOT NULL,
  partition_granularity market_data.partition_granularity NOT NULL, partition_start date NOT NULL,
  partition_end date NOT NULL, period_start timestamptz NOT NULL, period_end timestamptz NOT NULL,
  shard_key varchar(120) NOT NULL, part_number int NOT NULL, row_count bigint NOT NULL,
  min_instrument_id uuid, max_instrument_id uuid
);
CREATE TABLE strategy.element_catalog_versions (id uuid PRIMARY KEY);
CREATE TABLE market_data.feature_definitions (id uuid PRIMARY KEY, element_catalog_version_id uuid NOT NULL);
CREATE TABLE market_data.feature_snapshot_batches (id uuid PRIMARY KEY, snapshot_object_id uuid);
CREATE TABLE market_data.quality_incidents (id uuid PRIMARY KEY, evidence_object_id uuid);
"@

try {
    Write-Output "[transfer-e2e] create isolated source and target services"
    New-Item -ItemType Directory -Path $transferRoot -Force | Out-Null
    Invoke-Docker -Arguments @("network", "create", $network)
    foreach ($container in @($sourceDb, $targetDb, $collisionDb, $failureDb)) {
        Invoke-Docker -Arguments @(
            "run", "-d", "--name", $container, "--network", $network,
            "-e", "POSTGRES_DB=idea2strategy", "-e", "POSTGRES_USER=idea2strategy",
            "-e", "POSTGRES_PASSWORD=$password", "postgres:16-alpine"
        )
        Wait-Postgres -Container $container
        Invoke-Psql -Container $container -Sql $schemaSql
    }
    foreach ($container in @($sourceMinio, $targetMinio)) {
        Invoke-Docker -Arguments @(
            "run", "-d", "--name", $container, "--network", $network,
            "-e", "MINIO_ROOT_USER=$accessKey", "-e", "MINIO_ROOT_PASSWORD=$secretKey",
            "quay.io/minio/minio:RELEASE.2025-09-07T16-13-09Z", "server", "/data"
        )
    }
    Wait-MinIO -Alias "source" -Container $sourceMinio
    Wait-MinIO -Alias "target" -Container $targetMinio

    Write-Output "[transfer-e2e] seed source catalog and versioned object"
    $seedObject = Join-Path $transferRoot "seed.parquet"
    [System.IO.File]::WriteAllBytes($seedObject, $objectBytes)
    $objectHash = (Get-FileHash -LiteralPath $seedObject -Algorithm SHA256).Hash.ToLowerInvariant()
    $env:AWS_ACCESS_KEY_ID = $accessKey
    $env:AWS_SECRET_ACCESS_KEY = $secretKey
    Invoke-Docker -Arguments @(
        "run", "--rm", "--network", $network, "-e", "AWS_ACCESS_KEY_ID", "-e", "AWS_SECRET_ACCESS_KEY",
        "amazon/aws-cli:2.36.2", "--endpoint-url", "http://${sourceMinio}:9000", "--region", "ap-northeast-2",
        "s3api", "create-bucket", "--bucket", $sourceBucket,
        "--create-bucket-configuration", "LocationConstraint=ap-northeast-2"
    )
    Invoke-Docker -Arguments @(
        "run", "--rm", "--network", $network, "-e", "AWS_ACCESS_KEY_ID", "-e", "AWS_SECRET_ACCESS_KEY",
        "amazon/aws-cli:2.36.2", "--endpoint-url", "http://${sourceMinio}:9000", "--region", "ap-northeast-2",
        "s3api", "put-bucket-versioning", "--bucket", $sourceBucket,
        "--versioning-configuration", "Status=Enabled"
    )
    $putJson = Invoke-Docker -Capture -Arguments @(
        "run", "--rm", "--network", $network, "-v", "${transferRoot}:/baseline", "-e", "AWS_ACCESS_KEY_ID", "-e", "AWS_SECRET_ACCESS_KEY",
        "amazon/aws-cli:2.36.2", "--endpoint-url", "http://${sourceMinio}:9000", "--region", "ap-northeast-2",
        "s3api", "put-object", "--bucket", $sourceBucket, "--key", $objectKey, "--body", "/baseline/seed.parquet", "--output", "json"
    )
    $sourceVersion = [string](($putJson | Out-String | ConvertFrom-Json).VersionId)
    if ([string]::IsNullOrWhiteSpace($sourceVersion)) { throw "Source MinIO did not return a VersionId." }

    $seedSql = @"
INSERT INTO storage.objects VALUES (
 '$logicalId','AVAILABLE','aws-s3','$sourceBucket','$objectKey','$sourceVersion','$objectHash',8,
 'PARQUET','UNCOMPRESSED','application/vnd.apache.parquet','1.0.0',1,
 '2026-01-01T00:00:00Z','2026-01-02T00:00:00Z',NULL,'1.0.0',NULL,false,
 '2026-01-02T00:00:00Z','2026-01-02T00:00:00Z',NULL,NULL,NULL
);
INSERT INTO market_data.dataset_manifests VALUES (
 '$manifestId','55555555-5555-4555-8555-555555555555',NULL,'RAW','1m',1,'AVAILABLE',
 '2026-01-01T00:00:00Z','2026-01-02T00:00:00Z','1.0.0','$objectHash',1,NULL,
 '2026-01-02T00:00:00Z','2026-01-02T00:00:00Z'
);
INSERT INTO market_data.dataset_objects VALUES (
 '$relationId','$manifestId','$logicalId','BARS','DAY','2026-01-01','2026-01-02',
 '2026-01-01T00:00:00Z','2026-01-02T00:00:00Z','fixture',1,1,NULL,NULL
);
"@
    Invoke-Psql -Container $sourceDb -Sql $seedSql
    Remove-Item -LiteralPath $seedObject -Force

    Write-Output "[transfer-e2e] export and verify baseline"
    & (Join-Path $PSScriptRoot "export-market-data-baseline.ps1") `
        -BaselinePath $baseline -UseDockerTools -DockerNetwork $network `
        -DatabaseUrl "postgresql://idea2strategy:${password}@${sourceDb}:5432/idea2strategy" `
        -Bucket $sourceBucket -S3EndpointUrl "http://${sourceMinio}:9000" `
        -ConfirmMarketDataWritersStopped | Out-Null
    $verified = & (Join-Path $PSScriptRoot "verify-market-data-baseline.ps1") -BaselinePath $baseline -PassThru
    if (-not $verified.verified -or $verified.object_count -ne 1) { throw "Exported baseline did not verify." }

    Write-Output "[transfer-e2e] import into isolated target"
    Invoke-Docker -Arguments @(
        "run", "--rm", "--network", $network, "-e", "AWS_ACCESS_KEY_ID", "-e", "AWS_SECRET_ACCESS_KEY",
        "amazon/aws-cli:2.36.2", "--endpoint-url", "http://${targetMinio}:9000", "--region", "ap-northeast-2",
        "s3api", "create-bucket", "--bucket", $targetBucket,
        "--create-bucket-configuration", "LocationConstraint=ap-northeast-2"
    )
    Invoke-Docker -Arguments @(
        "run", "--rm", "--network", $network, "-e", "AWS_ACCESS_KEY_ID", "-e", "AWS_SECRET_ACCESS_KEY",
        "amazon/aws-cli:2.36.2", "--endpoint-url", "http://${targetMinio}:9000", "--region", "ap-northeast-2",
        "s3api", "put-bucket-versioning", "--bucket", $targetBucket,
        "--versioning-configuration", "Status=Enabled"
    )
    & (Join-Path $PSScriptRoot "import-market-data-baseline.ps1") `
        -BaselinePath $baseline -UseDockerTools -DockerNetwork $network `
        -DatabaseUrl "postgresql://idea2strategy:${password}@${targetDb}:5432/idea2strategy" `
        -TargetBucket $targetBucket -S3EndpointUrl "http://${targetMinio}:9000" | Out-Null

    Write-Output "[transfer-e2e] verify target catalog and object bytes"
    $catalog = (Invoke-Psql -Capture -Container $targetDb -Sql @"
SELECT so.id::text || '|' || so.bucket_name || '|' || so.object_key || '|' || so.content_hash || '|' ||
       dm.id::text || '|' || dmo.object_id::text || '|' || so.provider_version_id
FROM storage.objects so
JOIN market_data.dataset_objects dmo ON dmo.object_id = so.id
JOIN market_data.dataset_manifests dm ON dm.id = dmo.dataset_manifest_id;
"@ | Out-String).Trim()
    $parts = $catalog.Split('|')
    if ($parts.Count -ne 7 -or $parts[0] -cne $logicalId -or $parts[1] -cne $targetBucket -or
        $parts[2] -cne $objectKey -or $parts[3] -cne $objectHash -or $parts[4] -cne $manifestId -or
        $parts[5] -cne $logicalId -or $parts[6] -ceq $sourceVersion) {
        throw "Target catalog did not preserve logical IDs/key/hash or remap provider VersionId: $catalog"
    }

    $download = Join-Path $baseline "target-download.parquet"
    Invoke-Docker -Arguments @(
        "run", "--rm", "--network", $network, "-v", "${baseline}:/baseline", "-e", "AWS_ACCESS_KEY_ID", "-e", "AWS_SECRET_ACCESS_KEY",
        "amazon/aws-cli:2.36.2", "--endpoint-url", "http://${targetMinio}:9000", "--region", "ap-northeast-2",
        "s3api", "get-object", "--bucket", $targetBucket, "--key", $objectKey,
        "--version-id", $parts[6], "/baseline/target-download.parquet"
    )
    if ((Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash.ToLowerInvariant() -cne $objectHash) {
        throw "Target object bytes changed during transfer."
    }

    Write-Output "[transfer-e2e] reject an existing immutable key without mutating a fresh database"
    $collisionRejected = $false
    try {
        & (Join-Path $PSScriptRoot "import-market-data-baseline.ps1") `
            -BaselinePath $baseline -UseDockerTools -DockerNetwork $network `
            -DatabaseUrl "postgresql://idea2strategy:${password}@${collisionDb}:5432/idea2strategy" `
            -TargetBucket $targetBucket -S3EndpointUrl "http://${targetMinio}:9000" | Out-Null
    }
    catch {
        $collisionRejected = $_.Exception.Message -like "*version history*"
    }
    if (-not $collisionRejected) { throw "Import did not reject an existing immutable object key." }
    $collisionRows = ((Invoke-Psql -Capture -Container $collisionDb -Sql "SELECT (SELECT count(*) FROM storage.objects) + (SELECT count(*) FROM market_data.dataset_manifests);") | Out-String).Trim()
    if ([int64]$collisionRows -ne 0) { throw "Collision rejection mutated the target database." }

    Write-Output "[transfer-e2e] roll back uploaded versions when the atomic database import fails"
    Invoke-Docker -Arguments @(
        "run", "--rm", "--network", $network, "-e", "AWS_ACCESS_KEY_ID", "-e", "AWS_SECRET_ACCESS_KEY",
        "amazon/aws-cli:2.36.2", "--endpoint-url", "http://${targetMinio}:9000", "--region", "ap-northeast-2",
        "s3api", "create-bucket", "--bucket", $failureBucket,
        "--create-bucket-configuration", "LocationConstraint=ap-northeast-2"
    )
    Invoke-Docker -Arguments @(
        "run", "--rm", "--network", $network, "-e", "AWS_ACCESS_KEY_ID", "-e", "AWS_SECRET_ACCESS_KEY",
        "amazon/aws-cli:2.36.2", "--endpoint-url", "http://${targetMinio}:9000", "--region", "ap-northeast-2",
        "s3api", "put-bucket-versioning", "--bucket", $failureBucket,
        "--versioning-configuration", "Status=Enabled"
    )
    Invoke-Psql -Container $failureDb -Sql "DROP TABLE market_data.dataset_objects;"
    $databaseFailureObserved = $false
    try {
        & (Join-Path $PSScriptRoot "import-market-data-baseline.ps1") `
            -BaselinePath $baseline -UseDockerTools -DockerNetwork $network `
            -DatabaseUrl "postgresql://idea2strategy:${password}@${failureDb}:5432/idea2strategy" `
            -TargetBucket $failureBucket -S3EndpointUrl "http://${targetMinio}:9000" | Out-Null
    }
    catch { $databaseFailureObserved = $true }
    if (-not $databaseFailureObserved) { throw "Broken target schema unexpectedly accepted the import." }
    $failureRows = ((Invoke-Psql -Capture -Container $failureDb -Sql "SELECT (SELECT count(*) FROM storage.objects) + (SELECT count(*) FROM market_data.dataset_manifests);") | Out-String).Trim()
    if ([int64]$failureRows -ne 0) { throw "Failed atomic import left database rows behind." }
    $versionsJson = Invoke-Docker -Capture -Arguments @(
        "run", "--rm", "--network", $network, "-e", "AWS_ACCESS_KEY_ID", "-e", "AWS_SECRET_ACCESS_KEY",
        "amazon/aws-cli:2.36.2", "--endpoint-url", "http://${targetMinio}:9000", "--region", "ap-northeast-2",
        "s3api", "list-object-versions", "--bucket", $failureBucket, "--prefix", $objectKey, "--output", "json"
    )
    $failureVersions = $versionsJson | Out-String | ConvertFrom-Json
    if (($failureVersions.PSObject.Properties.Name -contains "Versions") -and @($failureVersions.Versions | Where-Object { $_.Key -ceq $objectKey }).Count -ne 0) {
        throw "Failed atomic import left an uploaded object version behind."
    }
    if (($failureVersions.PSObject.Properties.Name -contains "DeleteMarkers") -and @($failureVersions.DeleteMarkers | Where-Object { $_.Key -ceq $objectKey }).Count -ne 0) {
        throw "Failed atomic import left a delete marker behind."
    }
    Write-Output "Docker market-data transfer E2E checks passed."
}
finally {
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    foreach ($container in @($sourceDb, $targetDb, $collisionDb, $failureDb, $sourceMinio, $targetMinio)) {
        & docker rm -f $container *> $null
    }
    & docker network rm $network *> $null
    if (Test-Path -LiteralPath $transferRoot) { Remove-Item -LiteralPath $transferRoot -Recurse -Force }
    Remove-Item Env:AWS_ACCESS_KEY_ID -ErrorAction SilentlyContinue
    Remove-Item Env:AWS_SECRET_ACCESS_KEY -ErrorAction SilentlyContinue
    $ErrorActionPreference = $previousPreference
}
