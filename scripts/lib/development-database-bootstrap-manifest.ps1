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
