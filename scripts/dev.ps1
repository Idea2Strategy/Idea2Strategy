[CmdletBinding()]
param(
    [ValidateSet("up", "down", "restart", "status", "logs", "open", "reset")]
    [string]$Action = "up",

    [ValidateSet("all", "front", "back")]
    [string]$Scope = "all",

    [ValidateSet("frontend", "backend-api", "backend-batch", "backend-worker", "admin-mcp", "market-gateway", "trading-worker", "backtest-api", "backtest-worker", "all")]
    [string]$Service = "all",

    [switch]$WithBackend,
    [switch]$NoBrowser,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$environmentFile = Join-Path $root ".env.docker"
$environmentTemplate = Join-Path $root ".env.docker.example"
$composeBack = Join-Path $root "compose.back.yml"
$composeFront = Join-Path $root "compose.front.yml"
$env:COMPOSE_IGNORE_ORPHANS = "true"
$targetedService = $Service -cne "all"
$includeApps = $WithBackend -or ($targetedService -and $Service -cne "frontend")

if ($targetedService -and $Scope -eq "front" -and $Service -cne "frontend") {
    throw "-Scope front can target only the frontend service."
}
if ($targetedService -and $Scope -eq "back" -and $Service -ceq "frontend") {
    throw "-Scope back cannot target the frontend service."
}
if ($targetedService -and $Action -eq "reset") {
    throw "reset applies to the complete local environment; omit -Service."
}

function New-RandomSecret {
    $bytes = New-Object byte[] 32
    $generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $generator.GetBytes($bytes)
    }
    finally {
        $generator.Dispose()
    }

    return [Convert]::ToBase64String($bytes).TrimEnd("=").Replace("+", "A").Replace("/", "B")
}

# backend-api registers its customer identity surface only when all five
# identity.crypto keys are present (fail-closed, root #266), so both a fresh
# bootstrap and an existing .env.docker created before the keys were added
# must end up carrying generated values.
$identityCryptoKeys = @(
    "IDENTITY_CRYPTO_EMAIL_ENCRYPTION_KEY",
    "IDENTITY_CRYPTO_LOOKUP_HMAC_KEY",
    "IDENTITY_CRYPTO_VERIFICATION_HMAC_KEY",
    "IDENTITY_CRYPTO_REFRESH_TOKEN_HMAC_KEY",
    "IDENTITY_CRYPTO_CUSTOMER_JWT_SIGNING_KEY"
)
$backtestLocalSecrets = @("BACKTEST_RESULT_INGEST_TOKEN")
$fixedDataSecretDefaults = [ordered]@{
    APP_POSTGRES_USER = "idea2strategy_local_app"
    APP_POSTGRES_PASSWORD = $null
    APP_S3_ACCESS_KEY = "i2s-local-app"
    APP_S3_SECRET_KEY = $null
}

function Initialize-EnvironmentFile {
    if (Test-Path -LiteralPath $environmentFile) {
        Add-MissingIdentityCryptoKeys
        Add-MissingBacktestSecrets
        Add-MissingFixedDataSecrets
        return
    }

    if (-not (Test-Path -LiteralPath $environmentTemplate -PathType Leaf)) {
        throw "Environment template is missing: $environmentTemplate"
    }

    $content = Get-Content -LiteralPath $environmentTemplate -Raw
    $content = $content.Replace("__GENERATE_POSTGRES_PASSWORD__", (New-RandomSecret))
    $content = $content.Replace("__GENERATE_MINIO_PASSWORD__", (New-RandomSecret))
    foreach ($keyName in $identityCryptoKeys) {
        $placeholder = "__GENERATE_" + $keyName.Replace("IDENTITY_CRYPTO_", "IDENTITY_") + "__"
        $content = $content.Replace($placeholder, (New-RandomSecret))
    }
    foreach ($keyName in $backtestLocalSecrets) {
        $content = $content.Replace("__GENERATE_$keyName__", (New-RandomSecret))
    }
    $content = $content.Replace("__GENERATE_APP_POSTGRES_PASSWORD__", (New-RandomSecret))
    $content = $content.Replace("__GENERATE_APP_S3_SECRET_KEY__", (New-RandomSecret))
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($environmentFile, $content, $encoding)
    Write-Host "Created local-only environment file: .env.docker" -ForegroundColor Green
}

function Add-MissingIdentityCryptoKeys {
    $content = Get-Content -LiteralPath $environmentFile -Raw
    $appended = @()
    foreach ($keyName in $identityCryptoKeys) {
        if ($content -notmatch "(?im)^$keyName\s*=\s*\S+") {
            $appended += "$keyName=$(New-RandomSecret)"
        }
    }
    if ($appended.Count -eq 0) {
        return
    }
    if (-not $content.EndsWith("`n")) {
        $content += "`n"
    }
    $content += ($appended -join "`n") + "`n"
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($environmentFile, $content, $encoding)
    Write-Host "Added generated identity crypto keys to .env.docker" -ForegroundColor Green
}

function Add-MissingBacktestSecrets {
    $content = Get-Content -LiteralPath $environmentFile -Raw
    $appended = @()
    foreach ($keyName in $backtestLocalSecrets) {
        if ($content -notmatch "(?im)^$keyName\s*=\s*\S+") {
            $appended += "$keyName=$(New-RandomSecret)"
        }
    }
    if ($appended.Count -eq 0) {
        return
    }
    if (-not $content.EndsWith("`n")) {
        $content += "`n"
    }
    $content += ($appended -join "`n") + "`n"
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($environmentFile, $content, $encoding)
    Write-Host "Added generated backtest local secrets to .env.docker" -ForegroundColor Green
}

function Add-MissingFixedDataSecrets {
    $content = Get-Content -LiteralPath $environmentFile -Raw
    $appended = @()
    foreach ($entry in $fixedDataSecretDefaults.GetEnumerator()) {
        if ($content -notmatch "(?im)^$($entry.Key)\s*=\s*\S+") {
            $value = if ($null -eq $entry.Value) { New-RandomSecret } else { $entry.Value }
            $appended += "$($entry.Key)=$value"
        }
    }
    if ($appended.Count -eq 0) { return }
    if (-not $content.EndsWith("`n")) { $content += "`n" }
    $content += ($appended -join "`n") + "`n"
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($environmentFile, $content, $encoding)
    Write-Host "Added generated fixed-data application credentials to .env.docker" -ForegroundColor Green
}

function Get-EnvironmentValue {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$DefaultValue
    )

    foreach ($line in Get-Content -LiteralPath $environmentFile) {
        if ($line -match "^\s*$([Regex]::Escape($Name))=(.*)$") {
            return $Matches[1].Trim()
        }
    }

    return $DefaultValue
}

function Test-DockerEngine {
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "SilentlyContinue"
        & docker info *> $null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

function Start-DockerEngine {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw "Docker CLI is not installed. Install Docker Desktop first."
    }

    if (Test-DockerEngine) {
        return
    }

    $dockerDesktop = Join-Path $env:ProgramFiles "Docker\Docker\Docker Desktop.exe"
    if (-not (Test-Path -LiteralPath $dockerDesktop -PathType Leaf)) {
        throw "Docker engine is not running and Docker Desktop was not found: $dockerDesktop"
    }

    Write-Host "Starting Docker Desktop..." -ForegroundColor Yellow
    Start-Process -FilePath $dockerDesktop -WindowStyle Hidden

    $deadline = (Get-Date).AddMinutes(3)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 3
        if (Test-DockerEngine) {
            Write-Host "Docker engine is ready." -ForegroundColor Green
            return
        }
    }

    throw "Docker Desktop did not become ready within 3 minutes."
}

function Get-ComposeBaseArguments {
    $arguments = @(
        "compose",
        "--env-file", $environmentFile
    )

    switch ($Scope) {
        "front" {
            $arguments += @("-f", $composeFront)
        }
        "back" {
            $arguments += @("-f", $composeBack)
        }
        "all" {
            $arguments += @("-f", $composeBack, "-f", $composeFront)
        }
    }

    $arguments += @("-p", "idea2strategy-local")

    if ($includeApps) {
        if ($Scope -eq "front") {
            throw "-WithBackend cannot be used with -Scope front."
        }
        $backendGradleSettings = Join-Path $root "backend\settings.gradle.kts"
        $tradingGradleSettings = Join-Path $root "trading-engine\settings.gradle.kts"
        $backtestProject = Join-Path $root "backtest-engine\pyproject.toml"
        $migrationDirectory = Join-Path $root "backend\db-migration\src\main\resources\db\migration"
        foreach ($requiredProjectFile in @(
            $backendGradleSettings,
            $tradingGradleSettings,
            $backtestProject
        )) {
            if (-not (Test-Path -LiteralPath $requiredProjectFile -PathType Leaf)) {
                throw "Service source is not ready. Missing: $requiredProjectFile"
            }
        }
        if (-not (Test-Path -LiteralPath $migrationDirectory -PathType Container)) {
            throw "Backend Flyway migrations are not ready. Missing: backend/db-migration/src/main/resources/db/migration"
        }
        $arguments += @("--profile", "apps")
    }

    return $arguments
}

function Invoke-Compose {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    $allArguments = @(Get-ComposeBaseArguments) + $Arguments
    & docker @allArguments
    $exitCode = $LASTEXITCODE
    if (-not $AllowFailure -and $exitCode -ne 0) {
        throw "Docker Compose command failed with exit code $exitCode."
    }
}

function Initialize-FlywayBundle {
    if (-not $includeApps) {
        return
    }
    $prepareBundle = Join-Path $PSScriptRoot "prepare-flyway-bundle.ps1"
    if (-not (Test-Path -LiteralPath $prepareBundle -PathType Leaf)) {
        throw "Flyway bundle preparation script is missing: $prepareBundle"
    }
    & $prepareBundle | Out-Host
}

function Test-HttpEndpoint {
    param([Parameter(Mandatory = $true)][string]$Uri)

    try {
        $response = Invoke-WebRequest -Uri $Uri -UseBasicParsing -TimeoutSec 3
        return $response.StatusCode -ge 200 -and $response.StatusCode -lt 500
    }
    catch {
        return $false
    }
}

function Test-ContainerCommand {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $allArguments = @(Get-ComposeBaseArguments) + @("exec", "-T") + $Arguments
    & docker @allArguments *> $null
    return $LASTEXITCODE -eq 0
}

function Wait-DevelopmentEnvironment {
    $frontendPort = Get-EnvironmentValue -Name "FRONTEND_PORT" -DefaultValue "15173"
    $minioApiPort = Get-EnvironmentValue -Name "MINIO_API_PORT" -DefaultValue "19000"
    $postgresUser = Get-EnvironmentValue -Name "POSTGRES_USER" -DefaultValue "idea2strategy"
    $postgresDatabase = Get-EnvironmentValue -Name "POSTGRES_DB" -DefaultValue "idea2strategy"
    $frontendUrl = "http://localhost:$frontendPort"
    $minioHealthUrl = "http://localhost:$minioApiPort/minio/health/live"
    # A first run builds nine images and the probes themselves crawl while the
    # machine is compiling, so a fixed four minutes lost the race on slower
    # hosts even though the stack came up fine moments later (root #266).
    $readyTimeoutMinutes = [int](Get-EnvironmentValue -Name "DEV_READY_TIMEOUT_MINUTES" -DefaultValue "10")
    $deadline = (Get-Date).AddMinutes($readyTimeoutMinutes)

    Write-Host "Waiting for local services..." -ForegroundColor Yellow
    while ((Get-Date) -lt $deadline) {
        $postgresReady = $true
        $redisReady = $true
        $minioReady = $true
        $localstackReady = $true
        $frontendReady = $true

        if ($Scope -in @("all", "back")) {
            $postgresReady = Test-ContainerCommand -Arguments @(
                "postgres", "pg_isready", "-U", $postgresUser, "-d", $postgresDatabase
            )
            $redisReady = Test-ContainerCommand -Arguments @("redis", "redis-cli", "ping")
            $minioReady = Test-HttpEndpoint -Uri $minioHealthUrl
            $localstackReady = Test-ContainerCommand -Arguments @(
                "localstack", "awslocal", "sqs", "list-queues"
            )
        }

        if ($Scope -in @("all", "front")) {
            $frontendReady = Test-HttpEndpoint -Uri $frontendUrl
        }

        if ($postgresReady -and $redisReady -and $minioReady -and $localstackReady -and $frontendReady) {
            Write-Host "All default development services are ready." -ForegroundColor Green
            return
        }

        Start-Sleep -Seconds 3
    }

    Invoke-Compose -Arguments @("ps") -AllowFailure
    throw "Development services did not become ready within $readyTimeoutMinutes minutes (override with DEV_READY_TIMEOUT_MINUTES in .env.docker). Run scripts\dev.cmd logs."
}

function Open-DevelopmentPages {
    $frontendPort = Get-EnvironmentValue -Name "FRONTEND_PORT" -DefaultValue "15173"
    $minioConsolePort = Get-EnvironmentValue -Name "MINIO_CONSOLE_PORT" -DefaultValue "19001"
    if ($Scope -in @("all", "front")) {
        Start-Process "http://localhost:$frontendPort"
    }
    if ($Scope -in @("all", "back")) {
        Start-Process "http://localhost:$minioConsolePort"
    }
}

function Show-ConnectionSummary {
    $frontendPort = Get-EnvironmentValue -Name "FRONTEND_PORT" -DefaultValue "15173"
    $backendPort = Get-EnvironmentValue -Name "BACKEND_PORT" -DefaultValue "18080"
    $backtestPort = Get-EnvironmentValue -Name "BACKTEST_PORT" -DefaultValue "18082"
    $adminMcpPort = Get-EnvironmentValue -Name "ADMIN_MCP_PORT" -DefaultValue "18083"
    $localstackPort = Get-EnvironmentValue -Name "LOCALSTACK_PORT" -DefaultValue "14566"
    $postgresPort = Get-EnvironmentValue -Name "POSTGRES_PORT" -DefaultValue "15432"
    $redisPort = Get-EnvironmentValue -Name "REDIS_PORT" -DefaultValue "16379"
    $minioConsolePort = Get-EnvironmentValue -Name "MINIO_CONSOLE_PORT" -DefaultValue "19001"
    $postgresDatabase = Get-EnvironmentValue -Name "POSTGRES_DB" -DefaultValue "idea2strategy"

    Write-Host ""
    Write-Host "Idea2Strategy local development environment" -ForegroundColor Cyan
    Write-Host "  Selected:      $Scope"
    if ($Scope -in @("all", "front")) {
        Write-Host "  Frontend:      http://localhost:$frontendPort"
    }
    if ($Scope -in @("all", "back")) {
        Write-Host "  MinIO Console: http://localhost:$minioConsolePort"
        Write-Host "  PostgreSQL:    localhost:$postgresPort / $postgresDatabase"
        Write-Host "  Redis:         localhost:$redisPort"
        Write-Host "  LocalStack:    http://localhost:$localstackPort"
    }
    Write-Host "  Local secrets: .env.docker (Git ignored)"
    if ($Scope -in @("all", "back")) {
        if ($includeApps) {
            Write-Host "  Backend API:   http://localhost:$backendPort"
            Write-Host "  Backtest API:  http://localhost:$backtestPort"
            Write-Host "  Admin MCP:     http://localhost:$adminMcpPort"
        }
        else {
            Write-Host "  Service apps:  not started; use -WithBackend to start API and workers"
        }
    }
    Write-Host ""
}

Push-Location $root
try {
    Initialize-EnvironmentFile

    if ($Action -ne "open") {
        Start-DockerEngine
    }

    switch ($Action) {
        "up" {
            Initialize-FlywayBundle
            if ($targetedService) {
                Invoke-Compose -Arguments @("up", "-d", "--build", $Service) | Out-Null
                Invoke-Compose -Arguments @("ps", $Service)
            }
            else {
                Invoke-Compose -Arguments @("up", "-d", "--build") | Out-Null
                Wait-DevelopmentEnvironment
            }
            Show-ConnectionSummary
            if (-not $NoBrowser) {
                Open-DevelopmentPages
            }
        }
        "down" {
            if ($targetedService) {
                Invoke-Compose -Arguments @("stop", $Service) | Out-Null
                Invoke-Compose -Arguments @("rm", "-f", $Service) | Out-Null
            }
            elseif ($Scope -eq "all") {
                Invoke-Compose -Arguments @("down", "--remove-orphans") | Out-Null
            }
            elseif ($Scope -eq "front") {
                Invoke-Compose -Arguments @("stop", "frontend") | Out-Null
                Invoke-Compose -Arguments @("rm", "-f", "frontend") | Out-Null
            }
            else {
                $backServices = @("postgres", "redis", "minio", "minio-init", "localstack")
                if ($includeApps) {
                    $backServices += @(
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
                }
                Invoke-Compose -Arguments (@("stop") + $backServices) | Out-Null
                Invoke-Compose -Arguments (@("rm", "-f") + $backServices) | Out-Null
            }
            Write-Host "Development containers stopped. Volumes were preserved." -ForegroundColor Green
        }
        "restart" {
            Initialize-FlywayBundle
            if ($targetedService) {
                Invoke-Compose -Arguments @("up", "-d", "--build", $Service) | Out-Null
                Invoke-Compose -Arguments @("ps", $Service)
            }
            else {
                Invoke-Compose -Arguments @("up", "-d", "--build") | Out-Null
                Wait-DevelopmentEnvironment
            }
            Show-ConnectionSummary
            if (-not $NoBrowser) {
                Open-DevelopmentPages
            }
        }
        "status" {
            if ($targetedService) {
                Invoke-Compose -Arguments @("ps", $Service)
            }
            else {
                Invoke-Compose -Arguments @("ps")
            }
            Show-ConnectionSummary
        }
        "logs" {
            $logArguments = @("logs", "--follow", "--tail", "200")
            if ($targetedService) { $logArguments += $Service }
            Invoke-Compose -Arguments $logArguments
        }
        "open" {
            Open-DevelopmentPages
        }
        "reset" {
            if ($Scope -ne "all") {
                throw "reset is only supported with -Scope all because it deletes shared development volumes."
            }
            if (-not $Force) {
                throw "reset deletes local PostgreSQL, MinIO, and frontend dependency volumes. Re-run with -Force."
            }
            Invoke-Compose -Arguments @("down", "--volumes", "--remove-orphans") | Out-Null
            Write-Host "Development containers and local data volumes were removed." -ForegroundColor Yellow
        }
    }
}
finally {
    Pop-Location
}
