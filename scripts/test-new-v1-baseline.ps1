[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $PSScriptRoot 'new-v1-baseline.ps1'

if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "V1 baseline generator is missing: $scriptPath"
}

$content = Get-Content -LiteralPath $scriptPath -Raw
$requiredTokens = @(
    '[string]$SourceBundle',
    '[string]$Output',
    '[switch]$VerifyOnly',
    'V1__initial_schema.sql',
    'public.flyway_schema_history',
    '--no-owner',
    '--no-privileges',
    'finally',
    'docker network rm'
)
foreach ($token in $requiredTokens) {
    if (-not $content.Contains($token)) {
        throw "Baseline generator is missing required contract token: $token"
    }
}

$missingBundle = Join-Path $root '.harness/local/tmp/missing-v1-bundle'
$output = Join-Path $root '.harness/local/tmp/should-not-exist-v1.sql'
if (Test-Path -LiteralPath $missingBundle) {
    Remove-Item -LiteralPath $missingBundle -Recurse -Force
}
New-Item -ItemType Directory -Path $missingBundle -Force | Out-Null
try {
    & $scriptPath -SourceBundle $missingBundle -Output $output -VerifyOnly *> $null
    if ($LASTEXITCODE -eq 0) {
        throw 'Baseline generator accepted a bundle without V1__initial_schema.sql.'
    }
} catch {
    if ($_.Exception.Message -notmatch 'V1__initial_schema[.]sql') {
        throw
    }
} finally {
    if (Test-Path -LiteralPath $missingBundle) {
        Remove-Item -LiteralPath $missingBundle -Recurse -Force
    }
    if (Test-Path -LiteralPath $output) {
        Remove-Item -LiteralPath $output -Force
    }
}

Write-Host 'New V1 baseline generator contract checks passed.' -ForegroundColor Green
