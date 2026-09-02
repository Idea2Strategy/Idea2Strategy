[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'local-development-environment.ps1')

$names = @(
    'BACKTEST_RESULT_INGEST_TOKEN',
    'OPERATOR_AUTH_TOTP_KEY',
    'OPERATOR_AUTH_SESSION_HMAC_KEY',
    'OPERATOR_AUTH_CSRF_HMAC_KEY',
    'OPERATOR_AUTH_SOURCE_HMAC_KEY',
    'OPERATOR_AUTH_LOGIN_HMAC_KEY'
)
$template = ($names | ForEach-Object { "$_=__GENERATE_$($_)__" }) -join "`n"
$expanded = Expand-LocalDevelopmentSecretPlaceholders -Content $template -Names $names

foreach ($name in $names) {
    $line = @($expanded -split "`r?`n" | Where-Object { $_ -like "$name=*" })
    if ($line.Count -ne 1) {
        throw "Generated local environment must contain exactly one value for $name."
    }
    $value = $line[0].Substring($line[0].IndexOf('=') + 1)
    try {
        $decoded = [Convert]::FromBase64String($value)
    }
    catch {
        throw "Generated local environment value for $name must be padded base64."
    }
    if ($decoded.Length -ne 32) {
        throw "Generated local environment value for $name must decode to exactly 32 bytes."
    }
}

if ($expanded.Contains('__GENERATE_')) {
    throw 'Generated local environment must not retain secret placeholders.'
}

Write-Output 'local-development-environment: PASS'
