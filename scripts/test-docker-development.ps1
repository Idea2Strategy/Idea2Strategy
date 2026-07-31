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

$composeArguments = @(
    "compose",
    "--env-file", (Join-Path $root ".env.docker.example"),
    "-f", (Join-Path $root "compose.back.yml"),
    "-f", (Join-Path $root "compose.front.yml"),
    "-p", "idea2strategy-local",
    "--profile", "backend-apps",
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
    "frontend",
    "flyway",
    "backend",
    "batch",
    "backtest"
)

foreach ($serviceName in $requiredServices) {
    if (-not $config.services.PSObject.Properties.Name.Contains($serviceName)) {
        throw "Compose service is missing: $serviceName"
    }
}

foreach ($serviceName in @("postgres", "redis", "minio", "frontend", "backend", "batch", "backtest")) {
    $service = $config.services.$serviceName
    foreach ($port in @($service.ports)) {
        if ($port.host_ip -ne "127.0.0.1") {
            throw "$serviceName publishes a port outside localhost: $($port | ConvertTo-Json -Compress)"
        }
    }
}

foreach ($serviceName in @("flyway", "backend", "batch", "backtest")) {
    $profiles = @($config.services.$serviceName.profiles)
    if (-not $profiles.Contains("backend-apps")) {
        throw "$serviceName must be opt-in through the backend-apps profile."
    }
}

Write-Output "Docker development configuration checks passed."
