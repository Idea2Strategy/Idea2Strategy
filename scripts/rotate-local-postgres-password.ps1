[CmdletBinding()]
param(
    [switch]$SkipRestart
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$environmentFile = Join-Path $root '.env.docker'
$composeFile = Join-Path $root 'compose.back.yml'
. (Join-Path $PSScriptRoot 'local-development-environment.ps1')

function Read-EnvironmentValue([string]$Name) {
    $line = Get-Content -LiteralPath $environmentFile |
        Where-Object { $_ -match "^$([regex]::Escape($Name))=" } |
        Select-Object -Last 1
    if ($null -eq $line) { throw "$Name is missing from .env.docker" }
    return ($line -split '=', 2)[1]
}

function Set-EnvironmentValue([string]$Name, [string]$Value) {
    $content = Get-Content -LiteralPath $environmentFile -Raw
    $pattern = "(?m)^$([regex]::Escape($Name))=.*$"
    if ($content -notmatch $pattern) { throw "$Name is missing from .env.docker" }
    $updated = [regex]::Replace($content, $pattern, "$Name=$Value", 1)
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($environmentFile, $updated, $encoding)
}

function Set-DatabasePassword([string]$User, [string]$Password) {
    $quotedUser = $User.Replace('"', '""')
    $quotedPassword = $Password.Replace("'", "''")
    "ALTER ROLE `"$quotedUser`" PASSWORD '$quotedPassword';" |
        docker exec -i idea2strategy-postgres sh -lc 'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' |
        Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL rejected the local password rotation.' }
}

function Test-Password([string]$User, [string]$Password) {
    # The official image trusts loopback connections inside its own container.
    # Verify over the compose network instead, which is the same SCRAM path used
    # by every application service and therefore genuinely rejects the old value.
    docker run --rm --network idea2strategy-development -e "PGPASSWORD=$Password" `
        postgres:16-alpine psql -h idea2strategy-postgres -U $User `
        -d (Read-EnvironmentValue 'POSTGRES_DB') `
        -v ON_ERROR_STOP=1 -c 'select 1' *> $null
    return $LASTEXITCODE -eq 0
}

if (-not (Test-Path -LiteralPath $environmentFile -PathType Leaf)) {
    throw '.env.docker does not exist. Run scripts\dev.cmd up first.'
}
$user = Read-EnvironmentValue 'POSTGRES_USER'
if ($user -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') { throw 'POSTGRES_USER is not a safe SQL role name.' }
$oldPassword = Read-EnvironmentValue 'POSTGRES_PASSWORD'
$newPassword = New-LocalDevelopmentSecret
if ($newPassword -eq $oldPassword) { throw 'Generated password unexpectedly matches the current password.' }

Set-DatabasePassword $user $newPassword
try {
    if (Test-Password $user $oldPassword) { throw 'The previous PostgreSQL password still authenticates.' }
    if (-not (Test-Password $user $newPassword)) { throw 'The rotated PostgreSQL password does not authenticate.' }
    Set-EnvironmentValue 'POSTGRES_PASSWORD' $newPassword
} catch {
    Set-DatabasePassword $user $oldPassword
    throw
}

if (-not $SkipRestart) {
    $services = @(
        'postgres', 'backend-api', 'backend-batch', 'backend-worker', 'backtest-api',
        'trading-worker', 'admin-mcp', 'backtest-worker'
    )
    docker compose --profile apps --env-file $environmentFile -f $composeFile `
        up -d --force-recreate @services | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Services could not be recreated with the rotated password.' }
}

Write-Host 'Local PostgreSQL password rotated; the previous password was rejected and the new password was verified.' -ForegroundColor Green
