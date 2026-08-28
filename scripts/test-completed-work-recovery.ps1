$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$completedWorkIDs = @(
  'work.collaboration-policy-bootstrap',
  'work.product-authority-governance',
  'work.clone-readiness'
)

function Assert-True {
  param(
    [bool]$Condition,
    [string]$Message
  )

  if (-not $Condition) {
    throw "Assertion failed: $Message"
  }
}

foreach ($workID in $completedWorkIDs) {
  $itemPath = Join-Path $repositoryRoot ".harness/work/items/$workID.yaml"
  $definitionPath = Join-Path $repositoryRoot ".harness/work/definitions/$workID.yaml"
  Assert-True (Test-Path -LiteralPath $itemPath -PathType Leaf) "$workID has a durable completed item"
  Assert-True (-not (Test-Path -LiteralPath $definitionPath)) "$workID is no longer executable"
  $itemText = Get-Content -Raw -Encoding utf8 $itemPath
  Assert-True $itemText.Contains('status: done') "$workID is recorded as done"
}

$executableRecords = @(
  Get-ChildItem -LiteralPath (Join-Path $repositoryRoot '.harness/work') -Recurse -File |
    Where-Object { $_.FullName -match '[\\/](definitions|claims|branches)[\\/]' }
)
Assert-True ($executableRecords.Count -eq 0) 'completed setup work has no executable definition, claim, or branch record'

$taskLedger = Join-Path $repositoryRoot 'docs/launch-readiness-tasks.json'
$launchStatus = Join-Path $repositoryRoot 'scripts/launch-status.ps1'
Assert-True (Test-Path -LiteralPath $taskLedger -PathType Leaf) 'the current task ledger exists'
Assert-True ((Get-Content -Raw -Encoding utf8 $launchStatus).Contains('launch-readiness-tasks.json')) 'launch-status reads the current task ledger'

[pscustomobject]@{
  status = 'passed'
  assertions = 12
} | ConvertTo-Json -Compress
