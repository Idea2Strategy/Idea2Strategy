[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$BaselinePath,
    [Parameter(Mandatory = $true)][string]$DatabaseUrl,
    [Parameter(Mandatory = $true)][string]$TargetBucket,
    [string]$Region = "ap-northeast-2",
    [string]$S3EndpointUrl = "",
    [string]$AwsProfile = "",
    [switch]$AllowAwsTarget
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "market-data-baseline.ps1")

if ([string]::IsNullOrWhiteSpace($S3EndpointUrl) -and -not $AllowAwsTarget) {
    throw "Import without -S3EndpointUrl targets AWS. Pass -AllowAwsTarget explicitly after checking the account and bucket."
}
Assert-CommandAvailable -Name "aws"
Assert-CommandAvailable -Name "pg_restore"
Assert-CommandAvailable -Name "psql"

$verification = & (Join-Path $PSScriptRoot "verify-market-data-baseline.ps1") -BaselinePath $BaselinePath -PassThru
$root = Resolve-BaselineRoot -BaselinePath $BaselinePath
$manifest = Read-BaselineManifest -BaselineRoot $root
$dumpPath = Resolve-BaselineFile -BaselineRoot $root -RelativePath ([string]$manifest.database.file)
$storageCatalogPath = Resolve-BaselineFile -BaselineRoot $root -RelativePath ([string]$manifest.storage_catalog.file)

$awsBase = @("--region", $Region)
if (-not [string]::IsNullOrWhiteSpace($S3EndpointUrl)) { $awsBase += @("--endpoint-url", $S3EndpointUrl) }
if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) { $awsBase += @("--profile", $AwsProfile) }
$mapping = @()
foreach ($object in @($manifest.objects)) {
    $file = Resolve-BaselineFile -BaselineRoot $root -RelativePath ([string]$object.file)
    $putOutput = Invoke-CheckedNative -FilePath "aws" -Arguments ($awsBase + @(
        "s3api", "put-object", "--bucket", $TargetBucket, "--key", ([string]$object.key), "--body", $file,
        "--checksum-algorithm", "SHA256", "--output", "json"
    )) -Capture
    $putResult = ($putOutput | Out-String) | ConvertFrom-Json
    $targetVersion = if ($putResult.PSObject.Properties.Name -contains "VersionId") {
        [string]$putResult.VersionId
    }
    else {
        ([string]$putResult.ETag).Trim('"')
    }
    if ([string]::IsNullOrWhiteSpace($targetVersion)) { $targetVersion = "unversioned" }
    $mapping += [ordered]@{
        logical_id = [string]$object.logical_id
        key = [string]$object.key
        source_version_id = [string]$object.source_version_id
        target_version_id = $targetVersion
        sha256 = [string]$object.sha256
    }
}

# Do not mutate PostgreSQL until every immutable object has uploaded successfully.
$escapedCatalogPath = $storageCatalogPath.Replace("'", "''").Replace('\', '/')
$copyStorage = @"
\copy storage.objects (id,status,storage_provider,bucket_name,object_key,provider_version_id,content_hash,byte_size,file_format,compression_codec,media_type,schema_version,row_count,period_start,period_end,encryption_key_ref,retention_policy_version,retention_until,legal_hold,created_at,verified_at,quarantined_at,superseded_at,deleted_at) FROM '$escapedCatalogPath' WITH (FORMAT csv, HEADER true)
"@
Invoke-CheckedNative -FilePath "psql" -Arguments @(
    "--dbname=$DatabaseUrl", "--no-psqlrc", "--set=ON_ERROR_STOP=1", "--command=$copyStorage"
) | Out-Null

Invoke-CheckedNative -FilePath "pg_restore" -Arguments @(
    "--dbname=$DatabaseUrl", "--data-only", "--no-owner", "--no-privileges", "--exit-on-error", $dumpPath
)

function ConvertTo-PgLiteral {
    param([AllowEmptyString()][string]$Value)
    return "'" + $Value.Replace("'", "''") + "'"
}

$remapSql = "BEGIN;`n"
foreach ($entry in $mapping) {
    $logicalId = [guid]$entry.logical_id
    $targetBucketLiteral = ConvertTo-PgLiteral -Value $TargetBucket
    $targetVersionLiteral = ConvertTo-PgLiteral -Value ([string]$entry.target_version_id)
    $remapSql += @"
DO `$i2s`$
BEGIN
  UPDATE storage.objects
  SET storage_provider = 's3-compatible',
      bucket_name = $targetBucketLiteral,
      provider_version_id = $targetVersionLiteral,
      verified_at = now()
  WHERE id = '$logicalId'::uuid;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Missing logical storage object during import: $logicalId';
  END IF;
END
`$i2s`$;
"@
}
$remapSql += "COMMIT;`n"
$remapPath = [System.IO.Path]::GetTempFileName()
try {
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($remapPath, $remapSql, $encoding)
    Invoke-CheckedNative -FilePath "psql" -Arguments @(
        "--dbname=$DatabaseUrl", "--no-psqlrc", "--set=ON_ERROR_STOP=1", "--file=$remapPath"
    ) | Out-Null
}
finally {
    Remove-Item -LiteralPath $remapPath -Force -ErrorAction SilentlyContinue
}

$receipt = [ordered]@{
    schema_version = 1
    imported_at_utc = (Get-Date).ToUniversalTime().ToString("o")
    target = [ordered]@{ bucket = $TargetBucket; region = $Region; endpoint = $S3EndpointUrl }
    verified_object_count = $verification.object_count
    objects = $mapping
}
$receiptPath = Join-Path $root "import-receipt.json"
$encoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($receiptPath, ($receipt | ConvertTo-Json -Depth 8), $encoding)
$receipt | ConvertTo-Json -Depth 8
