[CmdletBinding()]
param(
    [Parameter(Position=0)][ValidateSet('up', 'rebuild', 'verify', 'reset')][string]$Action = 'up',
    [Parameter(Position=1)][string]$Service,
    [string]$BackupPath,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$stateDirectory = Join-Path $root '.harness/local'
$pathReceipt = Join-Path $stateDirectory 'backup-path.txt'
$safeServices = @('frontend', 'backend-api', 'backend-worker', 'admin-mcp', 'trading-worker', 'backtest-api', 'backtest-worker')

if (-not [string]::IsNullOrWhiteSpace($BackupPath)) {
    $resolved = (Get-Item -LiteralPath $BackupPath -Force).FullName
    if (-not (Test-Path -LiteralPath (Join-Path $resolved 'backup-manifest.json') -PathType Leaf)) { throw 'BackupPath has no backup-manifest.json.' }
    if (-not (Test-Path -LiteralPath $stateDirectory)) { New-Item -ItemType Directory -Path $stateDirectory -Force | Out-Null }
    [System.IO.File]::WriteAllText($pathReceipt, $resolved, [System.Text.UTF8Encoding]::new($false))
    $env:BACKUP_PATH = $resolved
} elseif (Test-Path -LiteralPath $pathReceipt -PathType Leaf) {
    $env:BACKUP_PATH = (Get-Content -LiteralPath $pathReceipt -Raw).Trim()
} elseif ([string]::IsNullOrWhiteSpace($env:BACKUP_PATH)) {
    throw 'Set BACKUP_PATH or pass -BackupPath once.'
}

Push-Location $root
try {
    switch ($Action) {
        'up' {
            & docker compose up -d
        }
        'rebuild' {
            if ($safeServices -notcontains $Service) { throw "Rebuild service must be one of: $($safeServices -join ', ')" }
            & docker compose up -d --build $Service
        }
        'verify' {
            & docker compose run --rm --no-deps data-bootstrap
        }
        'reset' {
            if (-not $Force) { throw 'reset deletes only local Docker volumes. Re-run with -Force.' }
            & docker compose down -v --remove-orphans
            if ($LASTEXITCODE -eq 0) { & docker compose up -d }
        }
    }
    if ($LASTEXITCODE -ne 0) { throw "Local Compose command failed with exit code $LASTEXITCODE." }
} finally {
    Pop-Location
}
