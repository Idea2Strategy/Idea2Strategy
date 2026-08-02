param(
  [switch]$BootstrapReview,
  [switch]$AuthorizedPolicyChange
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$policyRelativePath = 'docs/collaboration-policy.md'
$policyPath = Join-Path $repositoryRoot $policyRelativePath
$localRoot = Join-Path $repositoryRoot '.harness/local/project'
$integrityPath = Join-Path $localRoot 'policy/integrity.json'
$governanceRelativePath = '.harness/governance.yaml'
$governancePath = Join-Path $repositoryRoot $governanceRelativePath
$ownerMetadataPath = Join-Path $localRoot 'policy/owner.yaml'

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

if (-not (Test-Path -LiteralPath $governancePath -PathType Leaf)) {
  throw "Missing Stackcord governance policy: $governanceRelativePath"
}
$governanceText = Get-Content -Raw -Encoding utf8 $governancePath
$requiredGovernanceValues = @(
  'enabled: true',
  'provider: github',
  'repository: Idea2Strategy/Idea2Strategy',
  'product_authorities: [user:kcrmin, user:pjy008008, user:Juwon-Na, user:Pearone99]',
  'protected_kinds: [product, policy, business, contract]',
  'minimum: 1',
  'authority_self_approval: true'
)
foreach ($required in $requiredGovernanceValues) {
  if (-not $governanceText.Contains($required)) {
    throw "Governance requirement is missing: $required"
  }
}

$authorityRuleFiles = @(
  'AGENTS.md',
  '.agents/skills/use-project-harness/SKILL.md',
  '.agents/skills/use-project-harness/references/fallback.md',
  'docs/collaboration-policy.md'
)
$requiredAuthorityRules = @(
  'stackcord governance check --json',
  'user:kcrmin',
  'user:pjy008008',
  'user:Juwon-Na',
  'user:Pearone99',
  'fresh provider',
  'must not edit',
  'Git user.name and user.email never prove authority'
)
foreach ($relativePath in $authorityRuleFiles) {
  $content = Get-Content -Raw -Encoding utf8 (Join-Path $repositoryRoot $relativePath)
  foreach ($required in $requiredAuthorityRules) {
    if (-not $content.Contains($required)) {
      throw "Missing product-authority rule '$required' in $relativePath."
    }
  }
}

if (-not (Test-Path -LiteralPath $ownerMetadataPath -PathType Leaf)) {
  throw 'Ignored local product-owner metadata is missing.'
}
$ownerMetadata = Get-Content -Raw -Encoding utf8 $ownerMetadataPath
foreach ($required in @('product_authorities: [user:kcrmin, user:pjy008008, user:Juwon-Na, user:Pearone99]', 'contact_email_is_authority: false')) {
  if (-not $ownerMetadata.Contains($required)) {
    throw "Local product-owner metadata requirement is missing: $required"
  }
}

$sharedFiles = @(
  $policyPath,
  (Join-Path $repositoryRoot 'AGENTS.md'),
  (Join-Path $repositoryRoot 'README.md'),
  (Join-Path $repositoryRoot '.agents/skills/use-project-harness/SKILL.md'),
  (Join-Path $repositoryRoot '.agents/skills/use-project-harness/references/fallback.md'),
  $governancePath,
  (Join-Path $repositoryRoot '.harness/work/items/work.collaboration-policy-bootstrap.yaml')
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
  if ($LASTEXITCODE -ne 0 -and -not $AuthorizedPolicyChange) {
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
  authorized_policy_change = [bool]$AuthorizedPolicyChange
  governance_enabled = $true
  product_authorities = @('user:kcrmin', 'user:pjy008008', 'user:Juwon-Na', 'user:Pearone99')
  status = 'passed'
} | ConvertTo-Json -Compress
