$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$verifyScript = Join-Path $PSScriptRoot "verify-market-data-baseline.ps1"
if (-not (Test-Path -LiteralPath $verifyScript -PathType Leaf)) {
    throw "Market-data baseline verifier is missing."
}
$exportScript = Join-Path $PSScriptRoot "export-market-data-baseline.ps1"
$importScript = Join-Path $PSScriptRoot "import-market-data-baseline.ps1"
foreach ($requiredScript in @($exportScript, $importScript)) {
    if (-not (Test-Path -LiteralPath $requiredScript -PathType Leaf)) {
        throw "Market-data baseline transfer script is missing: $requiredScript"
    }
}

$exportSource = Get-Content -LiteralPath $exportScript -Raw
if ($exportSource -match "status\s*=\s*'AVAILABLE'" -or
    $exportSource -notmatch 'storage-objects\.csv' -or
    $exportSource -notmatch '--version-id' -or
    $exportSource -notmatch 'S3EndpointUrl' -or
    $exportSource -notmatch 'UseDockerTools' -or
    $exportSource -notmatch 'ConfirmMarketDataWritersStopped' -or
    $exportSource -notmatch 'Baseline destination already exists' -or
    $exportSource -notmatch 'idea2strategy-baseline-staging') {
    throw "Export must include every catalogued object in the selected bucket and preserve exact source versions."
}
$importSource = Get-Content -LiteralPath $importScript -Raw
$uploadPosition = $importSource.IndexOf('"s3api", "put-object"', [System.StringComparison]::Ordinal)
$restorePosition = $importSource.IndexOf('-Tool "pg_restore"', [System.StringComparison]::Ordinal)
if ($uploadPosition -lt 0 -or $restorePosition -lt 0 -or $uploadPosition -gt $restorePosition) {
    throw "Import must upload every object before mutating PostgreSQL."
}
if ($importSource -notmatch 'AllowAwsTarget' -or $importSource -notmatch 'Import without -S3EndpointUrl targets AWS') {
    throw "Import must require explicit opt-in before writing to AWS."
}
if ($importSource -notmatch '--if-none-match=\*' -or
    $importSource -notmatch '--version-id' -or
    $importSource -notmatch '\\set ON_ERROR_STOP on' -or
    $importSource -notmatch 'BEGIN;' -or
    $importSource -notmatch 'COMMIT;') {
    throw "Import must protect immutable keys, track exact uploaded versions, and restore PostgreSQL atomically."
}
$sharedSource = Get-Content -LiteralPath (Join-Path $PSScriptRoot "market-data-baseline.ps1") -Raw
if ($sharedSource -notmatch 'amazon/aws-cli:2\.36\.2' -or
    $sharedSource -notmatch 'postgres:16-alpine' -or
    $sharedSource -notmatch 'Invoke-BaselineAwsTool' -or
    $sharedSource -notmatch 'Invoke-BaselinePostgresTool') {
    throw "Baseline transfer must support pinned Docker tools so collaborators need only Docker."
}

$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("i2s-baseline-test-" + [guid]::NewGuid())
try {
    $objectDirectory = Join-Path $sandbox "objects/historical/provider=fixture"
    New-Item -ItemType Directory -Path $objectDirectory -Force | Out-Null
    $objectPath = Join-Path $objectDirectory "part-00001.parquet"
    [System.IO.File]::WriteAllBytes($objectPath, [byte[]](0x50, 0x41, 0x52, 0x31, 0x01, 0x02))
    [System.IO.File]::WriteAllBytes((Join-Path $sandbox "market-catalog.dump"), [byte[]](1, 2, 3, 4))
    $objectHash = (Get-FileHash -LiteralPath $objectPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $storagePath = Join-Path $sandbox "storage-objects.csv"
    $storageText = "logical_id,bucket_name,object_key,provider_version_id,content_hash,byte_size`n11111111-1111-4111-8111-111111111111,source-market-data,historical/provider=fixture/part-00001.parquet,source-version-1,$objectHash,6`n"
    [System.IO.File]::WriteAllText($storagePath, $storageText)
    $dumpHash = (Get-FileHash -LiteralPath (Join-Path $sandbox "market-catalog.dump") -Algorithm SHA256).Hash.ToLowerInvariant()
    $storageHash = (Get-FileHash -LiteralPath $storagePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $logicalId = "11111111-1111-4111-8111-111111111111"
    $manifest = [ordered]@{
        schema_version = 1
        created_at_utc = "2026-08-12T00:00:00Z"
        source = [ordered]@{ provider = "aws-s3"; bucket = "source-market-data"; region = "ap-northeast-2" }
        required_target_rows = [ordered]@{ strategy_element_catalog_version_ids = @("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa") }
        database = [ordered]@{ file = "market-catalog.dump"; sha256 = $dumpHash; format = "postgresql-custom" }
        storage_catalog = [ordered]@{ file = "storage-objects.csv"; sha256 = $storageHash; format = "postgresql-copy-csv" }
        objects = @([ordered]@{
            logical_id = $logicalId
            key = "historical/provider=fixture/part-00001.parquet"
            source_version_id = "source-version-1"
            content_hash = $objectHash
            byte_size = 6
            file = "objects/historical/provider=fixture/part-00001.parquet"
        })
    }
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $sandbox "baseline-manifest.json") -Encoding utf8

    $result = & $verifyScript -BaselinePath $sandbox -PassThru
    if (-not $result.verified -or $result.object_count -ne 1) {
        throw "A valid fixture baseline was not verified."
    }
    if ($result.objects[0].logical_id -cne $logicalId -or
        $result.objects[0].key -cne "historical/provider=fixture/part-00001.parquet") {
        throw "Verification changed the logical object UUID or object key."
    }

    $manifest.required_target_rows.strategy_element_catalog_version_ids = @("not-a-uuid")
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $sandbox "baseline-manifest.json") -Encoding utf8
    $requiredReferenceRejected = $false
    try { & $verifyScript -BaselinePath $sandbox | Out-Null } catch { $requiredReferenceRejected = $_.Exception.Message -match "non-empty UUID" }
    if (-not $requiredReferenceRejected) { throw "The verifier did not reject an invalid required target UUID." }
    $manifest.required_target_rows.strategy_element_catalog_version_ids = @("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $sandbox "baseline-manifest.json") -Encoding utf8

    $semanticTamper = $storageText.Replace("part-00001.parquet", "part-wrong.parquet")
    [System.IO.File]::WriteAllText($storagePath, $semanticTamper)
    $manifest.storage_catalog.sha256 = (Get-FileHash -LiteralPath $storagePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $sandbox "baseline-manifest.json") -Encoding utf8
    $semanticRejected = $false
    try { & $verifyScript -BaselinePath $sandbox | Out-Null } catch { $semanticRejected = $_.Exception.Message -match "disagree" }
    if (-not $semanticRejected) { throw "The verifier did not reject catalog/manifest semantic drift." }
    [System.IO.File]::WriteAllText($storagePath, $storageText)
    $manifest.storage_catalog.sha256 = (Get-FileHash -LiteralPath $storagePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $sandbox "baseline-manifest.json") -Encoding utf8

    [System.IO.File]::WriteAllBytes($objectPath, [byte[]](0x50, 0x41, 0x52, 0x31, 0x09))
    $tamperRejected = $false
    try {
        & $verifyScript -BaselinePath $sandbox | Out-Null
    }
    catch {
        $tamperRejected = $_.Exception.Message -match "hash|size"
    }
    if (-not $tamperRejected) {
        throw "The verifier did not reject a tampered object."
    }

    Remove-Item -LiteralPath $objectPath -Force
    $missingRejected = $false
    try {
        & $verifyScript -BaselinePath $sandbox | Out-Null
    }
    catch {
        $missingRejected = $_.Exception.Message -match "missing"
    }
    if (-not $missingRejected) {
        throw "The verifier did not reject a missing object."
    }
}
finally {
    if (Test-Path -LiteralPath $sandbox) {
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}

Write-Output "Market-data baseline fixture checks passed."
