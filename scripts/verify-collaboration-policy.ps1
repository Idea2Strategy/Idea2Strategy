param(
  [switch]$BootstrapReview
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$policyRelativePath = 'docs/collaboration-policy.md'
$policyPath = Join-Path $repositoryRoot $policyRelativePath
$localRoot = Join-Path $repositoryRoot '.harness/local/project'
$integrityPath = Join-Path $localRoot 'policy/integrity.json'

if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) {
  throw "Missing official collaboration policy: $policyRelativePath"
}

git -C $repositoryRoot check-ignore -q -- '.harness/local/project/policy/integrity.json'
if ($LASTEXITCODE -ne 0) {
  throw 'Operational content under .harness/local/ is not ignored by Git.'
}

$allowedLocalFiles = @('.harness/local/README.md')
$allowedLocalFiles += Get-ChildItem -LiteralPath (Join-Path $repositoryRoot '.harness/local') -Recurse -Force -File |
  Where-Object { $_.Name -eq '.gitkeep' } |
  ForEach-Object { $_.FullName.Substring($repositoryRoot.Length + 1).Replace('\', '/') }
$trackedLocalFiles = @(git -C $repositoryRoot ls-files -- '.harness/local')
foreach ($trackedPath in $trackedLocalFiles) {
  if ($trackedPath -notin $allowedLocalFiles) {
    throw "Unexpected tracked local-harness content: $trackedPath"
  }
}

foreach ($legacyRoot in @('output', 'tmp', '.idea2strategy-local')) {
  $legacyPath = Join-Path $repositoryRoot $legacyRoot
  if (Test-Path -LiteralPath $legacyPath -PathType Container) {
    if (@(Get-ChildItem -LiteralPath $legacyPath -Recurse -Force -File).Count -gt 0) {
      throw "Legacy local directory contains active files: $legacyRoot"
    }
  }
}

$requiredLinks = @(
  @{ Path = 'AGENTS.md'; Pattern = 'docs/collaboration-policy.md' },
  @{ Path = 'AGENTS.md'; Pattern = 'scripts/initialize-local-harness.ps1 -Verify' },
  @{ Path = '.agents/skills/use-project-harness/SKILL.md'; Pattern = 'docs/collaboration-policy.md' },
  @{ Path = '.agents/skills/use-project-harness/SKILL.md'; Pattern = 'scripts/initialize-local-harness.ps1 -Verify' },
  @{ Path = '.agents/skills/use-project-harness/references/fallback.md'; Pattern = 'docs/collaboration-policy.md' },
  @{ Path = '.agents/skills/use-project-harness/references/fallback.md'; Pattern = 'scripts/initialize-local-harness.ps1 -Verify' }
)
foreach ($link in $requiredLinks) {
  $content = Get-Content -Raw -Encoding utf8 (Join-Path $repositoryRoot $link.Path)
  if (-not $content.Contains($link.Pattern)) {
    throw "Missing policy recovery link in $($link.Path)."
  }
}

$sharedFiles = @(
  $policyPath,
  (Join-Path $repositoryRoot 'AGENTS.md'),
  (Join-Path $repositoryRoot 'README.md'),
  (Join-Path $repositoryRoot '.agents/skills/use-project-harness/SKILL.md'),
  (Join-Path $repositoryRoot '.agents/skills/use-project-harness/references/fallback.md'),
  (Join-Path $repositoryRoot '.harness/work/definitions/work.collaboration-policy-bootstrap.yaml')
)
$emailPattern = '(?i)[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}'
$credentialPatterns = @('ghp_[A-Za-z0-9]+', 'github_pat_[A-Za-z0-9_]+', 'glpat-[A-Za-z0-9_-]+', '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----')
foreach ($file in $sharedFiles) {
  $content = Get-Content -Raw -Encoding utf8 $file
  if ($content -match $emailPattern) {
    throw "Account email detected in shared file: $file"
  }
  foreach ($pattern in $credentialPatterns) {
    if ($content -match $pattern) {
      throw "Credential-like value detected in shared file: $file"
    }
  }
}

$actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $policyPath).Hash.ToLowerInvariant()
if (-not (Test-Path -LiteralPath $integrityPath -PathType Leaf)) {
  throw 'Local policy integrity metadata is missing.'
}
$integrity = Get-Content -Raw -Encoding utf8 $integrityPath | ConvertFrom-Json
if ($integrity.sha256 -ne $actualHash) {
  throw 'Official collaboration policy differs from the authorized local integrity baseline.'
}

$headPolicyPath = git -C $repositoryRoot ls-tree --name-only HEAD -- $policyRelativePath
$trackedInHead = $LASTEXITCODE -eq 0 -and $headPolicyPath -eq $policyRelativePath
if ($trackedInHead) {
  git -C $repositoryRoot diff --quiet HEAD -- $policyRelativePath
  if ($LASTEXITCODE -ne 0) {
    throw 'Official collaboration policy has an unapproved working-tree change.'
  }
} elseif (-not $BootstrapReview) {
  throw 'The initial policy is not distributed yet; use -BootstrapReview only for the owner review before the first policy commit.'
}

[pscustomobject]@{
  policy = $policyRelativePath
  sha256 = $actualHash
  ignored_local_root = $true
  tracked_local_allowlist = $allowedLocalFiles.Count
  recovery_links = $requiredLinks.Count
  tracked_in_head = $trackedInHead
  bootstrap_review = [bool]$BootstrapReview
  status = 'passed'
} | ConvertTo-Json -Compress
