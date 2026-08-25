[CmdletBinding()]
param(
    [string]$TestEmail = 'developer@idea2strategy.local',
    [string]$TestPassword = 'TestUser!2026',
    [switch]$KeepStack
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$environmentFile = Join-Path $root '.env.docker'
$receiptPath = Join-Path $root '.harness/local/artifacts/basic-strategy-real-e2e-receipt.json'
$frontendWasRunning = -not [string]::IsNullOrWhiteSpace((docker ps --quiet --filter 'name=^idea2strategy-frontend$' | Out-String).Trim())

function Get-EnvironmentValue([string]$Name, [string]$DefaultValue) {
    $line = Get-Content -LiteralPath $environmentFile | Where-Object { $_ -match "^$([regex]::Escape($Name))=" } | Select-Object -Last 1
    if ([string]::IsNullOrWhiteSpace($line)) { return $DefaultValue }
    return $line.Substring($line.IndexOf('=') + 1)
}

Push-Location $root
try {
    & (Join-Path $PSScriptRoot 'dev.ps1') -Action up -Scope all -WithBackend -NoBrowser
    $frontendPort = Get-EnvironmentValue 'FRONTEND_PORT' '15173'
    $env:A23_EXTERNAL_BASE_URL = "http://127.0.0.1:$frontendPort"
    $env:A23_FULL_STACK_E2E = '1'
    $env:A23_TEST_EMAIL = $TestEmail
    $env:A23_TEST_PASSWORD = $TestPassword
    $env:A23_RECEIPT_PATH = $receiptPath
    Push-Location (Join-Path $root 'ui')
    try {
        pnpm exec playwright test --config playwright.real-api.config.ts
        if ($LASTEXITCODE -ne 0) { throw "Real Basic strategy E2E failed with exit code $LASTEXITCODE." }
    }
    finally { Pop-Location }
    if (-not (Test-Path -LiteralPath $receiptPath -PathType Leaf)) {
        throw "Real Basic strategy E2E did not write its receipt: $receiptPath"
    }
    Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json | Out-Null
    Write-Host "Real Basic strategy E2E passed. Receipt: $receiptPath" -ForegroundColor Green
}
finally {
    foreach ($name in @('A23_EXTERNAL_BASE_URL', 'A23_FULL_STACK_E2E', 'A23_TEST_EMAIL', 'A23_TEST_PASSWORD', 'A23_RECEIPT_PATH')) {
        Remove-Item "Env:$name" -ErrorAction SilentlyContinue
    }
    if (-not $frontendWasRunning -and -not $KeepStack) {
        & (Join-Path $PSScriptRoot 'dev.ps1') -Action down -Scope all -WithBackend -NoBrowser
    }
    Pop-Location
}
