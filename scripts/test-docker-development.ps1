[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

$requiredFiles = @(
    "compose.front.yml",
    "compose.back.yml",
    "dev.cmd",
    ".env.docker.example",
    ".dockerignore",
    "infra/docker/frontend/Dockerfile",
    "infra/docker/backend/Dockerfile.spring",
    "infra/docker/README.md",
    "backend/db-migration/src/main/resources/db/migration/V1__initial_schema.sql",
    "scripts/prepare-flyway-bundle.ps1",
    "scripts/test-flyway-migration.ps1",
    "scripts/dev.ps1",
    "scripts/dev-menu.ps1",
    "scripts/dev.cmd"
)

foreach ($relativePath in $requiredFiles) {
    $path = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required Docker development file is missing: $relativePath"
    }
}

& (Join-Path $root "scripts/prepare-flyway-bundle.ps1") | Out-Host
$generatedBundle = Join-Path $root ".harness/local/tmp/flyway-bundle"
foreach ($fileName in @("V1__initial_schema.sql", "migration-bundle.manifest", "migration-bundle.sha256")) {
    if (-not (Test-Path -LiteralPath (Join-Path $generatedBundle $fileName) -PathType Leaf)) {
        throw "Generated Flyway bundle is missing: $fileName"
    }
}

$composeArguments = @(
    "compose",
    "--env-file", (Join-Path $root ".env.docker.example"),
    "-f", (Join-Path $root "compose.back.yml"),
    "-f", (Join-Path $root "compose.front.yml"),
    "-p", "idea2strategy-local",
    "--profile", "apps",
    "config",
    "--format", "json"
)

$configJson = & docker @composeArguments
if ($LASTEXITCODE -ne 0) {
    throw "docker compose config failed."
}

$config = $configJson | ConvertFrom-Json
$requiredServices = @(
    "postgres",
    "redis",
    "minio",
    "minio-init",
    "localstack",
    "frontend",
    "flyway",
    "backend-api",
    "backend-batch",
    "backend-worker",
    "admin-mcp",
    "market-gateway",
    "trading-worker",
    "backtest-api",
    "backtest-worker"
)

foreach ($serviceName in $requiredServices) {
    if (-not $config.services.PSObject.Properties.Name.Contains($serviceName)) {
        throw "Compose service is missing: $serviceName"
    }
}

foreach ($serviceName in @("postgres", "redis", "minio", "localstack", "frontend", "backend-api", "admin-mcp", "backtest-api")) {
    $service = $config.services.$serviceName
    foreach ($port in @($service.ports)) {
        if ($port.host_ip -ne "127.0.0.1") {
            throw "$serviceName publishes a port outside localhost: $($port | ConvertTo-Json -Compress)"
        }
    }
}

foreach ($serviceName in @("flyway", "backend-api", "backend-batch", "backend-worker", "admin-mcp", "market-gateway", "trading-worker", "backtest-api", "backtest-worker")) {
    $profiles = @($config.services.$serviceName.profiles)
    if (-not $profiles.Contains("apps")) {
        throw "$serviceName must be opt-in through the apps profile."
    }
}

$flywaySqlMount = @($config.services.flyway.volumes) |
    Where-Object { $_.target -eq "/flyway/sql" } |
    Select-Object -First 1
if ($null -eq $flywaySqlMount) {
    throw "flyway must mount the generated migration bundle at /flyway/sql."
}
if (-not $flywaySqlMount.read_only) {
    throw "The generated Flyway bundle must be mounted read-only."
}
$normalizedFlywaySource = ([string]$flywaySqlMount.source).Replace('\', '/')
if (-not $normalizedFlywaySource.EndsWith('/.harness/local/tmp/flyway-bundle')) {
    throw "flyway must read only the generated bundle; found $normalizedFlywaySource"
}

foreach ($serviceName in @("backend-batch", "backend-worker", "market-gateway", "trading-worker", "backtest-worker")) {
    $publishedPorts = $config.services.$serviceName.ports
    if ($null -ne $publishedPorts -and @($publishedPorts).Count -ne 0) {
        throw "$serviceName must not publish a host port."
    }
}

$initialMigrationPath = Join-Path $root "backend/db-migration/src/main/resources/db/migration/V1__initial_schema.sql"
$initialMigration = Get-Content -LiteralPath $initialMigrationPath -Raw
$createTableCount = ([regex]::Matches($initialMigration, "(?im)^CREATE TABLE ")).Count
if ($createTableCount -ne 137) {
    throw "The immutable V1 Flyway baseline must remain at 137 tables; found $createTableCount."
}

if ($initialMigration -match "(?im)^INSERT INTO ") {
    throw "The initial Flyway migration must not include DBML review-only Records data."
}

$devScript = Get-Content -LiteralPath (Join-Path $root "scripts/dev.ps1") -Raw
if ($devScript -notmatch 'Initialize-FlywayBundle' -or
    $devScript -notmatch 'prepare-flyway-bundle\.ps1') {
    throw "The developer apps-profile entry point must prepare the central Flyway bundle before Compose starts."
}

Write-Output "Docker development configuration checks passed."
