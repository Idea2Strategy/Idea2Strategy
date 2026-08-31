[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$prepareBundle = Join-Path $PSScriptRoot 'prepare-flyway-bundle.ps1'
$bundle = Join-Path $root '.local/tmp/flyway-bundle'
$fillAllocationFixture = Join-Path $root 'trading-engine/db/migration-contributions/fixtures/partial_fill_allocation_contract.sql.fixture'

if (-not (Test-Path -LiteralPath $prepareBundle -PathType Leaf)) {
    throw 'Flyway bundle preparation script is missing.'
}
if (-not (Test-Path -LiteralPath $fillAllocationFixture -PathType Leaf)) {
    throw 'The pinned trading-engine revision is missing the required partial-fill allocation contract fixture.'
}

& $prepareBundle | Out-Host
$firstManifestHash = (Get-FileHash -LiteralPath (Join-Path $bundle 'migration-bundle.manifest') -Algorithm SHA256).Hash
$firstBundleDigest = (Get-Content -LiteralPath (Join-Path $bundle 'migration-bundle.sha256') -Raw).Trim()

& $prepareBundle | Out-Host
$secondManifestHash = (Get-FileHash -LiteralPath (Join-Path $bundle 'migration-bundle.manifest') -Algorithm SHA256).Hash
$secondBundleDigest = (Get-Content -LiteralPath (Join-Path $bundle 'migration-bundle.sha256') -Raw).Trim()
if ($firstManifestHash -cne $secondManifestHash -or $firstBundleDigest -cne $secondBundleDigest) {
    throw 'The same exact inputs did not produce a deterministic Flyway bundle.'
}

$suffix = [guid]::NewGuid().ToString('N').Substring(0, 12)
$container = "idea2strategy-migration-$suffix"
$database = 'idea2strategy'
$user = 'idea2strategy'
$password = "migration-$suffix"

function Invoke-Flyway([string]$Command, [switch]$Json) {
    $arguments = @(
        'run', '--rm',
        '--network', "container:$container",
        '-v', "${bundle}:/flyway/sql:ro",
        'redgate/flyway:11-alpine',
        "-url=jdbc:postgresql://localhost:5432/$database",
        "-user=$user",
        "-password=$password",
        '-connectRetries=30'
    )
    if ($Json) {
        $arguments += '-outputType=json'
    }
    $arguments += $Command
    $output = & docker @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Flyway $Command failed."
    }
    return $output
}

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

    Invoke-Flyway 'migrate' | Out-Host
    Invoke-Flyway 'validate' | Out-Host

    $historyBeforeSecondRun = (docker exec -e "PGPASSWORD=$password" $container `
        psql -U $user -d $database -Atc `
        'SELECT count(*) FROM flyway_schema_history WHERE success;').Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($historyBeforeSecondRun)) {
        throw 'Unable to inspect Flyway history after the first migration.'
    }

    Invoke-Flyway 'migrate' | Out-Host
    $historyAfterSecondRun = (docker exec -e "PGPASSWORD=$password" $container `
        psql -U $user -d $database -Atc `
        'SELECT count(*) FROM flyway_schema_history WHERE success;').Trim()
    if ($LASTEXITCODE -ne 0 -or $historyAfterSecondRun -ne $historyBeforeSecondRun) {
        throw 'The second Flyway migrate applied an unexpected migration.'
    }

    $infoOutput = (Invoke-Flyway 'info' -Json) -join "`n"
    if ($infoOutput -match '(?i)"state"\s*:\s*"pending"') {
        throw 'Flyway reports a pending migration after the second migrate.'
    }

    $schemaList = "'identity','strategy','bot','storage','market_data','trading','backtest','performance','competition','operations'"
    $tableCount = (docker exec -e "PGPASSWORD=$password" $container `
        psql -U $user -d $database -Atc `
        "SELECT count(*) FROM information_schema.tables WHERE table_schema IN ($schemaList) AND table_type = 'BASE TABLE';").Trim()
    if ($LASTEXITCODE -ne 0 -or $tableCount -ne '181') {
        throw "Expected 181 application tables after Flyway; found '$tableCount'."
    }

    $fillAllocationTable = (docker exec -e "PGPASSWORD=$password" $container `
        psql -U $user -d $database -Atc `
        "SELECT to_regclass('trading.fill_component_allocations') IS NOT NULL;").Trim()
    if ($LASTEXITCODE -ne 0 -or $fillAllocationTable -ne 't') {
        throw 'The central bundle is missing canonical trading.fill_component_allocations.'
    }

    docker cp $fillAllocationFixture "${container}:/tmp/partial_fill_allocation_contract.sql"
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to copy the partial-fill allocation contract fixture into PostgreSQL.'
    }
    docker exec -e "PGPASSWORD=$password" $container `
        psql -v ON_ERROR_STOP=1 -U $user -d $database `
        -f /tmp/partial_fill_allocation_contract.sql | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw 'The partial-fill allocation contract fixture failed.'
    }

    [pscustomobject]@{
        status = 'passed'
        application_tables = [int]$tableCount
        successful_migrations = [int]$historyAfterSecondRun
        second_run_pending = 0
        partial_fill_allocation_contract = 'passed'
        bundle_sha256 = $secondBundleDigest
        postgres = '16-alpine'
        flyway = '11-alpine'
    } | ConvertTo-Json -Compress
} finally {
    docker rm -f $container *> $null
}
