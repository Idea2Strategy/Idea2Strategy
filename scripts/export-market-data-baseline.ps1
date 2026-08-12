[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$BaselinePath,
    [Parameter(Mandatory = $true)][string]$DatabaseUrl,
    [Parameter(Mandatory = $true)][string]$Bucket,
    [string]$Region = "ap-northeast-2",
    [string]$AwsProfile = "",
    [string]$S3EndpointUrl = "",
    [switch]$UseDockerTools,
    [string]$DockerNetwork = "",
    [switch]$ConfirmMarketDataWritersStopped
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "market-data-baseline.ps1")

if (-not $ConfirmMarketDataWritersStopped) {
    throw "Stop every market-data writer, then pass -ConfirmMarketDataWritersStopped. The dump and storage inventory must not be captured while writers are active."
}

if (-not $UseDockerTools) {
    Assert-CommandAvailable -Name "aws"
    Assert-CommandAvailable -Name "psql"
    Assert-CommandAvailable -Name "pg_dump"
}

$destinationPath = [System.IO.Path]::GetFullPath($BaselinePath)
if (Test-Path -LiteralPath $destinationPath) {
    throw "Baseline destination already exists. Export always requires a new path: $destinationPath"
}
$destinationParent = Split-Path -Parent $destinationPath
if ([string]::IsNullOrWhiteSpace($destinationParent)) {
    throw "Baseline destination must have a parent directory: $destinationPath"
}
New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
$fullBaselinePath = "$destinationPath.staging-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $fullBaselinePath | Out-Null
$ownershipMarker = Join-Path $fullBaselinePath ".idea2strategy-baseline-staging"
[System.IO.File]::WriteAllText($ownershipMarker, "idea2strategy-market-data-baseline-staging-v1")
$objectsDirectory = Join-Path $fullBaselinePath "objects"
New-Item -ItemType Directory -Path $objectsDirectory -Force | Out-Null

try {
    $dumpPath = Join-Path $fullBaselinePath "market-catalog.dump"
    Invoke-BaselinePostgresTool -Tool "pg_dump" -BaselineRoot $fullBaselinePath `
        -UseDockerTools:$UseDockerTools -DockerNetwork $DockerNetwork -Arguments @(
        "--dbname=$DatabaseUrl", "--format=custom", "--data-only", "--no-owner", "--no-privileges",
        "--table=market_data.*", "--file=$dumpPath"
    )

    $escapedBucket = $Bucket.Replace("'", "''")
    $referenceQuery = @"
WITH referenced_objects AS (
  SELECT object_id FROM market_data.dataset_objects
  UNION SELECT snapshot_object_id FROM market_data.feature_snapshot_batches WHERE snapshot_object_id IS NOT NULL
  UNION SELECT evidence_object_id FROM market_data.quality_incidents WHERE evidence_object_id IS NOT NULL
)
SELECT count(*)
FROM referenced_objects referenced
LEFT JOIN storage.objects stored ON stored.id = referenced.object_id
WHERE stored.id IS NULL OR stored.bucket_name <> '$escapedBucket';
"@
    $crossBucketCount = ((Invoke-BaselinePostgresTool -Tool "psql" -BaselineRoot $fullBaselinePath `
        -UseDockerTools:$UseDockerTools -DockerNetwork $DockerNetwork -Capture -Arguments @(
        "--dbname=$DatabaseUrl", "--no-psqlrc", "--tuples-only", "--no-align", "--set=ON_ERROR_STOP=1",
        "--command=$referenceQuery"
    ) | Out-String).Trim())
    if ([int64]$crossBucketCount -ne 0) {
        throw "Market-data catalog references $crossBucketCount storage object(s) outside the selected bucket. Export every referenced object from one baseline."
    }

    $requiredCatalogQuery = @"
SELECT DISTINCT element_catalog_version_id::text
FROM market_data.feature_definitions
ORDER BY element_catalog_version_id::text;
"@
    $requiredElementCatalogVersions = @(
        Invoke-BaselinePostgresTool -Tool "psql" -BaselineRoot $fullBaselinePath `
            -UseDockerTools:$UseDockerTools -DockerNetwork $DockerNetwork -Capture -Arguments @(
            "--dbname=$DatabaseUrl", "--no-psqlrc", "--tuples-only", "--no-align", "--set=ON_ERROR_STOP=1",
            "--command=$requiredCatalogQuery"
        ) | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ }
    )

    $query = @"
SELECT id::text AS logical_id, status::text, storage_provider, bucket_name, object_key,
       provider_version_id, content_hash, byte_size, file_format, compression_codec,
       media_type, schema_version, row_count, period_start, period_end, encryption_key_ref,
       retention_policy_version, retention_until, legal_hold, created_at, verified_at,
       quarantined_at, superseded_at, deleted_at
FROM storage.objects
WHERE bucket_name = '$escapedBucket'
ORDER BY id;
"@
    $csvLines = @(Invoke-BaselinePostgresTool -Tool "psql" -BaselineRoot $fullBaselinePath `
        -UseDockerTools:$UseDockerTools -DockerNetwork $DockerNetwork -Capture -Arguments @(
        "--dbname=$DatabaseUrl", "--no-psqlrc", "--csv", "--set=ON_ERROR_STOP=1",
        "--command=$query"
    ))
    $rows = if ($csvLines.Count -eq 0) { @() } else { @($csvLines | ConvertFrom-Csv) }
    $storageCatalogPath = Join-Path $fullBaselinePath "storage-objects.csv"
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($storageCatalogPath, [string[]]$csvLines, $encoding)

    $awsBase = @("--region", $Region)
    if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) { $awsBase += @("--profile", $AwsProfile) }
    if (-not [string]::IsNullOrWhiteSpace($S3EndpointUrl)) { $awsBase += @("--endpoint-url", $S3EndpointUrl) }
    $objects = @()
    foreach ($row in $rows) {
    $logicalId = [string]$row.logical_id
    $relativeFile = "objects/$logicalId.parquet"
    $targetFile = Join-Path $objectsDirectory "$logicalId.parquet"
    $getArguments = $awsBase + @(
        "s3api", "get-object", "--bucket", $Bucket, "--key", ([string]$row.object_key)
    )
    if (-not [string]::IsNullOrWhiteSpace([string]$row.provider_version_id)) {
        $getArguments += @("--version-id", ([string]$row.provider_version_id))
    }
    $getArguments += @($targetFile)
    Invoke-BaselineAwsTool -BaselineRoot $fullBaselinePath -UseDockerTools:$UseDockerTools `
        -DockerNetwork $DockerNetwork -Arguments $getArguments | Out-Null

    $actualSize = (Get-Item -LiteralPath $targetFile).Length
    if ($actualSize -ne [int64]$row.byte_size) {
        throw "Downloaded object size does not match storage.objects: $logicalId"
    }
    $sha256 = Get-LowerSha256 -Path $targetFile
    $catalogHash = ([string]$row.content_hash).ToLowerInvariant()
    if ($catalogHash -match '^[0-9a-f]{64}$' -and $sha256 -cne $catalogHash) {
        throw "Downloaded object hash does not match storage.objects: $logicalId"
    }
    $objects += [ordered]@{
        logical_id = $logicalId
        key = [string]$row.object_key
        source_version_id = [string]$row.provider_version_id
        content_hash = $catalogHash
        sha256 = $sha256
        byte_size = $actualSize
        file = $relativeFile
    }
    }

    $manifest = [ordered]@{
    schema_version = 1
    created_at_utc = (Get-Date).ToUniversalTime().ToString("o")
        source = [ordered]@{ provider = "aws-s3"; bucket = $Bucket; region = $Region }
        required_target_rows = [ordered]@{
            strategy_element_catalog_version_ids = $requiredElementCatalogVersions
        }
    database = [ordered]@{
        file = "market-catalog.dump"
        sha256 = Get-LowerSha256 -Path $dumpPath
        format = "postgresql-custom"
    }
    storage_catalog = [ordered]@{
        file = "storage-objects.csv"
        sha256 = Get-LowerSha256 -Path $storageCatalogPath
        format = "postgresql-copy-csv"
    }
    objects = $objects
    }
    $manifestPath = Join-Path $fullBaselinePath "baseline-manifest.json"
    [System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8), $encoding)

    & (Join-Path $PSScriptRoot "verify-market-data-baseline.ps1") -BaselinePath $fullBaselinePath | Out-Null
    Move-Item -LiteralPath $fullBaselinePath -Destination $destinationPath
    Remove-Item -LiteralPath (Join-Path $destinationPath ".idea2strategy-baseline-staging") -Force
    & (Join-Path $PSScriptRoot "verify-market-data-baseline.ps1") -BaselinePath $destinationPath
}
finally {
    if ((Test-Path -LiteralPath $ownershipMarker -PathType Leaf) -and
        (Test-Path -LiteralPath $fullBaselinePath -PathType Container)) {
        Remove-Item -LiteralPath $fullBaselinePath -Recurse -Force
    }
}
