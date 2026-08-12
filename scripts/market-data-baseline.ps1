Set-StrictMode -Version Latest

function Resolve-BaselineRoot {
    param([Parameter(Mandatory = $true)][string]$BaselinePath)

    if (-not (Test-Path -LiteralPath $BaselinePath -PathType Container)) {
        throw "Baseline directory is missing: $BaselinePath"
    }
    return (Resolve-Path -LiteralPath $BaselinePath).Path
}

function Resolve-BaselineFile {
    param(
        [Parameter(Mandatory = $true)][string]$BaselineRoot,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        throw "Baseline file path must be relative: $RelativePath"
    }
    $normalised = $RelativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $BaselineRoot $normalised))
    $rootPrefix = $BaselineRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $candidate.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Baseline file path escapes the baseline directory: $RelativePath"
    }
    return $candidate
}

function Get-LowerSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Read-BaselineManifest {
    param([Parameter(Mandatory = $true)][string]$BaselineRoot)

    $manifestPath = Join-Path $BaselineRoot "baseline-manifest.json"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Baseline manifest is missing: $manifestPath"
    }
    try {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    }
    catch {
        throw "Baseline manifest is not valid JSON: $($_.Exception.Message)"
    }
    if ([int]$manifest.schema_version -ne 1) {
        throw "Unsupported baseline manifest schema_version: $($manifest.schema_version)"
    }
    return $manifest
}

function Assert-Sha256Text {
    param(
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$Label
    )
    if ($Value -cnotmatch '^[0-9a-f]{64}$') {
        throw "$Label must be a lowercase SHA-256 value."
    }
}

function Assert-CommandAvailable {
    param([Parameter(Mandatory = $true)][string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command is unavailable: $Name"
    }
}

function Invoke-CheckedNative {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$Capture
    )

    if ($Capture) {
        $output = & $FilePath @Arguments 2>&1
    }
    else {
        & $FilePath @Arguments
        $output = @()
    }
    if ($LASTEXITCODE -ne 0) {
        $safeMessage = ($output | Out-String).Trim()
        throw "$FilePath failed with exit code $LASTEXITCODE. $safeMessage"
    }
    if ($Capture) {
        return $output
    }
}
