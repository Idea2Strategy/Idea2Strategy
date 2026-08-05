[CmdletBinding()]
param()

# Refreshes the committed db/flyway-ci-bundle from the exact submodule revisions
# pinned by the root HEAD. Run this in the same change that moves the backend,
# trading-engine, or data-pipeline gitlink; test-flyway-ci-bundle.ps1 fails closed until the pinned
# metadata matches the root gitlinks. The bundle content is regenerated through
# prepare-flyway-bundle.ps1, so this never weakens the pin: every digest is
# recomputed from the actual sources at the pinned revisions.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$committedBundle = Join-Path $root 'db/flyway-ci-bundle'
$generatedBundle = Join-Path $root '.harness/local/tmp/flyway-bundle'
$tradingFixtures = Join-Path $root 'trading-engine/db/migration-contributions/fixtures'
$metadataPath = Join-Path $committedBundle 'source-revisions.json'

if (-not (Test-Path -LiteralPath $committedBundle -PathType Container)) {
    throw "Committed Flyway CI bundle directory is missing: $committedBundle"
}

# prepare-flyway-bundle.ps1 already refuses dirty or mispinned submodules, so a
# successful run proves the generated bundle reflects the exact root gitlinks.
& (Join-Path $PSScriptRoot 'prepare-flyway-bundle.ps1')
if ($LASTEXITCODE -ne 0) {
    throw 'prepare-flyway-bundle.ps1 failed; the committed bundle was not touched.'
}

function Get-GitlinkRevision([string]$Path) {
    $entry = (& git -C $root ls-tree HEAD -- $Path) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $entry -notmatch '^160000\s+commit\s+([0-9a-f]{40})\s+') {
        throw "Unable to resolve root gitlink: $Path"
    }
    return $Matches[1]
}

function Get-NormalizedTextSha256([string]$Path) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $normalized = New-Object System.IO.MemoryStream
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        for ($index = 0; $index -lt $bytes.Length; $index++) {
            if ($bytes[$index] -eq 13 -and $index + 1 -lt $bytes.Length -and $bytes[$index + 1] -eq 10) {
                $normalized.WriteByte(10)
                $index++
            } else {
                $normalized.WriteByte($bytes[$index])
            }
        }
        return ([System.BitConverter]::ToString($sha256.ComputeHash($normalized.ToArray()))).Replace('-', '').ToLowerInvariant()
    } finally {
        $sha256.Dispose()
        $normalized.Dispose()
    }
}

function Get-Sha256OfText([string]$Text) {
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($Text)
        return ([System.BitConverter]::ToString($sha256.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    } finally {
        $sha256.Dispose()
    }
}

# Replace the generated portion of the committed bundle: migrations, manifest,
# and manifest digest. Root-owned .sql.fixture files are deliberately kept; the
# two trading-owned fixtures are re-vendored from the pinned trading revision.
Get-ChildItem -LiteralPath $committedBundle -Filter '*.sql' | Remove-Item -Force
foreach ($name in @('migration-bundle.manifest', 'migration-bundle.sha256')) {
    Copy-Item -LiteralPath (Join-Path $generatedBundle $name) -Destination (Join-Path $committedBundle $name) -Force
}
Get-ChildItem -LiteralPath $generatedBundle -Filter '*.sql' | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $committedBundle $_.Name) -Force
}

function Convert-CrlfToLf([byte[]]$Bytes) {
    $normalized = New-Object System.IO.MemoryStream
    try {
        for ($index = 0; $index -lt $Bytes.Length; $index++) {
            if ($Bytes[$index] -eq 13 -and $index + 1 -lt $Bytes.Length -and $Bytes[$index + 1] -eq 10) {
                $normalized.WriteByte(10)
                $index++
            } else {
                $normalized.WriteByte($Bytes[$index])
            }
        }
        return $normalized.ToArray()
    } finally {
        $normalized.Dispose()
    }
}

foreach ($fixture in @('partial_fill_allocation_contract.sql.fixture', 'trading_read_projection_contract.sql.fixture')) {
    $source = Join-Path $tradingFixtures $fixture
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Trading-owned fixture is missing from the pinned trading revision: $fixture"
    }
    # A Windows checkout may materialize CRLF; the committed bundle is always LF.
    [System.IO.File]::WriteAllBytes(
        (Join-Path $committedBundle $fixture),
        (Convert-CrlfToLf ([System.IO.File]::ReadAllBytes($source)))
    )
}

# Recompute every metadata digest exactly the way test-flyway-ci-bundle.ps1
# verifies it, so the test remains the single source of truth.
$bundleSha256 = (Get-Content -LiteralPath (Join-Path $committedBundle 'migration-bundle.sha256') -Raw).Trim()
if ($bundleSha256 -notmatch '^[0-9a-f]{64}$') {
    throw 'Generated bundle digest is not a lowercase SHA-256 value.'
}
$readContractSha256 = Get-NormalizedTextSha256 (Join-Path $committedBundle 'trading_read_projection_contract.sql.fixture')

$baselineManifest = "idea2strategy-canonical-baseline-v1`n"
foreach ($migration in (Get-ChildItem -LiteralPath $committedBundle -Filter '*.sql' | Sort-Object -Property Name -CaseSensitive)) {
    $baselineManifest += "$($migration.Name)`t$(Get-NormalizedTextSha256 $migration.FullName)`n"
}
$canonicalBaselineSha256 = Get-Sha256OfText $baselineManifest

$metadataJson = @(
    '{',
    '  "format": "idea2strategy-flyway-ci-bundle-v1",',
    "  `"backend_gitlink`": `"$(Get-GitlinkRevision 'backend')`",",
    "  `"trading_gitlink`": `"$(Get-GitlinkRevision 'trading-engine')`",",
    "  `"data_pipeline_gitlink`": `"$(Get-GitlinkRevision 'data-pipeline')`",",
    "  `"bundle_sha256`": `"$bundleSha256`",",
    "  `"trading_read_projection_contract_sha256`": `"$readContractSha256`",",
    "  `"canonical_baseline_sha256`": `"$canonicalBaselineSha256`"",
    '}'
) -join "`n"
[System.IO.File]::WriteAllBytes($metadataPath, (New-Object System.Text.UTF8Encoding($false)).GetBytes($metadataJson + "`n"))

[pscustomobject]@{
    status = 'refreshed'
    bundle = $committedBundle
    backend_gitlink = (Get-GitlinkRevision 'backend')
    trading_gitlink = (Get-GitlinkRevision 'trading-engine')
    data_pipeline_gitlink = (Get-GitlinkRevision 'data-pipeline')
    bundle_sha256 = $bundleSha256
    next_step = 'Run scripts/test-flyway-ci-bundle.ps1 to prove the refreshed bundle, then commit db/flyway-ci-bundle together with the gitlink change.'
} | ConvertTo-Json -Compress
