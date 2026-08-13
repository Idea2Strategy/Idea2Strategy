[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$compose = Get-Content -LiteralPath (Join-Path $root 'compose.back.yml') -Raw
$policyPath = Join-Path $root 'infra/docker/minio/market-baseline-readonly.json'
$policy = Get-Content -LiteralPath $policyPath -Raw
$template = Get-Content -LiteralPath (Join-Path $root '.env.docker.example') -Raw
$localTemplate = Get-Content -LiteralPath (Join-Path $root '.env.example') -Raw
$dev = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'dev.ps1') -Raw
$windowsInit = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'init-local-env.ps1') -Raw
$macInit = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'init-local-env.sh') -Raw
foreach ($required in @(
    'APP_POSTGRES_USER', 'APP_POSTGRES_PASSWORD', 'APP_S3_ACCESS_KEY', 'APP_S3_SECRET_KEY',
    'market-baseline-readonly',
    'S3_RESULTS_BUCKET', 'MINIO_ROOT_USER'
)) {
    if (-not $compose.Contains($required)) { throw "Compose fixed-data isolation omits: $required" }
}
foreach ($required in @('s3:GetObjectVersion', 's3:ListBucketVersions', 'idea2strategy-local-results')) {
    if (-not $policy.Contains($required)) { throw "MinIO fixed-data policy omits: $required" }
}
foreach ($required in @('APP_POSTGRES_USER=', 'APP_POSTGRES_PASSWORD=', 'APP_S3_ACCESS_KEY=', 'APP_S3_SECRET_KEY=')) {
    if (-not $template.Contains($required)) { throw "Environment template omits: $required" }
}
foreach ($required in @('APP_POSTGRES_PASSWORD', 'APP_S3_SECRET_KEY', 'Add-MissingFixedDataSecrets')) {
    if (-not $dev.Contains($required)) { throw "dev.ps1 omits fixed-data secret generation: $required" }
}
$sensitiveVariables = @(
    'POSTGRES_PASSWORD', 'APP_POSTGRES_PASSWORD', 'MINIO_ROOT_PASSWORD', 'APP_S3_SECRET_KEY',
    'IDENTITY_CRYPTO_EMAIL_ENCRYPTION_KEY', 'IDENTITY_CRYPTO_LOOKUP_HMAC_KEY',
    'IDENTITY_CRYPTO_VERIFICATION_HMAC_KEY', 'IDENTITY_CRYPTO_REFRESH_TOKEN_HMAC_KEY',
    'IDENTITY_CRYPTO_CUSTOMER_JWT_SIGNING_KEY', 'BACKTEST_RESULT_INGEST_TOKEN'
)
foreach ($name in $sensitiveVariables) {
    if ($compose -match [regex]::Escape("`${${name}:-")) { throw "Compose exposes a tracked default for $name." }
    if ($compose -notmatch [regex]::Escape("`${${name}:?")) { throw "Compose must require $name from ignored .env." }
    if ($localTemplate -notmatch "(?m)^$name=__GENERATE_[A-Z0-9_]+__$") {
        throw ".env.example must contain only a generation placeholder for $name."
    }
}
if ($windowsInit -notmatch 'RandomNumberGenerator' -or $windowsInit -notmatch 'SetAccessRuleProtection') {
    throw 'Windows local env initialization must use OS CSPRNG and restrict the .env ACL.'
}
if ($macInit -notmatch 'umask 077' -or $macInit -notmatch 'openssl rand') {
    throw 'macOS local env initialization must use OS CSPRNG and mode 0600.'
}

$composeTestEnv = Join-Path ([IO.Path]::GetTempPath()) ("i2s-compose-{0}.env" -f [guid]::NewGuid().ToString('N'))
try {
    $generated = [guid]::NewGuid().ToString('N')
    @($sensitiveVariables | ForEach-Object { "$_=$generated" }) + 'BACKUP_PATH=./.local-data/baseline-2026-08-13' |
        Set-Content -LiteralPath $composeTestEnv -Encoding utf8
    $resolvedCompose = docker compose --env-file $composeTestEnv -f (Join-Path $root 'compose.yml') config --format json |
        ConvertFrom-Json
    if (($resolvedCompose.services.flyway.command -join ' ') -match '(?i)password') {
        throw 'Flyway must not receive its password through process arguments.'
    }
    if (-not $resolvedCompose.services.flyway.environment.FLYWAY_PASSWORD) {
        throw 'Flyway must receive its password through its environment.'
    }
}
finally {
    Remove-Item -LiteralPath $composeTestEnv -Force -ErrorAction SilentlyContinue
}
Write-Host 'Fixed-data isolation contract tests passed.'
