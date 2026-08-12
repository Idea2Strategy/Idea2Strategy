param(
  [switch]$BootstrapReview,
  [switch]$AuthorizedPolicyChange
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$policyRelative = 'docs/collaboration-policy.md'
$policyPath = Join-Path $root $policyRelative
$authorityRelative = 'docs/product-authorities.yaml'
$authorityPath = Join-Path $root $authorityRelative
$localRoot = Join-Path $root '.harness/local/project'
$integrityPath = Join-Path $localRoot 'policy/integrity.json'
$ownerPath = Join-Path $localRoot 'policy/owner.yaml'

foreach ($requiredFile in @($policyPath, $authorityPath)) {
  if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
    throw "Missing collaboration source: $requiredFile"
  }
}

git -C $root check-ignore -q -- '.harness/local/project/policy/integrity.json'
if ($LASTEXITCODE -ne 0) {
  throw 'Operational content under .harness/local/ is not ignored by Git.'
}

$allowedLocalFiles = @('.harness/local/README.md')
$allowedLocalFiles += Get-ChildItem -LiteralPath (Join-Path $root '.harness/local') -Recurse -Force -File |
  Where-Object Name -eq '.gitkeep' |
  ForEach-Object { $_.FullName.Substring($root.Length + 1).Replace('\', '/') }
foreach ($trackedPath in @(git -C $root ls-files -- '.harness/local')) {
  if ($trackedPath -notin $allowedLocalFiles) {
    throw "Unexpected tracked local workspace content: $trackedPath"
  }
}

$requiredLinks = @(
  @{ Path = 'AGENTS.md'; Pattern = 'docs/collaboration-policy.md' },
  @{ Path = 'AGENTS.md'; Pattern = 'docs/product-authorities.yaml' },
  @{ Path = '.agents/skills/use-project-harness/SKILL.md'; Pattern = 'docs/collaboration-policy.md' },
  @{ Path = '.agents/skills/use-project-harness/SKILL.md'; Pattern = 'docs/product-authorities.yaml' }
)
foreach ($link in $requiredLinks) {
  $content = Get-Content -Raw -Encoding utf8 (Join-Path $root $link.Path)
  if (-not $content.Contains($link.Pattern)) {
    throw "Missing policy recovery link in $($link.Path): $($link.Pattern)"
  }
}

$authorityText = Get-Content -Raw -Encoding utf8 $authorityPath
foreach ($required in @(
  'provider: github',
  'repository: Idea2Strategy/Idea2Strategy',
  'product_authorities: [user:kcrmin, user:pjy008008, user:Juwon-Na, user:hjcud]',
  'protected_kinds: [product, policy, business, contract]',
  'minimum: 1',
  'authority_self_approval: true'
)) {
  if (-not $authorityText.Contains($required)) {
    throw "Product-authority requirement is missing: $required"
  }
}

foreach ($relative in @('docs/collaboration-policy.md')) {
  $content = Get-Content -Raw -Encoding utf8 (Join-Path $root $relative)
  foreach ($required in @('user:kcrmin', 'user:pjy008008', 'user:Juwon-Na', 'user:hjcud', 'Git user.name and user.email')) {
    if (-not $content.Contains($required)) {
      throw "Missing product-authority rule '$required' in $relative"
    }
  }
}

if (-not (Test-Path -LiteralPath $ownerPath -PathType Leaf)) {
  throw 'Ignored local product-owner metadata is missing.'
}
$owner = Get-Content -Raw -Encoding utf8 $ownerPath
foreach ($required in @('product_authorities: [user:kcrmin, user:pjy008008, user:Juwon-Na, user:hjcud]', 'contact_email_is_authority: false')) {
  if (-not $owner.Contains($required)) {
    throw "Local product-owner metadata requirement is missing: $required"
  }
}

$emailPattern = '(?i)[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}'
$credentialPatterns = @('ghp_[A-Za-z0-9]+', 'github_pat_[A-Za-z0-9_]+', 'glpat-[A-Za-z0-9_-]+', '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----')
foreach ($relative in @($policyRelative, $authorityRelative, 'AGENTS.md', 'README.md')) {
  $content = Get-Content -Raw -Encoding utf8 (Join-Path $root $relative)
  if ($content -match $emailPattern) { throw "Account email detected in shared file: $relative" }
  foreach ($pattern in $credentialPatterns) {
    if ($content -match $pattern) { throw "Credential-like value detected in shared file: $relative" }
  }
}

$actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $policyPath).Hash.ToLowerInvariant()
if (-not (Test-Path -LiteralPath $integrityPath -PathType Leaf)) {
  if (-not $AuthorizedPolicyChange) { throw 'Local policy integrity metadata is missing.' }
} else {
  $integrity = Get-Content -Raw -Encoding utf8 $integrityPath | ConvertFrom-Json
  if ($integrity.sha256 -ne $actualHash -and -not $AuthorizedPolicyChange) {
    throw 'Official collaboration policy differs from the local integrity baseline.'
  }
}

$headPolicyPath = git -C $root ls-tree --name-only HEAD -- $policyRelative
$trackedInHead = $LASTEXITCODE -eq 0 -and $headPolicyPath -eq $policyRelative
if ($trackedInHead) {
  git -C $root diff --quiet HEAD -- $policyRelative
  if ($LASTEXITCODE -ne 0 -and -not $AuthorizedPolicyChange) {
    throw 'Official collaboration policy has an unapproved working-tree change.'
  }
} elseif (-not $BootstrapReview) {
  throw 'The policy is not tracked yet; use -BootstrapReview for owner review.'
}

[pscustomobject]@{
  policy = $policyRelative
  authority = $authorityRelative
  sha256 = $actualHash
  product_authorities = @('user:kcrmin', 'user:pjy008008', 'user:Juwon-Na', 'user:hjcud')
  tracked_in_head = $trackedInHead
  authorized_policy_change = [bool]$AuthorizedPolicyChange
  status = 'passed'
} | ConvertTo-Json -Compress
