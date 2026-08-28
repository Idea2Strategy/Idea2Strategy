$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$legacyName = 'stack' + 'cord'

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw "Legacy coordination dependency found: $Message" }
}

$operationalFiles = @('AGENTS.md', 'CLAUDE.md', 'README.md')
$operationalFiles += @(git -C $root ls-files -- '.agents/**' '.claude/**' '.github/**' '.harness/**' 'scripts/**')
$operationalFiles += @(Get-ChildItem -LiteralPath (Join-Path $root 'docs') -File |
  ForEach-Object { "docs/$($_.Name)" })
$operationalFiles += @(git -C $root ls-files -- 'docs/prompts/**')
$operationalFiles = @($operationalFiles | Sort-Object -Unique | Where-Object {
  $_ -ne 'scripts/test-repository-native-harness.ps1' -and
  (Test-Path -LiteralPath (Join-Path $root $_) -PathType Leaf)
})

$references = @()
foreach ($path in $operationalFiles) {
  $content = Get-Content -Raw -Encoding utf8 (Join-Path $root $path)
  if ($content -match "(?i)$legacyName") { $references += $path }
}
Assert-True ($references.Count -eq 0) ('operational references remain in ' + ($references -join ', '))

foreach ($obsoletePath in @(
  '.harness/governance.yaml',
  '.harness/work/provider.yaml',
  'docs/prompts/stackcord-pre-mutation-governance.md'
)) {
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $root $obsoletePath))) "$obsoletePath still exists"
}

Assert-True (Test-Path -LiteralPath (Join-Path $root '.harness/product-authorities.yaml') -PathType Leaf) (
  'repository-local product authority registry is missing'
)

[pscustomobject]@{
  status = 'passed'
  operational_files = $operationalFiles.Count
  legacy_references = 0
} | ConvertTo-Json -Compress
