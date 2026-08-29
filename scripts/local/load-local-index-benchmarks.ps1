param([string]$EnvironmentFile = '.env.docker')

$ErrorActionPreference = 'Stop'
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$environmentPath = Join-Path $repositoryRoot $EnvironmentFile
if (-not (Test-Path -LiteralPath $environmentPath -PathType Leaf)) {
    throw "Local environment file is missing: $environmentPath"
}

function Read-EnvironmentValue([string]$Name) {
    $line = Get-Content -LiteralPath $environmentPath |
        Where-Object { $_ -match "^$([regex]::Escape($Name))=" } |
        Select-Object -Last 1
    if (-not $line) { throw "Missing $Name in $environmentPath" }
    return $line.Substring($line.IndexOf('=') + 1)
}

$names = @(
    'PIPELINE_WORKER_DATABASE_URL', 'MARKET_DATA_BUCKET',
    'PIPELINE_WORKER_MARKET_HISTORY_REDIS_URI',
    'PIPELINE_WORKER_MARKET_HISTORY_REDIS_KEY_PREFIX',
    'PIPELINE_WORKER_AWS_ENDPOINT_URL', 'PIPELINE_WORKER_OBJECT_STORE_ROOT',
    'AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_DEFAULT_REGION'
)
$saved = @{}
foreach ($name in $names) { $saved[$name] = [Environment]::GetEnvironmentVariable($name) }

try {
    $databaseUser = Read-EnvironmentValue 'POSTGRES_USER'
    $databasePassword = [uri]::EscapeDataString((Read-EnvironmentValue 'POSTGRES_PASSWORD'))
    $databaseName = Read-EnvironmentValue 'POSTGRES_DB'
    $databasePort = Read-EnvironmentValue 'POSTGRES_PORT'
    $redisPort = Read-EnvironmentValue 'REDIS_PORT'
    $minioPort = Read-EnvironmentValue 'MINIO_API_PORT'
    $env:PIPELINE_WORKER_DATABASE_URL = "postgresql+psycopg://${databaseUser}:${databasePassword}@127.0.0.1:${databasePort}/${databaseName}"
    $env:MARKET_DATA_BUCKET = Read-EnvironmentValue 'S3_MARKET_DATA_BUCKET'
    $env:PIPELINE_WORKER_MARKET_HISTORY_REDIS_URI = "redis://127.0.0.1:${redisPort}"
    $env:PIPELINE_WORKER_MARKET_HISTORY_REDIS_KEY_PREFIX = 'i2s'
    $env:PIPELINE_WORKER_AWS_ENDPOINT_URL = "http://127.0.0.1:${minioPort}"
    $env:PIPELINE_WORKER_OBJECT_STORE_ROOT = Join-Path $repositoryRoot '.local\pipeline'
    $env:AWS_ACCESS_KEY_ID = Read-EnvironmentValue 'MINIO_ROOT_USER'
    $env:AWS_SECRET_ACCESS_KEY = Read-EnvironmentValue 'MINIO_ROOT_PASSWORD'
    $env:AWS_DEFAULT_REGION = 'us-east-1'

    Push-Location (Join-Path $repositoryRoot 'data-pipeline')
    try {
        & .\.venv\Scripts\python.exe -m apps.pipeline_worker.load_index_history
        if ($LASTEXITCODE -ne 0) { throw "Canonical index loader exited with $LASTEXITCODE" }
    } finally {
        Pop-Location
    }
} finally {
    foreach ($name in $names) {
        [Environment]::SetEnvironmentVariable($name, $saved[$name])
    }
}
