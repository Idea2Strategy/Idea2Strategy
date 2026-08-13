[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$compose = Get-Content -LiteralPath (Join-Path $root 'compose.back.yml') -Raw
$bootstrap = Get-Content -LiteralPath (Join-Path $root 'infra/docker/local-bootstrap/bootstrap.py') -Raw
$wrapper = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'local.ps1') -Raw
$pin = Get-Content -LiteralPath (Join-Path $root 'config/fixed-market-data-baseline.json') -Raw | ConvertFrom-Json
foreach ($required in @(
    'data-bootstrap', '${BACKUP_PATH:', 'read_only: true', 'bootstrap-state:/state',
    'service_completed_successfully', 'profiles: [collection-disabled]',
    'APP_POSTGRES_USER', 'APP_S3_ACCESS_KEY'
)) { if (-not $compose.Contains($required)) { throw "Compose bootstrap omits: $required" } }
foreach ($required in @(
    'manifest SHA-256 is not the team baseline', 'ensure_legacy_database',
    'restore-raw-market-data.py', 'migrate-legacy-market-data.py',
    'verify-fixed-market-data.py', 'ALREADY_BOOTSTRAPPED',
    'transaction_timeout', 'DROP DATABASE',
    'InsufficientPrivilege', 'local_results', 'unexpectedly wrote to fixed market bucket'
)) { if (-not $bootstrap.Contains($required)) { throw "Bootstrap gate omits: $required" } }
foreach ($forbidden in @('--secret-key', '--minio-secret-key', '--legacy-database-url', '--canonical-database-url')) {
    if ($bootstrap.Contains($forbidden)) { throw "Bootstrap exposes a credential in process arguments: $forbidden" }
}
foreach ($required in @('docker compose up -d', 'docker compose up -d --build', 'docker compose down -v', 'data-bootstrap')) {
    if (-not $wrapper.Contains($required)) { throw "Simple local wrapper omits: $required" }
}
if ($pin.s3_versions -ne 10798 -or $pin.parquet_files -ne 10529 -or $pin.storage_objects -ne 768) { throw 'Pinned team baseline counts drifted.' }
Write-Host 'Compose fixed-data bootstrap contract tests passed.'
