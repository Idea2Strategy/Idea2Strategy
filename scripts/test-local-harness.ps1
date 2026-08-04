$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$scriptUnderTest = Join-Path $PSScriptRoot 'initialize-local-harness.ps1'
if (-not (Test-Path -LiteralPath $scriptUnderTest -PathType Leaf)) {
  throw 'Missing scripts/initialize-local-harness.ps1'
}

function Assert-True {
  param(
    [bool]$Condition,
    [string]$Message
  )

  if (-not $Condition) {
    throw "Assertion failed: $Message"
  }
}

$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("idea2strategy-harness-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $sandbox | Out-Null

try {
  git -C $sandbox init --quiet
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to initialize the test Git repository.'
  }

  New-Item -ItemType Directory -Path (Join-Path $sandbox '.harness') | Out-Null
  Set-Content -LiteralPath (Join-Path $sandbox '.harness/manifest.yaml') -Encoding utf8 -Value "schema_version: 1`nid: test.project`n"
  Set-Content -LiteralPath (Join-Path $sandbox '.gitignore') -Encoding utf8 -Value @'
.harness/local/**
!.harness/local/README.md
!.harness/local/**/
!.harness/local/**/.gitkeep
'@

  $fixtures = @{
    'output/report.txt' = 'artifact-data'
    'tmp/checkpoint.yaml' = 'checkpoint-data'
    '.idea2strategy-local/policy/integrity.json' = '{"sha256":"test"}'
    '.idea2strategy-local/jira/project-log.yaml' = 'records: []'
    '.idea2strategy-local/remotes/sync-state.yaml' = 'gitlab: planned'
    '.idea2strategy-local/harness/project-record.yaml' = 'project: test'
  }
  foreach ($entry in $fixtures.GetEnumerator()) {
    $path = Join-Path $sandbox $entry.Key
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
    Set-Content -LiteralPath $path -Encoding utf8 -Value $entry.Value
  }

  & $scriptUnderTest -RepositoryRoot $sandbox -MigrateLegacy -Verify
  Assert-True ($LASTEXITCODE -eq 0) 'first bootstrap run exits successfully'

  $ownerPath = Join-Path $sandbox '.harness/local/project/policy/owner.yaml'
  Assert-True (Test-Path -LiteralPath $ownerPath -PathType Leaf) 'first bootstrap creates local authority reference'
  $ownerText = Get-Content -Raw -Encoding utf8 $ownerPath
  Assert-True $ownerText.Contains('product_authorities: [user:kcrmin, user:pjy008008, user:Juwon-Na, user:hjcud]') 'authority reference names provider identities'
  Assert-True $ownerText.Contains('contact_email_is_authority: false') 'authority reference rejects email authentication'
  Assert-True (-not $ownerText.Contains('@')) 'generated authority reference contains no email address'

  $expectedFiles = @{
    '.harness/local/artifacts/report.txt' = 'artifact-data'
    '.harness/local/tmp/checkpoint.yaml' = 'checkpoint-data'
    '.harness/local/project/policy/integrity.json' = '{"sha256":"test"}'
    '.harness/local/project/jira/project-log.yaml' = 'records: []'
    '.harness/local/project/remotes/sync-state.yaml' = 'gitlab: planned'
    '.harness/local/project/work/project-record.yaml' = 'project: test'
  }
  foreach ($entry in $expectedFiles.GetEnumerator()) {
    $path = Join-Path $sandbox $entry.Key
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "$($entry.Key) exists after migration"
    Assert-True ((Get-Content -Raw -Encoding utf8 $path).Trim() -eq $entry.Value) "$($entry.Key) content is preserved"
  }

  foreach ($legacyRoot in @('output', 'tmp', '.idea2strategy-local')) {
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $sandbox $legacyRoot))) "$legacyRoot is removed after lossless migration"
  }

  foreach ($required in @(
    '.harness/local/README.md',
    '.harness/local/artifacts/.gitkeep',
    '.harness/local/tmp/.gitkeep',
    '.harness/local/cache/.gitkeep',
    '.harness/local/logs/.gitkeep',
    '.harness/local/project/policy/.gitkeep',
    '.harness/local/project/jira/.gitkeep',
    '.harness/local/project/remotes/.gitkeep',
    '.harness/local/project/work/.gitkeep',
    '.harness/local/dbdiagram/.gitkeep',
    '.harness/local/operations/.gitkeep'
  )) {
    Assert-True (Test-Path -LiteralPath (Join-Path $sandbox $required) -PathType Leaf) "$required is created"
  }

  git -C $sandbox check-ignore --quiet -- '.harness/local/tmp/checkpoint.yaml'
  Assert-True ($LASTEXITCODE -eq 0) 'operational content is ignored'
  git -C $sandbox check-ignore --quiet -- '.harness/local/tmp/.gitkeep'
  Assert-True ($LASTEXITCODE -ne 0) '.gitkeep is eligible for tracking'

  $preservedOwner = @'
schema_version: 1
provider_authority: user:existing-local-owner
contact_email_is_authority: false
'@
  Set-Content -LiteralPath $ownerPath -Encoding utf8 -Value $preservedOwner
  $ownerHashBeforeSecondRun = (Get-FileHash -Algorithm SHA256 -LiteralPath $ownerPath).Hash

  & $scriptUnderTest -RepositoryRoot $sandbox -MigrateLegacy -Verify
  Assert-True ($LASTEXITCODE -eq 0) 'second bootstrap run is idempotent'
  $ownerHashAfterSecondRun = (Get-FileHash -Algorithm SHA256 -LiteralPath $ownerPath).Hash
  Assert-True ($ownerHashAfterSecondRun -eq $ownerHashBeforeSecondRun) 'second bootstrap preserves existing local owner metadata'

  [pscustomobject]@{
    status = 'passed'
    assertions = 31
  } | ConvertTo-Json -Compress
} finally {
  $resolvedTemp = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
  $resolvedSandbox = [System.IO.Path]::GetFullPath($sandbox)
  if ($resolvedSandbox.StartsWith($resolvedTemp, [System.StringComparison]::OrdinalIgnoreCase) -and
      (Split-Path -Leaf $resolvedSandbox).StartsWith('idea2strategy-harness-test-')) {
    Remove-Item -LiteralPath $resolvedSandbox -Recurse -Force
  }
}
