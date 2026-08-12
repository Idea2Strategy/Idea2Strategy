[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$BaselinePath,
    [Parameter(Mandatory = $true)][string]$DatabaseUrl,
    [Parameter(Mandatory = $true)][string]$TargetBucket,
    [string]$Region = "ap-northeast-2",
    [string]$S3EndpointUrl = "",
    [string]$AwsProfile = "",
    [switch]$UseDockerTools,
    [string]$DockerNetwork = "",
    [switch]$AllowAwsTarget
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "market-data-baseline.ps1")

if ([string]::IsNullOrWhiteSpace($S3EndpointUrl) -and -not $AllowAwsTarget) {
    throw "Import without -S3EndpointUrl targets AWS. Pass -AllowAwsTarget explicitly after checking the account and bucket."
}
if (-not $UseDockerTools) {
    foreach ($command in @("aws", "pg_restore", "psql")) { Assert-CommandAvailable -Name $command }
}

$verification = & (Join-Path $PSScriptRoot "verify-market-data-baseline.ps1") -BaselinePath $BaselinePath -PassThru
$root = Resolve-BaselineRoot -BaselinePath $BaselinePath
$manifest = Read-BaselineManifest -BaselineRoot $root
$dumpPath = Resolve-BaselineFile -BaselineRoot $root -RelativePath ([string]$manifest.database.file)
$storageCatalogPath = Resolve-BaselineFile -BaselineRoot $root -RelativePath ([string]$manifest.storage_catalog.file)
$awsBase = @("--region", $Region)
if (-not [string]::IsNullOrWhiteSpace($S3EndpointUrl)) { $awsBase += @("--endpoint-url", $S3EndpointUrl) }
if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) { $awsBase += @("--profile", $AwsProfile) }

$emptyTargetSql = @'
DO $i2s$
DECLARE item record; row_total bigint;
BEGIN
  SELECT count(*) INTO row_total FROM storage.objects;
  IF row_total <> 0 THEN RAISE EXCEPTION 'Target storage.objects is not empty'; END IF;
  FOR item IN SELECT tablename FROM pg_tables WHERE schemaname = 'market_data' LOOP
    EXECUTE format('SELECT count(*) FROM market_data.%I', item.tablename) INTO row_total;
    IF row_total <> 0 THEN RAISE EXCEPTION 'Target market_data.% is not empty', item.tablename; END IF;
  END LOOP;
END
$i2s$;
'@
Invoke-BaselinePostgresTool -Tool "psql" -BaselineRoot $root -UseDockerTools:$UseDockerTools `
    -DockerNetwork $DockerNetwork -Arguments @(
    "--dbname=$DatabaseUrl", "--no-psqlrc", "--set=ON_ERROR_STOP=1", "--command=$emptyTargetSql"
) | Out-Null

$requiredCatalogIds = @()
if ($manifest.PSObject.Properties.Name -contains "required_target_rows" -and
    $manifest.required_target_rows.PSObject.Properties.Name -contains "strategy_element_catalog_version_ids") {
    $requiredCatalogIds = @($manifest.required_target_rows.strategy_element_catalog_version_ids)
}
if ($requiredCatalogIds.Count -gt 0) {
    $requiredValues = @($requiredCatalogIds | ForEach-Object { "('$([guid]$_)'::uuid)" }) -join ','
    $missingSql = "SELECT count(*) FROM (VALUES $requiredValues) required(id) WHERE NOT EXISTS (SELECT 1 FROM strategy.element_catalog_versions target WHERE target.id = required.id);"
    $missingCount = ((Invoke-BaselinePostgresTool -Tool "psql" -BaselineRoot $root `
        -UseDockerTools:$UseDockerTools -DockerNetwork $DockerNetwork -Capture -Arguments @(
        "--dbname=$DatabaseUrl", "--no-psqlrc", "--tuples-only", "--no-align", "--set=ON_ERROR_STOP=1", "--command=$missingSql"
    ) | Out-String).Trim())
    if ([int64]$missingCount -ne 0) {
        throw "Target database is missing $missingCount required strategy.element_catalog_versions row(s). Apply the matching Flyway/bootstrap baseline first."
    }
}

$versioningOutput = Invoke-BaselineAwsTool -BaselineRoot $root -UseDockerTools:$UseDockerTools `
    -DockerNetwork $DockerNetwork -Capture -Arguments ($awsBase + @(
    "s3api", "get-bucket-versioning", "--bucket", $TargetBucket, "--output", "json"
))
$versioning = ($versioningOutput | Out-String) | ConvertFrom-Json
if (-not ($versioning.PSObject.Properties.Name -contains "Status") -or [string]$versioning.Status -cne "Enabled") {
    throw "Target bucket versioning must be Enabled before import: $TargetBucket"
}

$mapping = @()
$databaseCommitted = $false
try {
    foreach ($object in @($manifest.objects)) {
        $key = [string]$object.key
        $versionsOutput = Invoke-BaselineAwsTool -BaselineRoot $root -UseDockerTools:$UseDockerTools `
            -DockerNetwork $DockerNetwork -Capture -Arguments ($awsBase + @(
            "s3api", "list-object-versions", "--bucket", $TargetBucket, "--prefix", $key, "--output", "json"
        ))
        $versions = ($versionsOutput | Out-String) | ConvertFrom-Json
        $existing = @()
        if ($versions.PSObject.Properties.Name -contains "Versions") {
            $existing += @($versions.Versions | Where-Object { [string]$_.Key -ceq $key })
        }
        if ($versions.PSObject.Properties.Name -contains "DeleteMarkers") {
            $existing += @($versions.DeleteMarkers | Where-Object { [string]$_.Key -ceq $key })
        }
        if ($existing.Count -ne 0) {
            throw "Target object key already has version history; refusing to overwrite immutable data: $key"
        }

        $file = Resolve-BaselineFile -BaselineRoot $root -RelativePath ([string]$object.file)
        $sha256 = [string]$object.sha256
        $transferAttempt = [guid]::NewGuid().ToString("N")
        try {
            $putOutput = Invoke-BaselineAwsTool -BaselineRoot $root -UseDockerTools:$UseDockerTools `
                -DockerNetwork $DockerNetwork -Capture -Arguments ($awsBase + @(
                "s3api", "put-object", "--bucket", $TargetBucket, "--key", $key, "--body", $file,
                "--if-none-match", "*", "--metadata", "sha256=$sha256,transfer_attempt=$transferAttempt",
                "--checksum-algorithm", "SHA256", "--output", "json"
            ))
            $putResult = ($putOutput | Out-String) | ConvertFrom-Json
            if (-not ($putResult.PSObject.Properties.Name -contains "VersionId")) {
                throw "Target object store did not return an exact VersionId: $key"
            }
            $targetVersion = [string]$putResult.VersionId
            if ([string]::IsNullOrWhiteSpace($targetVersion) -or $targetVersion -ceq "null") {
                throw "Target object store returned an invalid VersionId: $key"
            }
        }
        catch {
            $putError = $_
            try {
                $reconcileOutput = Invoke-BaselineAwsTool -BaselineRoot $root -UseDockerTools:$UseDockerTools `
                    -DockerNetwork $DockerNetwork -Capture -Arguments ($awsBase + @(
                    "s3api", "list-object-versions", "--bucket", $TargetBucket, "--prefix", $key, "--output", "json"
                ))
                $reconcileVersions = ($reconcileOutput | Out-String) | ConvertFrom-Json
                foreach ($candidate in @($reconcileVersions.Versions | Where-Object { [string]$_.Key -ceq $key })) {
                    $candidateHeadOutput = Invoke-BaselineAwsTool -BaselineRoot $root -UseDockerTools:$UseDockerTools `
                        -DockerNetwork $DockerNetwork -Capture -Arguments ($awsBase + @(
                        "s3api", "head-object", "--bucket", $TargetBucket, "--key", $key,
                        "--version-id", ([string]$candidate.VersionId), "--output", "json"
                    ))
                    $candidateHead = ($candidateHeadOutput | Out-String) | ConvertFrom-Json
                    if ($candidateHead.PSObject.Properties.Name -contains "Metadata" -and
                        [string]$candidateHead.Metadata.transfer_attempt -ceq $transferAttempt) {
                        $mapping += [ordered]@{
                            logical_id = [string]$object.logical_id; key = $key
                            source_version_id = [string]$object.source_version_id
                            target_version_id = [string]$candidate.VersionId; sha256 = $sha256
                        }
                        break
                    }
                }
            }
            catch { Write-Warning "Unable to reconcile an ambiguous upload for $key. Inspect transfer_attempt=$transferAttempt before retrying." }
            throw $putError
        }

        # Record the exact uploaded version before doing any follow-up request so a
        # failed HEAD/metadata check can still remove only the version we created.
        $mapping += [ordered]@{
            logical_id = [string]$object.logical_id
            key = $key
            source_version_id = [string]$object.source_version_id
            target_version_id = $targetVersion
            sha256 = $sha256
        }

        $headOutput = Invoke-BaselineAwsTool -BaselineRoot $root -UseDockerTools:$UseDockerTools `
            -DockerNetwork $DockerNetwork -Capture -Arguments ($awsBase + @(
            "s3api", "head-object", "--bucket", $TargetBucket, "--key", $key,
            "--version-id", $targetVersion, "--output", "json"
        ))
        $head = ($headOutput | Out-String) | ConvertFrom-Json
        $metadataHash = if ($head.PSObject.Properties.Name -contains "Metadata" -and
            $head.Metadata.PSObject.Properties.Name -contains "sha256") { [string]$head.Metadata.sha256 } else { "" }
        if ([int64]$head.ContentLength -ne [int64]$object.byte_size -or $metadataHash -cne $sha256) {
            throw "Target object verification failed after upload: $key ($targetVersion)"
        }

        $downloadVerificationPath = Join-Path $root (".verify-upload-" + [guid]::NewGuid().ToString("N"))
        try {
            Invoke-BaselineAwsTool -BaselineRoot $root -UseDockerTools:$UseDockerTools `
                -DockerNetwork $DockerNetwork -Arguments ($awsBase + @(
                "s3api", "get-object", "--bucket", $TargetBucket, "--key", $key,
                "--version-id", $targetVersion, $downloadVerificationPath
            )) | Out-Null
            if ((Get-LowerSha256 -Path $downloadVerificationPath) -cne $sha256) {
                throw "Target object bytes failed SHA-256 verification after upload: $key ($targetVersion)"
            }
        }
        finally {
            Remove-Item -LiteralPath $downloadVerificationPath -Force -ErrorAction SilentlyContinue
        }
    }

    $marketSqlPath = Join-Path $root (".import-market-" + [guid]::NewGuid().ToString("N") + ".sql")
    $atomicSqlPath = Join-Path $root (".import-atomic-" + [guid]::NewGuid().ToString("N") + ".sql")
    try {
        Invoke-BaselinePostgresTool -Tool "pg_restore" -BaselineRoot $root -UseDockerTools:$UseDockerTools `
            -DockerNetwork $DockerNetwork -Arguments @(
            "--data-only", "--no-owner", "--no-privileges", "--exit-on-error", "--file=$marketSqlPath", $dumpPath
        )
        $catalogPathForPsql = if ($UseDockerTools) { "/baseline/storage-objects.csv" } else { $storageCatalogPath.Replace('\', '/') }
        $escapedCatalogPath = $catalogPathForPsql.Replace("'", "''")
        $marketSql = Get-Content -LiteralPath $marketSqlPath -Raw
        $atomicSql = "\set ON_ERROR_STOP on`nBEGIN;`n$emptyTargetSql`n"
        $atomicSql += "\copy storage.objects (id,status,storage_provider,bucket_name,object_key,provider_version_id,content_hash,byte_size,file_format,compression_codec,media_type,schema_version,row_count,period_start,period_end,encryption_key_ref,retention_policy_version,retention_until,legal_hold,created_at,verified_at,quarantined_at,superseded_at,deleted_at) FROM '$escapedCatalogPath' WITH (FORMAT csv, HEADER true)`n"
        $atomicSql += $marketSql + "`n"
        $targetProvider = if ([string]::IsNullOrWhiteSpace($S3EndpointUrl)) { "S3" } else { "S3_COMPATIBLE" }
        foreach ($entry in $mapping) {
            $targetBucketLiteral = $TargetBucket.Replace("'", "''")
            $targetVersionLiteral = ([string]$entry.target_version_id).Replace("'", "''")
            $atomicSql += "UPDATE storage.objects SET storage_provider='$targetProvider', bucket_name='$targetBucketLiteral', provider_version_id='$targetVersionLiteral', verified_at=now() WHERE id='$([guid]$entry.logical_id)'::uuid;`n"
        }
        $expectedCount = $mapping.Count
        $atomicSql += @"
DO `$i2s`$
DECLARE actual bigint;
BEGIN
  SELECT count(*) INTO actual FROM storage.objects;
  IF actual <> $expectedCount THEN RAISE EXCEPTION 'Imported storage object count mismatch: %', actual; END IF;
  IF EXISTS (SELECT 1 FROM market_data.dataset_objects relation LEFT JOIN storage.objects stored ON stored.id=relation.object_id WHERE stored.id IS NULL) THEN
    RAISE EXCEPTION 'Imported dataset object has no storage object';
  END IF;
END
`$i2s`$;
COMMIT;
"@
        $encoding = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($atomicSqlPath, $atomicSql, $encoding)
        Invoke-BaselinePostgresTool -Tool "psql" -BaselineRoot $root -UseDockerTools:$UseDockerTools `
            -DockerNetwork $DockerNetwork -Arguments @(
            "--dbname=$DatabaseUrl", "--no-psqlrc", "--set=ON_ERROR_STOP=1", "--file=$atomicSqlPath"
        ) | Out-Null
        $databaseCommitted = $true
    }
    finally {
        Remove-Item -LiteralPath $marketSqlPath, $atomicSqlPath -Force -ErrorAction SilentlyContinue
    }
}
catch {
    $originalError = $_
    if (-not $databaseCommitted) {
        foreach ($entry in @($mapping)) {
            try {
                Invoke-BaselineAwsTool -BaselineRoot $root -UseDockerTools:$UseDockerTools `
                    -DockerNetwork $DockerNetwork -Arguments ($awsBase + @(
                    "s3api", "delete-object", "--bucket", $TargetBucket, "--key", ([string]$entry.key),
                    "--version-id", ([string]$entry.target_version_id)
                )) | Out-Null
            }
            catch { Write-Warning "Unable to roll back uploaded version $($entry.key)@$($entry.target_version_id): $($_.Exception.Message)" }
        }
    }
    throw $originalError
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
