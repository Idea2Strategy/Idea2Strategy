param(
  [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$resolvedRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw "Harness consistency failed: $Message" }
}

$trackedIndex = @(git -C $resolvedRoot ls-files -- '.harness')
$untracked = @(git -C $resolvedRoot ls-files --others --exclude-standard -- '.harness')
$tracked = @($trackedIndex + $untracked) | Sort-Object -Unique
Assert-True ($LASTEXITCODE -eq 0) 'unable to list tracked harness files'

$required = @(
  '.harness/README.md',
  '.harness/entry.md',
  '.harness/manifest.yaml',
  '.harness/profile.yaml',
  '.harness/sources.yaml',
  '.harness/workspaces.yaml',
  '.harness/commands.yaml',
  '.harness/product-authorities.yaml'
)
foreach ($path in $required) {
  Assert-True ($path -in $tracked) "missing required file $path"
}

$obsoleteWorkState = @($tracked | Where-Object {
  $_ -match '^\.harness/work/(branches|claims|definitions)/'
})
Assert-True ($obsoleteWorkState.Count -eq 0) (
  'executable work state must come from docs/launch-readiness-tasks.json; remove: ' +
  ($obsoleteWorkState -join ', ')
)
foreach ($removedDependencyPath in @('.harness/governance.yaml', '.harness/work/provider.yaml')) {
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $resolvedRoot $removedDependencyPath))) (
    "obsolete coordination file remains: $removedDependencyPath"
  )
}

$workItems = @($tracked | Where-Object { $_ -match '^\.harness/work/items/.+\.yaml$' })
foreach ($path in $workItems) {
  $text = Get-Content -Raw -Encoding utf8 (Join-Path $resolvedRoot $path)
  Assert-True ($text -match '(?m)^status: done\s*$') "$path is not an immutable completion receipt"
}

$entry = Get-Content -Raw -Encoding utf8 (Join-Path $resolvedRoot '.harness/entry.md')
foreach ($canonicalPath in @('docs/launch-readiness-plan.md', 'docs/launch-readiness-tasks.json')) {
  Assert-True ($entry.Contains($canonicalPath)) "entry does not name current work authority $canonicalPath"
}

$commandText = Get-Content -Raw -Encoding utf8 (Join-Path $resolvedRoot '.harness/commands.yaml')
$commandIds = @([regex]::Matches($commandText, '(?m)^\s*- id: (?<id>command\.[a-z0-9-]+)\s*$') |
  ForEach-Object { $_.Groups['id'].Value })
Assert-True ($commandIds.Count -eq (@($commandIds | Sort-Object -Unique)).Count) 'command ids are duplicated'
foreach ($scriptMatch in [regex]::Matches($commandText, 'scripts/[A-Za-z0-9._/-]+')) {
  $scriptPath = $scriptMatch.Value
  Assert-True (Test-Path -LiteralPath (Join-Path $resolvedRoot $scriptPath) -PathType Leaf) (
    "command references missing script $scriptPath"
  )
}

$trackedBytes = 0
foreach ($path in $tracked) {
  if ($path -in $trackedIndex) {
    $blobBytes = git -C $resolvedRoot cat-file -s ":$path"
    Assert-True ($LASTEXITCODE -eq 0) "unable to read indexed harness blob $path"
    $trackedBytes += [long]$blobBytes
  } else {
    $trackedBytes += (Get-Item -LiteralPath (Join-Path $resolvedRoot $path)).Length
  }
}
Assert-True ($trackedBytes -le 20000) "tracked harness is too large ($trackedBytes bytes; limit 20000)"

[pscustomobject]@{
  status = 'passed'
  tracked_files = $tracked.Count
  tracked_bytes = $trackedBytes
  completed_receipts = $workItems.Count
  executable_work_records = 0
  command_ids = $commandIds.Count
} | ConvertTo-Json -Compress
