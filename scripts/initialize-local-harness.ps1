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
logs, operation records, dbdiagram proposals, owner mappings, Jira
transfer records, and remote synchronization state stored here remain local.

Run `scripts/initialize-local-harness.ps1 -Verify` after cloning. Add
`-MigrateLegacy` only when migrating the former root `output/`, `tmp/`, or
`.idea2strategy-local/` directories. Files below `tmp/`, `cache/`, and `logs/`
are disposable and should not be used as completion evidence. Keep durable,
non-secret receipts in `artifacts/` and project metadata in `project/`. Never
store credentials in this tree.
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
purpose: repository-local product-authority reference; an explicit change record or pull-request review is required
'@
  if (Test-Path -LiteralPath $ownerMetadataPath -PathType Leaf) {
    # Migrate any superseded generated default; never overwrite a locally
    # customized owner reference, which omits the generated purpose marker.
    $existing = Get-Content -Raw -Encoding utf8 $ownerMetadataPath
    if ($existing.Contains('purpose: repository-local product-authority reference') -or
        -not $existing.Contains('purpose: non-secret product-authority reference; provider verification is required')) {
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

# 상위 디렉터리의 사본이 이 체크아웃을 가리는지 검사한다. 2026-08-08 에 정확히 이 일이
# 일어났다 — 옛 클론의 스킬·CLAUDE.md 가 정본을 가려 낡은 절차가 실행됐고, 가리는 파일이
# 다른 저장소 소속이라 git pull 로는 고칠 수 없었다. 여기서 던지지는 않는다(샌드박스와
# 별개 클론 배치가 정상인 경우가 있다). 대신 결과를 남기고 화면에 크게 알린다. 에이전트
# 진입점(/start-work, .agents/prompts/start-work.md)은 이 실패를 정지 조건으로 취급한다.
$workspaceIsolation = 'skipped'
try {
  $isolation = Join-Path $PSScriptRoot 'verify-workspace-isolation.ps1'
  if (Test-Path -LiteralPath $isolation -PathType Leaf) {
    & $isolation | Out-Host
    $workspaceIsolation = if ($LASTEXITCODE -eq 0) { 'passed' } else { 'failed' }
  }
} catch {
  $workspaceIsolation = "failed: $($_.Exception.Message)"
}

# 추적되는 git 훅을 이 체크아웃에 붙인다. AGENTS.md 가 모든 작업 전에 이 스크립트를
# 실행하라고 요구하므로, 가드가 설치되는 지점으로 여기가 맞다 — 도구가 섞여 있어
# (Claude·Codex) 편집기 훅에 의존할 수 없고 git 훅은 모두에게 걸린다.
#
# 실제 git 작업 트리에서만 시도하고 절대 던지지 않는다. 이 스크립트는 git 저장소가
# 아닌 임시 샌드박스에서도 실행된다(scripts/test-local-harness.ps1). 훅을 붙이지
# 못하는 것이 로컬 하니스 초기화를 실패시킬 이유는 아니다.
# 확인하는 경로와 설정하는 경로를 같게 둔다. install-git-hooks.ps1 은 자기 스크립트가
# 속한 저장소를 대상으로 하므로, -RepositoryRoot 로 넘어온 샌드박스가 아니라 그 저장소를
# 확인해야 한다. 아니면 샌드박스를 검사하고 실제 저장소를 고치는 일이 된다.
$hooksPath = 'skipped'
try {
  $scriptRepository = Split-Path -Parent $PSScriptRoot
  $insideWorkTree = & git -C $scriptRepository rev-parse --is-inside-work-tree 2>$null
  if ($LASTEXITCODE -eq 0 -and "$insideWorkTree".Trim() -eq 'true') {
    $installer = Join-Path $PSScriptRoot 'install-git-hooks.ps1'
    if (Test-Path -LiteralPath $installer -PathType Leaf) {
      & $installer | Out-Null
      $hooksPath = '.githooks'
    }
  }
} catch {
  $hooksPath = "failed: $($_.Exception.Message)"
}

# Codex 사용자용 /start-work 프롬프트를 사용자 홈에 복사한다. Claude 는 저장소의
# .claude/skills 를 직접 읽지만 Codex 는 $CODEX_HOME/prompts 만 읽으므로 설치가 필요하다.
# Codex 를 안 쓰는 사람에게는 무해하고, 실패해도 하니스 초기화를 막을 이유는 아니다.
$codexPrompts = 'skipped'
try {
  $promptInstaller = Join-Path $PSScriptRoot 'install-codex-prompts.ps1'
  if (Test-Path -LiteralPath $promptInstaller -PathType Leaf) {
    & $promptInstaller | Out-Null
    $codexPrompts = 'installed'
  }
} catch {
  $codexPrompts = "failed: $($_.Exception.Message)"
}

[pscustomobject]@{
  repository = $resolvedRoot
  local_root = '.harness/local'
  migrated_files = $migratedFiles
  verified = [bool]$Verify
  git_hooks = $hooksPath
  codex_prompts = $codexPrompts
  status = 'passed'
} | ConvertTo-Json -Compress
