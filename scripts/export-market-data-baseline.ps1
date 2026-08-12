[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$BaselinePath,
    [Parameter(Mandatory = $true)][string]$DatabaseUrl,
    [Parameter(Mandatory = $true)][string]$Bucket,
    [string]$Region = "ap-northeast-2",
    [string]$AwsProfile = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "market-data-baseline.ps1")

Assert-CommandAvailable -Name "aws"
Assert-CommandAvailable -Name "psql"
Assert-CommandAvailable -Name "pg_dump"

$fullBaselinePath = [System.IO.Path]::GetFullPath($BaselinePath)
if (Test-Path -LiteralPath $fullBaselinePath) {
    $existing = @(Get-ChildItem -LiteralPath $fullBaselinePath -Force)
    if ($existing.Count -gt 0 -and -not $Force) {
        throw "Baseline directory is not empty. Choose a new directory or pass -Force: $fullBaselinePath"
    }
    if ($existing.Count -gt 0) {
        foreach ($item in $existing) { Remove-Item -LiteralPath $item.FullName -Recurse -Force }
    }
}
else {
    New-Item -ItemType Directory -Path $fullBaselinePath -Force | Out-Null
}
$objectsDirectory = Join-Path $fullBaselinePath "objects"
New-Item -ItemType Directory -Path $objectsDirectory -Force | Out-Null

$dumpPath = Join-Path $fullBaselinePath "market-catalog.dump"
Invoke-CheckedNative -FilePath "pg_dump" -Arguments @(
    "--dbname=$DatabaseUrl", "--format=custom", "--data-only", "--no-owner", "--no-privileges",
    "--schema=market_data", "--file=$dumpPath"
)

$query = @"
SELECT id::text AS logical_id, status::text, storage_provider, bucket_name, object_key,
       provider_version_id, content_hash, byte_size, file_format, compression_codec,
       media_type, schema_version, row_count, period_start, period_end, encryption_key_ref,
       retention_policy_version, retention_until, legal_hold, created_at, verified_at,
       quarantined_at, superseded_at, deleted_at
FROM storage.objects
WHERE bucket_name = :'baseline_bucket'
ORDER BY id;
"@
$csvLines = @(Invoke-CheckedNative -FilePath "psql" -Arguments @(
    "--dbname=$DatabaseUrl", "--no-psqlrc", "--csv", "--set=ON_ERROR_STOP=1",
    "--set=baseline_bucket=$Bucket", "--command=$query"
) -Capture)
$rows = if ($csvLines.Count -eq 0) { @() } else { @($csvLines | ConvertFrom-Csv) }
$storageCatalogPath = Join-Path $fullBaselinePath "storage-objects.csv"
$encoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($storageCatalogPath, [string[]]$csvLines, $encoding)

$awsBase = @("--region", $Region)
if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) { $awsBase += @("--profile", $AwsProfile) }
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
    Invoke-CheckedNative -FilePath "aws" -Arguments $getArguments | Out-Null

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

& (Join-Path $PSScriptRoot "verify-market-data-baseline.ps1") -BaselinePath $fullBaselinePath
