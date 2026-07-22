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

$nextRaw = & stackcord work next --root $repositoryRoot --json 2>&1
$nextExit = $LASTEXITCODE
$next = $nextRaw | ConvertFrom-Json
$recommendations = @($next.facts | Where-Object code -eq 'work.recommended')

Assert-True ($nextExit -eq 6) 'an empty executable queue reports no dependency-ready work'
Assert-True ($next.status -eq 'unknown') 'an empty executable queue is explicit rather than silently successful'
Assert-True ($recommendations.Count -eq 0) 'completed setup work is never recommended again'

[pscustomobject]@{
  status = 'passed'
  assertions = 12
} | ConvertTo-Json -Compress
