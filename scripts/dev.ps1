[CmdletBinding()]
param(
    [ValidateSet("up", "down", "restart", "status", "logs", "open", "reset")]
    [string]$Action = "up",

    [ValidateSet("all", "front", "back")]
    [string]$Scope = "all",

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

function Initialize-EnvironmentFile {
    if (Test-Path -LiteralPath $environmentFile) {
        return
    }

    if (-not (Test-Path -LiteralPath $environmentTemplate -PathType Leaf)) {
        throw "Environment template is missing: $environmentTemplate"
    }

    $content = Get-Content -LiteralPath $environmentTemplate -Raw
    $content = $content.Replace("__GENERATE_POSTGRES_PASSWORD__", (New-RandomSecret))
    $content = $content.Replace("__GENERATE_MINIO_PASSWORD__", (New-RandomSecret))
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($environmentFile, $content, $encoding)
    Write-Host "Created local-only environment file: .env.docker" -ForegroundColor Green
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

    if ($WithBackend) {
        if ($Scope -eq "front") {
            throw "-WithBackend cannot be used with -Scope front."
        }
        $gradleWrapper = Join-Path $root "backend\gradlew"
        $migrationDirectory = Join-Path $root "backend\db-migration\src\main\resources\db\migration"
        if (-not (Test-Path -LiteralPath $gradleWrapper -PathType Leaf)) {
            throw "Backend source is not ready. Missing: backend/gradlew"
        }
        if (-not (Test-Path -LiteralPath $migrationDirectory -PathType Container)) {
            throw "Backend Flyway migrations are not ready. Missing: backend/db-migration/src/main/resources/db/migration"
        }
        $arguments += @("--profile", "backend-apps")
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
    $deadline = (Get-Date).AddMinutes(4)

    Write-Host "Waiting for local services..." -ForegroundColor Yellow
    while ((Get-Date) -lt $deadline) {
        $postgresReady = $true
        $redisReady = $true
        $minioReady = $true
        $frontendReady = $true

        if ($Scope -in @("all", "back")) {
            $postgresReady = Test-ContainerCommand -Arguments @(
                "postgres", "pg_isready", "-U", $postgresUser, "-d", $postgresDatabase
            )
            $redisReady = Test-ContainerCommand -Arguments @("redis", "redis-cli", "ping")
            $minioReady = Test-HttpEndpoint -Uri $minioHealthUrl
        }

        if ($Scope -in @("all", "front")) {
            $frontendReady = Test-HttpEndpoint -Uri $frontendUrl
        }

        if ($postgresReady -and $redisReady -and $minioReady -and $frontendReady) {
            Write-Host "All default development services are ready." -ForegroundColor Green
            return
        }

        Start-Sleep -Seconds 3
    }

    Invoke-Compose -Arguments @("ps") -AllowFailure
    throw "Development services did not become ready within 4 minutes. Run scripts\dev.cmd logs."
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
    $batchPort = Get-EnvironmentValue -Name "BATCH_PORT" -DefaultValue "18081"
    $backtestPort = Get-EnvironmentValue -Name "BACKTEST_PORT" -DefaultValue "18082"
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
    }
    Write-Host "  Local secrets: .env.docker (Git ignored)"
    if ($Scope -in @("all", "back")) {
        if ($WithBackend) {
            Write-Host "  Backend:       http://localhost:$backendPort"
            Write-Host "  Batch:         http://localhost:$batchPort"
            Write-Host "  Backtest:      http://localhost:$backtestPort"
        }
        else {
            Write-Host "  Spring apps:   not started; use -WithBackend after backend sources are added"
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
            Invoke-Compose -Arguments @("up", "-d", "--build") | Out-Null
            Wait-DevelopmentEnvironment
            Show-ConnectionSummary
            if (-not $NoBrowser) {
                Open-DevelopmentPages
            }
        }
        "down" {
            if ($Scope -eq "all") {
                Invoke-Compose -Arguments @("down", "--remove-orphans") | Out-Null
            }
            elseif ($Scope -eq "front") {
                Invoke-Compose -Arguments @("stop", "frontend") | Out-Null
                Invoke-Compose -Arguments @("rm", "-f", "frontend") | Out-Null
            }
            else {
                $backServices = @("postgres", "redis", "minio", "minio-init")
                if ($WithBackend) {
                    $backServices += @("flyway", "backend", "batch", "backtest")
                }
                Invoke-Compose -Arguments (@("stop") + $backServices) | Out-Null
                Invoke-Compose -Arguments (@("rm", "-f") + $backServices) | Out-Null
            }
            Write-Host "Development containers stopped. Volumes were preserved." -ForegroundColor Green
        }
        "restart" {
            Invoke-Compose -Arguments @("up", "-d", "--build") | Out-Null
            Wait-DevelopmentEnvironment
            Show-ConnectionSummary
            if (-not $NoBrowser) {
                Open-DevelopmentPages
            }
        }
        "status" {
            Invoke-Compose -Arguments @("ps")
            Show-ConnectionSummary
        }
        "logs" {
            Invoke-Compose -Arguments @("logs", "--follow", "--tail", "200")
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
