param([string]$EnvironmentFile = '.env.docker')

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$environmentPath = Join-Path $repositoryRoot $EnvironmentFile
function Read-EnvironmentValue([string]$Name) {
    $line = Get-Content -LiteralPath $environmentPath |
        Where-Object { $_ -match "^$([regex]::Escape($Name))=" } | Select-Object -Last 1
    if (-not $line) { throw "Missing $Name in $environmentPath" }
    return $line.Substring($line.IndexOf('=') + 1)
}
$names = @(
    'LOCAL_HISTORY_DATABASE_URL', 'LOCAL_HISTORY_S3_BUCKET', 'LOCAL_HISTORY_S3_ENDPOINT',
    'AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_DEFAULT_REGION'
)
$saved = @{}
foreach ($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name) }
try {
    $user = Read-EnvironmentValue 'POSTGRES_USER'
    $password = [uri]::EscapeDataString((Read-EnvironmentValue 'POSTGRES_PASSWORD'))
    $env:LOCAL_HISTORY_DATABASE_URL = "postgresql+psycopg://${user}:${password}@127.0.0.1:$(Read-EnvironmentValue 'POSTGRES_PORT')/$(Read-EnvironmentValue 'POSTGRES_DB')"
    $env:LOCAL_HISTORY_S3_BUCKET = Read-EnvironmentValue 'S3_MARKET_DATA_BUCKET'
    $env:LOCAL_HISTORY_S3_ENDPOINT = "http://127.0.0.1:$(Read-EnvironmentValue 'MINIO_API_PORT')"
    $env:AWS_ACCESS_KEY_ID = Read-EnvironmentValue 'MINIO_ROOT_USER'
    $env:AWS_SECRET_ACCESS_KEY = Read-EnvironmentValue 'MINIO_ROOT_PASSWORD'
    $env:AWS_DEFAULT_REGION = 'us-east-1'
    & (Join-Path $repositoryRoot 'data-pipeline\.venv\Scripts\python.exe') `
        (Join-Path $repositoryRoot 'scripts\local\backfill-local-physical-ranges.py')
    if ($LASTEXITCODE -ne 0) { throw "Physical-range backfill exited with $LASTEXITCODE" }
} finally {
    foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
}
