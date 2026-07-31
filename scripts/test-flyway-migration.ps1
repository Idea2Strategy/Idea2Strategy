[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$migrationPath = Join-Path $root 'backend/db-migration/src/main/resources/db/migration'

if (-not (Test-Path -LiteralPath $migrationPath -PathType Container)) {
    throw 'Flyway migration directory is missing.'
}

$suffix = [guid]::NewGuid().ToString('N').Substring(0, 12)
$container = "idea2strategy-migration-$suffix"
$database = 'idea2strategy'
$user = 'idea2strategy'
$password = "migration-$suffix"

try {
    $started = docker run -d `
        --name $container `
        --health-cmd "pg_isready -U $user -d $database" `
        --health-interval 2s `
        --health-timeout 2s `
        --health-retries 30 `
        -e "POSTGRES_DB=$database" `
        -e "POSTGRES_USER=$user" `
        -e "POSTGRES_PASSWORD=$password" `
        postgres:16-alpine
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($started)) {
        throw 'Failed to start the temporary PostgreSQL container.'
    }

    $healthy = $false
    for ($attempt = 0; $attempt -lt 45; $attempt++) {
        $health = (docker inspect --format '{{.State.Health.Status}}' $container 2>$null).Trim()
        if ($health -eq 'healthy') {
            $healthy = $true
            break
        }
        if ($health -eq 'unhealthy') {
            throw 'Temporary PostgreSQL became unhealthy.'
        }
        Start-Sleep -Seconds 2
    }
    if (-not $healthy) {
        throw 'Timed out waiting for temporary PostgreSQL.'
    }

    docker run --rm `
        --network "container:$container" `
        -v "${migrationPath}:/flyway/sql:ro" `
        redgate/flyway:11-alpine `
        "-url=jdbc:postgresql://localhost:5432/$database" `
        "-user=$user" `
        "-password=$password" `
        '-connectRetries=30' `
        migrate
    if ($LASTEXITCODE -ne 0) {
        throw 'Flyway migration failed.'
    }

    $schemaList = "'identity','strategy','bot','storage','market_data','trading','backtest','performance','competition','operations'"
    $tableCount = (docker exec -e "PGPASSWORD=$password" $container `
        psql -U $user -d $database -Atc `
        "SELECT count(*) FROM information_schema.tables WHERE table_schema IN ($schemaList) AND table_type = 'BASE TABLE';").Trim()
    if ($LASTEXITCODE -ne 0 -or $tableCount -ne '137') {
        throw "Expected 137 application tables after Flyway; found '$tableCount'."
    }

    $historyCount = (docker exec -e "PGPASSWORD=$password" $container `
        psql -U $user -d $database -Atc `
        'SELECT count(*) FROM flyway_schema_history WHERE success;').Trim()
    if ($LASTEXITCODE -ne 0 -or $historyCount -lt 1) {
        throw 'Flyway schema history does not contain a successful migration.'
    }

    [pscustomobject]@{
        status = 'passed'
        application_tables = [int]$tableCount
        successful_migrations = [int]$historyCount
        postgres = '16-alpine'
        flyway = '11-alpine'
    } | ConvertTo-Json -Compress
} finally {
    docker rm -f $container *> $null
}
