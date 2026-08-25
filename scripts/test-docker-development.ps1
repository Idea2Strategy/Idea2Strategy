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
    "scripts/local-development-environment.ps1",
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

. (Join-Path $root "scripts/local-development-environment.ps1")
foreach ($sample in 1..32) {
    $generatedSecret = New-LocalDevelopmentSecret
    $decodedSecret = [Convert]::FromBase64String($generatedSecret)
    if ($decodedSecret.Length -ne 32) {
        throw "Generated local secret must be padded base64 for exactly 32 bytes."
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

foreach ($serviceName in @("flyway", "backend-api", "backend-batch", "backend-worker", "admin-mcp", "trading-worker", "backtest-api", "backtest-worker")) {
    $profiles = @($config.services.$serviceName.profiles)
    if (-not $profiles.Contains("apps")) {
        throw "$serviceName must be opt-in through the apps profile."
    }
}

$backendApiEnvironment = $config.services."backend-api".environment
foreach ($required in @(
    "MARKET_DATA_REDIS_URI",
    "MARKET_DATA_REDIS_KEY_PREFIX",
    "MARKET_DATA_WEBSOCKET_ALLOWED_ORIGIN_PATTERNS"
)) {
    if (-not $backendApiEnvironment.PSObject.Properties.Name.Contains($required) -or
        [string]::IsNullOrWhiteSpace([string]$backendApiEnvironment.$required)) {
        throw "backend-api is missing the local market-history read model wiring: $required"
    }
}

if ($config.services.PSObject.Properties.Name.Contains("market-gateway")) {
    throw "The apps profile must start without the credential-gated live market gateway."
}

$liveConfigArguments = @(
    "compose",
    "--env-file", (Join-Path $root ".env.docker.example"),
    "-f", (Join-Path $root "compose.back.yml"),
    "-p", "idea2strategy-local",
    "--profile", "market-live",
    "config",
    "--format", "json"
)
$liveConfig = (& docker @liveConfigArguments) | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $liveConfig.services.PSObject.Properties.Name.Contains("market-gateway")) {
    throw "The market-live profile must expose the live market gateway."
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

$backtestApiEnvironment = $config.services."backtest-api".environment
foreach ($required in @(
    "BACKTEST_API_HOST",
    "BACKTEST_API_PORT",
    "BACKTEST_AUTHENTICATOR",
    "BACKTEST_COMPILED_PLAN_SOURCE",
    "BACKTEST_DATABASE_URL",
    "BACKTEST_DATASET_MANIFEST_SOURCE",
    "BACKTEST_DEAD_LETTER_SINK",
    "BACKTEST_EXECUTION_POLICY_CATALOG",
    "BACKTEST_OBJECT_STORE",
    "BACKTEST_OWNER_DIRECTORY",
    "BACKTEST_QUEUE_URL",
    "BACKTEST_API_DLQ_URL",
    "CUSTOMER_JWT_SIGNING_KEY_BASE64",
    "BACKTEST_RESULT_INGEST_TOKEN",
    "BACKTEST_RESULT_PRINCIPAL_ID",
    "BACKTEST_EXECUTION_POLICY_FILE",
    "BACKTEST_RESULTS_BUCKET",
    "AWS_ENDPOINT_URL_S3",
    "AWS_ENDPOINT_URL_SQS"
)) {
    if (-not $backtestApiEnvironment.PSObject.Properties.Name.Contains($required) -or
        [string]::IsNullOrWhiteSpace([string]$backtestApiEnvironment.$required)) {
        throw "backtest-api is missing required local runtime wiring: $required"
    }
}

try {
    $customerJwtKey = [Convert]::FromBase64String([string]$backtestApiEnvironment.CUSTOMER_JWT_SIGNING_KEY_BASE64)
}
catch {
    throw "backtest-api customer JWT key must be valid base64: $($_.Exception.Message)"
}
if ($customerJwtKey.Length -lt 32) {
    throw "backtest-api customer JWT key must decode to at least 32 bytes."
}

$backtestWorkerEnvironment = $config.services."backtest-worker".environment
$correlationId = [Guid]::Empty
if (-not [Guid]::TryParse([string]$backtestWorkerEnvironment.BACKTEST_WORKER_CORRELATION_ID, [ref]$correlationId)) {
    throw "backtest-worker correlation id must be a UUID."
}
foreach ($required in @(
    "BACKTEST_JOB_HANDLER",
    "BACKTEST_EXECUTION_KEY_STORE",
    "BACKTEST_REQUEST_HANDLER",
    "BACKTEST_REQUEST_RECEIPT_STORE",
    "BACKTEST_WORKER_ID",
    "BACKTEST_BASIC_QUEUE_URL",
    "BACKTEST_BASIC_DLQ_URL",
    "BACKTEST_CUSTOM_QUEUE_URL",
    "BACKTEST_CUSTOM_DLQ_URL",
    "BACKTEST_COMPETITION_QUEUE_URL",
    "BACKTEST_COMPETITION_DLQ_URL",
    "BACKTEST_BASIC_REQUEST_QUEUE_URL",
    "BACKTEST_BASIC_REQUEST_DLQ_URL",
    "BACKTEST_CUSTOM_REQUEST_QUEUE_URL",
    "BACKTEST_CUSTOM_REQUEST_DLQ_URL",
    "BACKTEST_COMPETITION_REQUEST_QUEUE_URL",
    "BACKTEST_COMPETITION_REQUEST_DLQ_URL",
    "BACKTEST_RESULTS_BUCKET",
    "BACKTEST_MARKET_DATA_BUCKET",
    "BACKTEST_API_BASE_URL",
    "BACKTEST_EXECUTION_POLICY_FILE",
    "BACKTEST_RUNTIME_POLICY_FILE",
    "AWS_ENDPOINT_URL_S3",
    "AWS_ENDPOINT_URL_SQS"
)) {
    if (-not $backtestWorkerEnvironment.PSObject.Properties.Name.Contains($required) -or
        [string]::IsNullOrWhiteSpace([string]$backtestWorkerEnvironment.$required)) {
        throw "backtest-worker is missing required local runtime wiring: $required"
    }
}

$backendRelayRoutes = [string]$config.services."backend-worker".environment.SPRING_APPLICATION_JSON
foreach ($route in @(
    '"OFFICIAL_BACKTEST_REQUESTED":"http://localstack:4566/000000000000/backtest-basic-request"',
    '"CUSTOM_BACKTEST_REQUESTED":"http://localstack:4566/000000000000/backtest-custom-request"',
    '"COMPETITION_BACKTEST_REQUESTED":"http://localstack:4566/000000000000/backtest-competition-request"'
)) {
    if (-not $backendRelayRoutes.Contains($route)) {
        throw "backend-worker does not route a backtest producer envelope to its request boundary: $route"
    }
}

foreach ($serviceName in @("backtest-api", "backtest-worker")) {
    $policyMount = @($config.services.$serviceName.volumes) |
        Where-Object { $_.target -eq "/runtime-policy" } |
        Select-Object -First 1
    if ($null -eq $policyMount -or -not $policyMount.read_only) {
        throw "$serviceName must mount the version-pinned local policy artifacts read-only at /runtime-policy."
    }
}

$localstackInit = Get-Content -LiteralPath (Join-Path $root "infra/docker/localstack/ready.d/10-create-queues.sh") -Raw
foreach ($queueName in @(
    "backtest-basic",
    "backtest-custom",
    "backtest-competition",
    "backtest-basic-request",
    "backtest-custom-request",
    "backtest-competition-request"
)) {
    if (-not $localstackInit.Contains("create_queue `"$queueName`"")) {
        throw "LocalStack does not create the required backtest queue boundary: $queueName"
    }
}

$initialMigrationPath = Join-Path $root "backend/db-migration/src/main/resources/db/migration/V1__initial_schema.sql"
$initialMigration = Get-Content -LiteralPath $initialMigrationPath -Raw
$createTableCount = ([regex]::Matches($initialMigration, "(?im)^CREATE TABLE ")).Count
if ($createTableCount -ne 183) {
    throw "The rebased V1 Flyway baseline must contain 183 tables; found $createTableCount."
}

$devScript = Get-Content -LiteralPath (Join-Path $root "scripts/dev.ps1") -Raw
if ($devScript -notmatch 'Initialize-FlywayBundle' -or
    $devScript -notmatch 'prepare-flyway-bundle\.ps1') {
    throw "The developer apps-profile entry point must prepare the central Flyway bundle before Compose starts."
}

Write-Output "Docker development configuration checks passed."
