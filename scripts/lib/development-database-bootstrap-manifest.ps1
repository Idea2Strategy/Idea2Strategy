function Get-ValidatedDevelopmentFlywayBundle {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BundleRoot
    )

    Set-StrictMode -Version 2.0

    if (-not (Test-Path -LiteralPath $BundleRoot -PathType Container)) {
        throw "Flyway bundle directory is missing: $BundleRoot"
    }

    $manifestPath = Join-Path $BundleRoot "migration-bundle.manifest"
    $digestPath = Join-Path $BundleRoot "migration-bundle.sha256"
    foreach ($path in @($manifestPath, $digestPath)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Required Flyway bundle input is missing: $path"
        }
    }

    $bundleDigest = (Get-Content -LiteralPath $digestPath -Raw).Trim()
    if ($bundleDigest -notmatch '^[0-9a-f]{64}$') {
        throw "Flyway bundle digest is malformed."
    }
    $actualManifestDigest = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualManifestDigest -cne $bundleDigest) {
        throw "Flyway manifest digest mismatch."
    }

    $manifestLines = @(Get-Content -LiteralPath $manifestPath)
    if ($manifestLines.Count -eq 0 -or $manifestLines[0] -cne "idea2strategy-flyway-bundle-v1") {
        throw "Flyway manifest header is invalid."
    }
    if ($manifestLines.Count -eq 1) {
        throw "Flyway manifest must contain at least one migration."
    }

    $entries = @()
    $listedFiles = @{}
    $listedVersions = @{}
    foreach ($line in $manifestLines[1..($manifestLines.Count - 1)]) {
        if ($line -notmatch '^([VR][A-Za-z0-9_.-]+\.sql)\t([0-9a-f]{64})$') {
            throw "Invalid Flyway manifest entry."
        }

        $migrationName = $Matches[1]
        $expectedHash = $Matches[2]
        $normalizedName = $migrationName.ToLowerInvariant()
        if ($listedFiles.ContainsKey($normalizedName)) {
            throw "Flyway manifest contains a duplicate migration: $migrationName"
        }
        $listedFiles[$normalizedName] = $true

        if ($migrationName -match '^V([0-9]+(?:[._][0-9]+)*)__') {
            $normalizedVersion = (($Matches[1] -split '[._]') | ForEach-Object {
                    $segment = $_.TrimStart('0')
                    if ([string]::IsNullOrEmpty($segment)) { '0' } else { $segment }
                }) -join '.'
            if ($listedVersions.ContainsKey($normalizedVersion)) {
                throw "Flyway manifest contains a duplicate version '$normalizedVersion': $migrationName and $($listedVersions[$normalizedVersion])"
            }
            $listedVersions[$normalizedVersion] = $migrationName
        }

        $migrationPath = Join-Path $BundleRoot $migrationName
        if (-not (Test-Path -LiteralPath $migrationPath -PathType Leaf)) {
            throw "Flyway migration is missing: $migrationName"
        }
        $actualHash = (Get-FileHash -LiteralPath $migrationPath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -cne $expectedHash) {
            throw "Flyway migration checksum mismatch: $migrationName"
        }

        $entries += [pscustomobject]@{
            Name = $migrationName
            Sha256 = $expectedHash
        }
    }

    $bundleSqlFiles = @(Get-ChildItem -LiteralPath $BundleRoot -Filter "*.sql" -File)
    foreach ($sqlFile in $bundleSqlFiles) {
        if (-not $listedFiles.ContainsKey($sqlFile.Name.ToLowerInvariant())) {
            throw "Flyway migration is not listed in the manifest: $($sqlFile.Name)"
        }
    }
    if ($bundleSqlFiles.Count -ne $entries.Count) {
        throw "Flyway bundle SQL file count does not match the exact manifest."
    }

    return [pscustomobject]@{
        Digest = $bundleDigest
        ManifestPath = $manifestPath
        MigrationCount = $entries.Count
        Entries = $entries
    }
}

function Get-DevelopmentDatabaseBootstrapFingerprint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{64}$')][string]$BundleSha256,
        [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{64}$')][string]$PolicySeedSha256,
        [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{64}$')][string]$ScoringSeedSha256,
        [Parameter(Mandatory = $true)][ValidatePattern('^[a-z][a-z0-9_]{2,62}$')][string]$DatabaseName
    )

    $material = @(
        "idea2strategy-development-database-bootstrap-v2"
        "bundle_sha256=$BundleSha256"
        "policy_seed_sha256=$PolicySeedSha256"
        "scoring_seed_sha256=$ScoringSeedSha256"
        "database_name=$DatabaseName"
    ) -join "`n"
    $material += "`n"

    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($material)
        return ([BitConverter]::ToString($sha256.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }
}

function Get-DevelopmentScoringSeedIds {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SeedSqlPath
    )

    if (-not (Test-Path -LiteralPath $SeedSqlPath -PathType Leaf)) {
        throw "Scoring seed SQL is missing: $SeedSqlPath"
    }
    $seedSql = Get-Content -LiteralPath $SeedSqlPath -Raw
    $ids = @([regex]::Matches($seedSql, "'([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})'") |
        ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    if ($ids.Count -eq 0) {
        throw "Scoring seed SQL must identify at least one immutable scoring version ID."
    }
    return $ids
}
