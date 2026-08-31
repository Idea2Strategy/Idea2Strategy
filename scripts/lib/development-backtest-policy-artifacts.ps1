function Get-DevelopmentBacktestPolicyArtifactSet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$RepositoryRoot
    )

    $artifactRoot = Join-Path $RepositoryRoot "config/development/runtime-policy"
    $manifestPath = Join-Path $artifactRoot "artifact-manifest.json"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Development Backtest policy artifact manifest is missing."
    }

    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $artifacts = [ordered]@{}
    foreach ($entry in @(
            @{ Id = "execution-policy"; File = "execution-policy.json" },
            @{ Id = "runtime-policy"; File = "runtime-policy.json" }
        )) {
        $path = Join-Path $artifactRoot $entry.File
        $property = $manifest.artifacts.PSObject.Properties[$entry.File]
        if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or
            $null -eq $property -or [string]$property.Value -notmatch '^[0-9a-f]{64}$') {
            throw "Development Backtest policy artifact is missing or malformed: $($entry.File)"
        }
        $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -cne [string]$property.Value) {
            throw "Development Backtest policy artifact hash mismatch: $($entry.File)"
        }
        $artifacts[$entry.Id] = [ordered]@{
            id = $entry.Id
            file_name = $entry.File
            path = $path
            sha256 = $actual
            key = "runtime/backtest/$($entry.Id)/$actual/$($entry.File)"
        }
    }

    $material = @(
        "idea2strategy-development-backtest-policy-artifacts-v1"
        "execution_policy_sha256=$($artifacts['execution-policy'].sha256)"
        "runtime_policy_sha256=$($artifacts['runtime-policy'].sha256)"
    ) -join "`n"
    $material += "`n"
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $fingerprint = ([BitConverter]::ToString(
                $sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes($material))
            )).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }

    [pscustomobject]@{
        Fingerprint = $fingerprint
        Artifacts = $artifacts
        ReceiptKey = "runtime/backtest/artifact-sets/$fingerprint/receipt.json"
    }
}
