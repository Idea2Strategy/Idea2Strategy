[CmdletBinding()]
param(
    [string]$BackupPath = './.local-data/baseline-2026-08-13',
    [string]$SharedEnvPath,
    [switch]$Force
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$target = Join-Path $root '.env'
$template = Join-Path $root '.env.example'
$resolvedBackup = if ([IO.Path]::IsPathRooted($BackupPath)) { $BackupPath } else { Join-Path $root $BackupPath }
if (-not (Test-Path -LiteralPath (Join-Path $resolvedBackup 'backup-manifest.json') -PathType Leaf)) {
    throw "Backup path has no backup-manifest.json: $resolvedBackup"
}
if ((Test-Path -LiteralPath $target) -and -not $Force) {
    throw '.env already exists. Use -Force only when intentionally rotating all local credentials.'
}

function New-LocalSecret {
    $bytes = New-Object byte[] 32
    $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $generator.GetBytes($bytes)
    }
    finally {
        $generator.Dispose()
    }
    return [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', 'A').Replace('/', 'B')
}

$names = @(
    'POSTGRES_PASSWORD', 'APP_POSTGRES_PASSWORD', 'MINIO_ROOT_PASSWORD', 'APP_S3_SECRET_KEY',
    'IDENTITY_CRYPTO_EMAIL_ENCRYPTION_KEY', 'IDENTITY_CRYPTO_LOOKUP_HMAC_KEY',
    'IDENTITY_CRYPTO_VERIFICATION_HMAC_KEY', 'IDENTITY_CRYPTO_REFRESH_TOKEN_HMAC_KEY',
    'IDENTITY_CRYPTO_CUSTOMER_JWT_SIGNING_KEY', 'BACKTEST_RESULT_INGEST_TOKEN'
)

if ($SharedEnvPath) {
    $shared = if ([IO.Path]::IsPathRooted($SharedEnvPath)) { $SharedEnvPath } else { Join-Path (Get-Location) $SharedEnvPath }
    if (-not (Test-Path -LiteralPath $shared -PathType Leaf)) { throw "Shared .env file not found: $shared" }
    $content = Get-Content -LiteralPath $shared -Raw
    if ($content.Contains('__GENERATE_')) { throw 'Shared .env still contains generation placeholders.' }
    foreach ($name in $names) {
        if ($content -notmatch "(?m)^$name=[^\r\n]+\r?$") { throw "Shared .env is missing a value for $name." }
    }
}
else {
    $content = Get-Content -LiteralPath $template -Raw
    foreach ($name in $names) {
        $content = [regex]::Replace($content, "(?m)^$name=__GENERATE_[A-Z0-9_]+__$", "$name=$(New-LocalSecret)")
    }
    if ($content.Contains('__GENERATE_')) { throw 'Not every local secret placeholder was replaced.' }
}
$content = [regex]::Replace($content, '(?m)^BACKUP_PATH=.*$', "BACKUP_PATH=$BackupPath")
[IO.File]::WriteAllText($target, $content, [Text.UTF8Encoding]::new($false))

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$currentAcl = Get-Acl -LiteralPath $target
$currentRules = @($currentAcl.Access)
$alreadyRestricted = $currentAcl.AreAccessRulesProtected -and $currentRules.Count -eq 1 -and
    $currentRules[0].IdentityReference.Translate([Security.Principal.SecurityIdentifier]) -eq $identity.User -and
    $currentRules[0].AccessControlType -eq [Security.AccessControl.AccessControlType]::Allow -and
    (($currentRules[0].FileSystemRights -band [Security.AccessControl.FileSystemRights]::FullControl) -eq
        [Security.AccessControl.FileSystemRights]::FullControl)
if (-not $alreadyRestricted) {
    $acl = [Security.AccessControl.FileSecurity]::new()
    $acl.SetAccessRuleProtection($true, $false)
    $rule = [Security.AccessControl.FileSystemAccessRule]::new(
        $identity.User, [Security.AccessControl.FileSystemRights]::FullControl,
        [Security.AccessControl.AccessControlType]::Allow
    )
    $acl.AddAccessRule($rule)
    Set-Acl -LiteralPath $target -AclObject $acl
}
$message = if ($SharedEnvPath) { 'Installed shared ignored .env and restricted its ACL.' } else { 'Created ignored .env with new local-only credentials.' }
Write-Host $message -ForegroundColor Green
