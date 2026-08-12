[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$BaselinePath,
    [switch]$PassThru
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot "market-data-baseline.ps1")

$root = Resolve-BaselineRoot -BaselinePath $BaselinePath
$manifest = Read-BaselineManifest -BaselineRoot $root

if ($manifest.PSObject.Properties.Name -contains "required_target_rows" -and
    $manifest.required_target_rows.PSObject.Properties.Name -contains "strategy_element_catalog_version_ids") {
    $requiredIds = @{}
    foreach ($requiredIdValue in @($manifest.required_target_rows.strategy_element_catalog_version_ids)) {
        $requiredId = [string]$requiredIdValue
        $parsedRequiredId = [guid]::Empty
        if (-not [guid]::TryParse($requiredId, [ref]$parsedRequiredId) -or $parsedRequiredId -eq [guid]::Empty) {
            throw "Required strategy element catalog version is not a non-empty UUID: $requiredId"
        }
        if ($requiredIds.ContainsKey($requiredId)) {
            throw "Duplicate required strategy element catalog version UUID: $requiredId"
        }
        $requiredIds[$requiredId] = $true
    }
}

$databaseFile = Resolve-BaselineFile -BaselineRoot $root -RelativePath ([string]$manifest.database.file)
if (-not (Test-Path -LiteralPath $databaseFile -PathType Leaf)) {
    throw "Baseline database dump is missing: $($manifest.database.file)"
}
$databaseHash = ([string]$manifest.database.sha256).ToLowerInvariant()
Assert-Sha256Text -Value $databaseHash -Label "database.sha256"
if ((Get-LowerSha256 -Path $databaseFile) -cne $databaseHash) {
    throw "Baseline database dump hash does not match the manifest."
}

$storageCatalogFile = Resolve-BaselineFile -BaselineRoot $root -RelativePath ([string]$manifest.storage_catalog.file)
if (-not (Test-Path -LiteralPath $storageCatalogFile -PathType Leaf)) {
    throw "Baseline storage catalog is missing: $($manifest.storage_catalog.file)"
}
$storageCatalogHash = ([string]$manifest.storage_catalog.sha256).ToLowerInvariant()
Assert-Sha256Text -Value $storageCatalogHash -Label "storage_catalog.sha256"
if ((Get-LowerSha256 -Path $storageCatalogFile) -cne $storageCatalogHash) {
    throw "Baseline storage catalog hash does not match the manifest."
}

$catalogRows = @(Import-Csv -LiteralPath $storageCatalogFile)
$catalogByLogicalId = @{}
foreach ($row in $catalogRows) {
    $catalogId = [string]$row.logical_id
    if ([string]::IsNullOrWhiteSpace($catalogId)) {
        throw "Storage catalog contains an empty logical_id."
    }
    if ($catalogByLogicalId.ContainsKey($catalogId)) {
        throw "Storage catalog contains duplicate logical_id: $catalogId"
    }
    if ([string]$row.bucket_name -cne [string]$manifest.source.bucket) {
        throw "Storage catalog bucket disagrees with manifest source for $catalogId."
    }
    $catalogByLogicalId[$catalogId] = $row
}
if ($catalogRows.Count -ne @($manifest.objects).Count) {
    throw "Storage catalog and object manifest counts disagree."
}

$logicalIds = @{}
$keys = @{}
$verifiedObjects = @()
foreach ($object in @($manifest.objects)) {
    $logicalId = [string]$object.logical_id
    $parsedId = [guid]::Empty
    if (-not [guid]::TryParse($logicalId, [ref]$parsedId) -or $parsedId -eq [guid]::Empty) {
        throw "Object logical_id is not a non-empty UUID: $logicalId"
    }
    if ($logicalIds.ContainsKey($logicalId)) {
        throw "Duplicate logical object UUID in baseline manifest: $logicalId"
    }
    $logicalIds[$logicalId] = $true

    $key = [string]$object.key
    if ([string]::IsNullOrWhiteSpace($key)) {
        throw "Object key is empty for logical UUID $logicalId."
    }
    if ($keys.ContainsKey($key)) {
        throw "Duplicate object key in baseline manifest: $key"
    }
    $keys[$key] = $true

    if (-not $catalogByLogicalId.ContainsKey($logicalId)) {
        throw "Object manifest logical UUID is missing from storage catalog: $logicalId"
    }
    $catalogRow = $catalogByLogicalId[$logicalId]
    if ([string]$catalogRow.object_key -cne $key -or
        [string]$catalogRow.provider_version_id -cne [string]$object.source_version_id -or
        [string]$catalogRow.content_hash -cne [string]$object.content_hash -or
        [int64]$catalogRow.byte_size -ne [int64]$object.byte_size) {
        throw "Storage catalog and object manifest disagree for logical UUID $logicalId."
    }

    $file = Resolve-BaselineFile -BaselineRoot $root -RelativePath ([string]$object.file)
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        throw "Baseline object is missing: $($object.file)"
    }
    $expectedSize = [int64]$object.byte_size
    $actualSize = (Get-Item -LiteralPath $file).Length
    if ($actualSize -ne $expectedSize) {
        throw "Baseline object size mismatch for $logicalId ($key)."
    }
    $expectedHash = if ($object.PSObject.Properties.Name -contains "sha256") {
        ([string]$object.sha256).ToLowerInvariant()
    }
    else {
        ([string]$object.content_hash).ToLowerInvariant()
    }
    Assert-Sha256Text -Value $expectedHash -Label "object.sha256 ($logicalId)"
    if ((Get-LowerSha256 -Path $file) -cne $expectedHash) {
        throw "Baseline object hash mismatch for $logicalId ($key)."
    }
    $verifiedObjects += [pscustomobject]@{
        logical_id = $logicalId
        key = $key
        sha256 = $expectedHash
        byte_size = $actualSize
    }
}

$result = [pscustomobject]@{
    verified = $true
    schema_version = 1
    object_count = $verifiedObjects.Count
    database_sha256 = $databaseHash
    storage_catalog_sha256 = $storageCatalogHash
    objects = $verifiedObjects
}

if ($PassThru) {
    return $result
}
$result | ConvertTo-Json -Depth 5
