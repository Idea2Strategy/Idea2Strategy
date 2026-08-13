$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ("i2s-env-test-{0}" -f [guid]::NewGuid().ToString('N'))
$testRoot = Join-Path $sandbox 'repository'
$testScripts = Join-Path $testRoot 'scripts'
$backup = Join-Path $testRoot '.local-data/baseline-2026-08-13'
$shared = Join-Path $sandbox 'local-development.env'
$names = @(
    'POSTGRES_PASSWORD', 'APP_POSTGRES_PASSWORD', 'MINIO_ROOT_PASSWORD', 'APP_S3_SECRET_KEY',
    'IDENTITY_CRYPTO_EMAIL_ENCRYPTION_KEY', 'IDENTITY_CRYPTO_LOOKUP_HMAC_KEY',
    'IDENTITY_CRYPTO_VERIFICATION_HMAC_KEY', 'IDENTITY_CRYPTO_REFRESH_TOKEN_HMAC_KEY',
    'IDENTITY_CRYPTO_CUSTOMER_JWT_SIGNING_KEY', 'BACKTEST_RESULT_INGEST_TOKEN'
)
try {
    New-Item -ItemType Directory -Force $testScripts, $backup | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'init-local-env.ps1') -Destination $testScripts
    Copy-Item -LiteralPath (Join-Path $root '.env.example') -Destination $testRoot
    '{}' | Set-Content -LiteralPath (Join-Path $backup 'backup-manifest.json') -Encoding utf8
    $generated = [guid]::NewGuid().ToString('N')
    @('DBDIAGRAM_TOKEN=', 'BACKUP_PATH=must-be-replaced') + @($names | ForEach-Object { "$_=$generated" }) |
        Set-Content -LiteralPath $shared -Encoding utf8

    & (Join-Path $testScripts 'init-local-env.ps1') -BackupPath './.local-data/baseline-2026-08-13' -SharedEnvPath $shared
    & (Join-Path $testScripts 'init-local-env.ps1') -BackupPath './.local-data/baseline-2026-08-13' -SharedEnvPath $shared -Force

    $installed = Get-Content -LiteralPath (Join-Path $testRoot '.env') -Raw
    if ($installed -notmatch '(?m)^BACKUP_PATH=\./\.local-data/baseline-2026-08-13$') {
        throw 'Installed shared .env did not use the project-local backup path.'
    }
    foreach ($name in $names) {
        if ($installed -notmatch "(?m)^$name=$generated\r?$") { throw "Shared .env lost $name." }
    }
    $acl = Get-Acl -LiteralPath (Join-Path $testRoot '.env')
    if (-not $acl.AreAccessRulesProtected) { throw 'Installed .env still inherits filesystem permissions.' }
}
finally {
    Remove-Item -LiteralPath $sandbox -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host 'Shared local .env installation test passed.'
