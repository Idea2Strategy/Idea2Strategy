[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

$requiredFiles = @(
    ".env.docker.example",
    "compose.back.yml",
    "compose.front.yml",
    "infra/terraform/bootstrap/terraform.tfvars.example",
    "infra/terraform/ci-identity/backend.hcl.example",
    "infra/terraform/ci-identity/terraform.tfvars.example",
    "infra/terraform/artifact-foundation/backend.hcl.example",
    "infra/terraform/artifact-foundation/terraform.tfvars.example",
    "infra/terraform/environments/development/backend.hcl.example",
    "infra/terraform/environments/development/terraform.tfvars.example",
    "scripts/test-aws-deployment-prerequisites.ps1",
    "docs/infrastructure/deploy-readiness-runbook.md"
)
foreach ($relativePath in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $root $relativePath) -PathType Leaf)) {
        throw "Required deployment input is missing: $relativePath"
    }
}

$envExample = Get-Content -LiteralPath (Join-Path $root ".env.docker.example") -Raw
foreach ($placeholder in @("__GENERATE_POSTGRES_PASSWORD__", "__GENERATE_MINIO_PASSWORD__")) {
    if (-not $envExample.Contains($placeholder)) {
        throw ".env.docker.example must keep the non-secret placeholder $placeholder."
    }
}
if ($envExample -match '(?im)^DBDIAGRAM_TOKEN\s*=\s*\S+') {
    throw "The environment example must not contain a dbdiagram token."
}

$ignoredInputs = @(".env", ".env.docker", "terraform.tfvars", "backend.hcl", "deployment.tfplan")
foreach ($path in $ignoredInputs) {
    & git -C $root check-ignore --quiet -- $path
    if ($LASTEXITCODE -ne 0) {
        throw "Sensitive/generated deployment input is not ignored: $path"
    }
}

$compose = Get-Command docker -ErrorAction SilentlyContinue
if ($null -eq $compose) {
    throw "Docker is required to validate the merged Compose model."
}
$configJson = & docker compose `
    --env-file (Join-Path $root ".env.docker.example") `
    -f (Join-Path $root "compose.back.yml") `
    -f (Join-Path $root "compose.front.yml") `
    --profile apps config --format json
if ($LASTEXITCODE -ne 0) {
    throw "docker compose config failed."
}
$config = $configJson | ConvertFrom-Json

foreach ($serviceName in @("postgres", "redis", "minio", "localstack", "frontend", "backend-api", "admin-mcp", "backtest-api")) {
    foreach ($port in @($config.services.$serviceName.ports)) {
        if ($port.host_ip -ne "127.0.0.1") {
            throw "$serviceName publishes a port outside localhost."
        }
    }
}
foreach ($serviceName in @("backend-batch", "backend-worker", "market-gateway", "trading-worker", "backtest-worker")) {
    $publishedPorts = $config.services.$serviceName.ports
    if ($null -ne $publishedPorts -and @($publishedPorts).Count -ne 0) {
        throw "$serviceName must not publish a host port."
    }
}

$backendVariables = Get-Content -LiteralPath (Join-Path $root "infra/terraform/environments/development/variables.tf") -Raw
if ($backendVariables -match '(?im)^\s*default\s*=\s*"(?:AKIA|ASIA|[A-Za-z0-9/+]{32,})') {
    throw "Terraform variable defaults appear to contain a credential."
}

Write-Output "Deployment input, secret-safety, and Compose model checks passed."
