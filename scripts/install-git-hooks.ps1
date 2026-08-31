[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$hooksDirectory = Join-Path $root '.githooks'
if (-not (Test-Path -LiteralPath $hooksDirectory -PathType Container)) {
    throw "Tracked hooks directory is missing: $hooksDirectory"
}

$current = ''
try { $current = (& git -C $root config --local core.hooksPath) } catch { $current = '' }
if ($null -eq $current) { $current = '' }
$current = "$current".Trim()

if ($current -ne '.githooks') {
    & git -C $root config --local core.hooksPath '.githooks'
    if ($LASTEXITCODE -ne 0) { throw 'Unable to configure core.hooksPath.' }
}

$hooks = @(Get-ChildItem -LiteralPath $hooksDirectory -File | Select-Object -ExpandProperty Name)
([ordered]@{
    hooks_path = '.githooks'
    installed  = $hooks
    status = 'passed'
}) | ConvertTo-Json -Compress
