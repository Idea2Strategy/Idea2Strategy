[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('ALPACA_API_KEY', 'ALPACA_API_SECRET')]
    [string]$Name,
    [string]$EnvironmentFile = '.env.docker'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$target = [System.IO.Path]::GetFullPath((Join-Path $root $EnvironmentFile))
if (-not $target.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Environment file must stay inside the repository.'
}
if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
    throw "Local environment file is missing: $target"
}

$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    $fallback = 'C:\Program Files\Git\cmd\git.exe'
    if (Test-Path -LiteralPath $fallback -PathType Leaf) { $git = Get-Item -LiteralPath $fallback }
}
if (-not $git) { throw 'Git executable is unavailable; ignored-file safety cannot be verified.' }
$gitPath = if ($git.PSObject.Properties.Name -contains 'Source') { $git.Source } else { $git.FullName }
$global:LASTEXITCODE = 0
& $gitPath -C $root check-ignore --quiet -- $target
if ($LASTEXITCODE -ne 0) {
    throw 'Refusing to store a credential in a tracked or non-ignored file.'
}

$credential = [Console]::In.ReadToEnd().Trim()
if ([string]::IsNullOrWhiteSpace($credential) -or $credential.Contains("`n") -or $credential.Contains("`r")) {
    throw 'Credential input must be one non-empty line.'
}

$lines = [System.Collections.Generic.List[string]]::new()
$found = $false
foreach ($line in [System.IO.File]::ReadAllLines($target)) {
    if ($line.StartsWith("$Name=", [StringComparison]::Ordinal)) {
        if (-not $found) { $lines.Add("$Name=$credential") }
        $found = $true
    } else {
        $lines.Add($line)
    }
}
if (-not $found) { $lines.Add("$Name=$credential") }

$temporary = "$target.$([guid]::NewGuid().ToString('N')).tmp"
try {
    [System.IO.File]::WriteAllLines($temporary, $lines, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temporary -Destination $target -Force
} finally {
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
}

([ordered]@{ name = $Name; stored = $true; ignored = $true } | ConvertTo-Json -Compress)
