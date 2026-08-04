param(
  [string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
  [switch]$MigrateLegacy,
  [switch]$Verify
)

$ErrorActionPreference = 'Stop'
$resolvedRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$harnessManifest = Join-Path $resolvedRoot '.harness/manifest.yaml'
if (-not (Test-Path -LiteralPath (Join-Path $resolvedRoot '.git')) -or
    -not (Test-Path -LiteralPath $harnessManifest -PathType Leaf)) {
  throw "RepositoryRoot must contain .git and .harness/manifest.yaml: $resolvedRoot"
}

$localRoot = Join-Path $resolvedRoot '.harness/local'
$localDirectories = @(
  'artifacts',
  'tmp',
  'cache',
  'logs',
  'project/policy',
  'project/jira',
  'project/remotes',
  'project/work',
  'dbdiagram',
  'operations'
)

$readme = @'
# Local harness workspace

This directory exists in every clone, but Git tracks only this README and the
approved `.gitkeep` markers. All generated artifacts, temporary data, caches,
logs, Stackcord operation records, dbdiagram proposals, owner mappings, Jira
transfer records, and remote synchronization state stored here remain local.

Run `scripts/initialize-local-harness.ps1 -Verify` after cloning. Add
`-MigrateLegacy` only when migrating the former root `output/`, `tmp/`, or
`.idea2strategy-local/` directories. Never store credentials in this tree.
'@

function Initialize-Layout {
  New-Item -ItemType Directory -Force -Path $localRoot | Out-Null
  $readmePath = Join-Path $localRoot 'README.md'
  if (-not (Test-Path -LiteralPath $readmePath -PathType Leaf)) {
    Set-Content -LiteralPath $readmePath -Encoding utf8 -Value $readme
  }

  foreach ($relativeDirectory in $localDirectories) {
    $directory = Join-Path $localRoot $relativeDirectory
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $marker = Join-Path $directory '.gitkeep'
    if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) {
      New-Item -ItemType File -Path $marker | Out-Null
    }
  }
}

function Initialize-TrackedPolicyIntegrity {
  $policyRelativePath = 'docs/collaboration-policy.md'
  $policyPath = Join-Path $resolvedRoot $policyRelativePath
  $integrityPath = Join-Path $localRoot 'project/policy/integrity.json'
  if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf) -or
      (Test-Path -LiteralPath $integrityPath -PathType Leaf)) {
    return
  }

  $headPolicyPath = git -C $resolvedRoot ls-tree --name-only HEAD -- $policyRelativePath
  if ($LASTEXITCODE -ne 0 -or $headPolicyPath -ne $policyRelativePath) {
    return
  }
  git -C $resolvedRoot diff --quiet HEAD -- $policyRelativePath
  if ($LASTEXITCODE -ne 0) {
    return
  }

  [pscustomobject]@{
    policy = $policyRelativePath
    sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $policyPath).Hash.ToLowerInvariant()
    baseline = 'tracked-head'
  } | ConvertTo-Json | Set-Content -LiteralPath $integrityPath -Encoding utf8
}

function Initialize-ProductAuthorityReference {
  $ownerMetadataPath = Join-Path $localRoot 'project/policy/owner.yaml'
  $ownerMetadata = @'
schema_version: 1
provider: github
repository: Idea2Strategy/Idea2Strategy
product_authorities: [user:kcrmin, user:pjy008008, user:Juwon-Na, user:hjcud]
contact_email_is_authority: false
purpose: non-secret product-authority reference; provider verification is required
'@
  if (Test-Path -LiteralPath $ownerMetadataPath -PathType Leaf) {
    # Migrate any superseded generated default; never overwrite a locally
    # customized owner reference, which omits the generated purpose marker.
    $existing = Get-Content -Raw -Encoding utf8 $ownerMetadataPath
    if ($existing.Contains('product_authorities: [user:kcrmin, user:pjy008008, user:Juwon-Na, user:hjcud]') -or
        -not $existing.Contains('purpose: non-secret product-authority reference')) {
      return
    }
  }

  Set-Content -LiteralPath $ownerMetadataPath -Encoding utf8 -Value $ownerMetadata
}

function Remove-EmptyDirectoryTree {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    return
  }

  Get-ChildItem -LiteralPath $Path -Recurse -Force -Directory |
    Sort-Object { $_.FullName.Length } -Descending |
    ForEach-Object {
      if (@(Get-ChildItem -LiteralPath $_.FullName -Force).Count -eq 0) {
        Remove-Item -LiteralPath $_.FullName -Force
      }
    }

  if (@(Get-ChildItem -LiteralPath $Path -Force).Count -eq 0) {
    Remove-Item -LiteralPath $Path -Force
  }
}

function Move-LegacyTree {
  param(
    [string]$SourceRelative,
    [string]$DestinationRelative
  )

  $source = Join-Path $resolvedRoot $SourceRelative
  if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    return 0
  }

  $destination = Join-Path $resolvedRoot $DestinationRelative
  New-Item -ItemType Directory -Force -Path $destination | Out-Null
  $moved = 0

  foreach ($file in @(Get-ChildItem -LiteralPath $source -Recurse -Force -File)) {
    $relative = $file.FullName.Substring($source.Length).TrimStart([char[]]@('\', '/'))
    $target = Join-Path $destination $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null

    if (Test-Path -LiteralPath $target -PathType Leaf) {
      $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash
      $targetHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash
      if ($sourceHash -ne $targetHash) {
        throw "Migration collision with different content: $SourceRelative/$relative"
      }
      Remove-Item -LiteralPath $file.FullName -Force
    } else {
      Move-Item -LiteralPath $file.FullName -Destination $target
    }
    $moved++
  }

  Remove-EmptyDirectoryTree -Path $source
  return $moved
}

function Test-Layout {
  $requiredFiles = @('.harness/local/README.md')
  $requiredFiles += $localDirectories | ForEach-Object { ".harness/local/$_/.gitkeep" }
  foreach ($relativePath in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $resolvedRoot $relativePath) -PathType Leaf)) {
      throw "Missing local harness skeleton file: $relativePath"
    }
  }

  $probe = '.harness/local/tmp/__idea2strategy_ignore_probe__.tmp'
  git -C $resolvedRoot check-ignore --quiet -- $probe
  if ($LASTEXITCODE -ne 0) {
    throw "Operational local-harness content is not ignored: $probe"
  }

  foreach ($marker in @('.harness/local/README.md', '.harness/local/tmp/.gitkeep')) {
    git -C $resolvedRoot check-ignore --quiet -- $marker
    if ($LASTEXITCODE -eq 0) {
      throw "Shared local-harness skeleton file is unexpectedly ignored: $marker"
    }
  }

  $trackedLocalFiles = @(git -C $resolvedRoot ls-files -- '.harness/local')
  foreach ($trackedPath in $trackedLocalFiles) {
    if ($trackedPath -ne '.harness/local/README.md' -and $trackedPath -notmatch '/\.gitkeep$') {
      throw "Unexpected tracked local-harness content: $trackedPath"
    }
  }

  foreach ($legacyRoot in @('output', 'tmp', '.idea2strategy-local')) {
    $legacyPath = Join-Path $resolvedRoot $legacyRoot
    if (Test-Path -LiteralPath $legacyPath -PathType Container) {
      $legacyFiles = @(Get-ChildItem -LiteralPath $legacyPath -Recurse -Force -File)
      if ($legacyFiles.Count -gt 0) {
        throw "Legacy local directory still contains files: $legacyRoot"
      }
    }
  }
}

Initialize-Layout
Initialize-TrackedPolicyIntegrity
Initialize-ProductAuthorityReference
$migratedFiles = 0
if ($MigrateLegacy) {
  $migrations = @(
    @{ Source = 'output'; Destination = '.harness/local/artifacts' },
    @{ Source = 'tmp'; Destination = '.harness/local/tmp' },
    @{ Source = '.idea2strategy-local/policy'; Destination = '.harness/local/project/policy' },
    @{ Source = '.idea2strategy-local/jira'; Destination = '.harness/local/project/jira' },
    @{ Source = '.idea2strategy-local/remotes'; Destination = '.harness/local/project/remotes' },
    @{ Source = '.idea2strategy-local/harness'; Destination = '.harness/local/project/work' }
  )
  foreach ($migration in $migrations) {
    $migratedFiles += Move-LegacyTree -SourceRelative $migration.Source -DestinationRelative $migration.Destination
  }
  Remove-EmptyDirectoryTree -Path (Join-Path $resolvedRoot '.idea2strategy-local')
}

if ($Verify) {
  Test-Layout
}

[pscustomobject]@{
  repository = $resolvedRoot
  local_root = '.harness/local'
  migrated_files = $migratedFiles
  verified = [bool]$Verify
  status = 'passed'
} | ConvertTo-Json -Compress
