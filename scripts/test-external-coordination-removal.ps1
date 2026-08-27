$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$removedToolName = ('stack' + 'cord')
$activeFiles = @(
  'AGENTS.md',
  'CLAUDE.md',
  'README.md',
  '.agents/skills/use-project-harness/SKILL.md',
  '.agents/skills/use-project-harness/references/fallback.md',
  '.claude/skills/start-work/SKILL.md',
  '.github/workflows/ci.yml',
  'docs/backend-implementation-master-checklist.md',
  'docs/backtest-production-readiness.md',
  'docs/collaboration-policy.md',
  'docs/development-start-guide.md',
  'docs/launch-readiness-plan.md',
  'scripts/initialize-local-harness.ps1',
  'scripts/test-local-harness.ps1',
  'scripts/validate-proposal-boundary.mjs',
  'scripts/verify-collaboration-policy.ps1',
  'scripts/verify-foundation-evidence.mjs'
)

foreach ($relative in $activeFiles) {
  $path = Join-Path $root $relative
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Missing active project file: $relative"
  }
  if ((Get-Content -Raw -Encoding utf8 $path) -match [regex]::Escape($removedToolName)) {
    throw "Active project file still references removed coordination tooling: $relative"
  }
}

$removedState = @(
  '.harness/commands.yaml', '.harness/entry.md', '.harness/governance.yaml',
  '.harness/manifest.yaml', '.harness/profile.yaml', '.harness/sources.yaml',
  '.harness/workspaces.yaml', '.harness/work'
)
foreach ($relative in $removedState) {
  $candidate = Join-Path $root $relative
  $remains = if (Test-Path -LiteralPath $candidate -PathType Container) {
    @(Get-ChildItem -LiteralPath $candidate -Recurse -Force -File).Count -gt 0
  } else {
    Test-Path -LiteralPath $candidate
  }
  if ($remains) {
    throw "Removed coordination state remains: $relative"
  }
}

foreach ($required in @(
  'docs/product-authorities.yaml', '.harness/local/README.md',
  '.harness/ui/baselines/ui.baseline.signal-studio.yaml'
)) {
  if (-not (Test-Path -LiteralPath (Join-Path $root $required))) {
    throw "Required project-owned replacement is missing: $required"
  }
}

[pscustomobject]@{ status = 'passed'; active_files = $activeFiles.Count } |
  ConvertTo-Json -Compress
