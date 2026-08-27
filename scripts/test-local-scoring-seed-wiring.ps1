[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$bundle = Join-Path $root 'db/flyway-ci-bundle'
$initializer = Join-Path $PSScriptRoot 'initialize-local-scoring-catalog.ps1'
$suffix = [guid]::NewGuid().ToString('N').Substring(0, 12)
$container = "idea2strategy-local-scoring-$suffix"
$database = 'idea2strategy'
$user = 'idea2strategy'
$password = "local-scoring-$suffix"

function Invoke-Docker([string[]]$Arguments) {
    $output = & docker @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Docker command failed: docker $($Arguments -join ' ')"
    }
    return $output
}

try {
    $null = Invoke-Docker @(
        'run', '-d', '--name', $container,
        '--health-cmd', "pg_isready -U $user -d $database",
        '--health-interval', '2s', '--health-timeout', '2s', '--health-retries', '30',
        '-e', "POSTGRES_DB=$database", '-e', "POSTGRES_USER=$user", '-e', "POSTGRES_PASSWORD=$password",
        'postgres:16-alpine'
    )

    $healthy = $false
    foreach ($attempt in 1..30) {
        $status = (& docker inspect --format '{{.State.Health.Status}}' $container 2>$null).Trim()
        if ($status -eq 'healthy') { $healthy = $true; break }
        Start-Sleep -Seconds 2
    }
    if (-not $healthy) { throw 'Temporary PostgreSQL did not become healthy.' }

    $null = Invoke-Docker @(
        'run', '--rm', '--network', "container:$container",
        '-v', "${bundle}:/flyway/sql:ro", 'redgate/flyway:11-alpine',
        "-url=jdbc:postgresql://localhost:5432/$database", "-user=$user", "-password=$password",
        '-connectRetries=30', 'migrate'
    )

    foreach ($iteration in 1..2) {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $initializer `
            -ContainerName $container -PostgresUser $user -PostgresDatabase $database
        if ($LASTEXITCODE -ne 0) { throw "Local scoring initialization failed on pass $iteration." }
    }

    $count = (Invoke-Docker @(
        'exec', '-e', "PGPASSWORD=$password", $container,
        'psql', '-U', $user, '-d', $database, '-X', '-qAt', '-v', 'ON_ERROR_STOP=1',
        '-c', "SELECT count(*) FROM competition.scoring_template_versions WHERE retired_at IS NULL AND version='development-2026-q3-v1';"
    ) | Select-Object -Last 1).Trim()
    if ($count -ne '4') { throw "Expected four selectable scoring templates, found $count." }

    [pscustomobject]@{ status = 'passed'; templates = 4; replay = 'idempotent' } |
        ConvertTo-Json -Compress
}
finally {
    & docker rm -f $container 2>$null | Out-Null
}
