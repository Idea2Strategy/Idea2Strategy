[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Get-FullPath([string]$Path) {
    return [System.IO.Path]::GetFullPath($Path)
}

function Assert-RegularDirectory([string]$Path, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "$Label directory is missing: $Path"
    }
    $item = Get-Item -LiteralPath $Path -Force
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "$Label directory must not be a symlink or reparse point: $Path"
    }
}

function Assert-CleanContribution([string]$Repository, [string]$RelativePath) {
    $status = & git -C $Repository status --porcelain=v1 -- $RelativePath
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect the contribution in $Repository."
    }
    if (-not [string]::IsNullOrWhiteSpace(($status -join "`n"))) {
        throw "The contribution must come from an exact committed submodule revision: $RelativePath"
    }
}

function Assert-PinnedSubmodule([string]$Root, [string]$SubmodulePath, [string]$Repository) {
    $treeEntry = (& git -C $Root ls-tree HEAD -- $SubmodulePath) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $treeEntry -notmatch '^160000\s+commit\s+([0-9a-f]{40})\s+') {
        throw "Unable to read the pinned gitlink for $SubmodulePath from the root HEAD."
    }
    $pinnedRevision = $Matches[1]
    $checkedOutRevision = (& git -C $Repository rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $checkedOutRevision -cne $pinnedRevision) {
        throw "$SubmodulePath must be checked out at the exact root gitlink revision ($pinnedRevision); found $checkedOutRevision."
    }
}

function Quote-ApplicationArgument([string]$Value) {
    if ($Value.Contains('"')) {
        throw "Flyway bundle paths must not contain double quote characters: $Value"
    }
    return '"' + $Value + '"'
}

$root = Get-FullPath (Split-Path -Parent $PSScriptRoot)
$backendRoot = Join-Path $root 'backend'
$tradingRoot = Join-Path $root 'trading-engine'
$centralMigration = Join-Path $backendRoot 'db-migration/src/main/resources/db/migration'
$tradingContribution = Join-Path $tradingRoot 'db/migration-contributions'
$localRoot = Join-Path $root '.harness/local'
$temporaryRoot = Join-Path $localRoot 'tmp'
$bundle = Join-Path $temporaryRoot 'flyway-bundle'
$expectedBundle = Get-FullPath (Join-Path $root '.harness/local/tmp/flyway-bundle')

if ((Get-FullPath $bundle) -cne $expectedBundle) {
    throw 'Refusing to prepare a Flyway bundle outside the exact local bundle path.'
}

Assert-RegularDirectory $backendRoot 'Backend submodule'
Assert-RegularDirectory $tradingRoot 'Trading submodule'
Assert-RegularDirectory $centralMigration 'Central migration'
Assert-RegularDirectory $tradingContribution 'Trading migration contribution'
Assert-PinnedSubmodule $root 'backend' $backendRoot
Assert-PinnedSubmodule $root 'trading-engine' $tradingRoot
Assert-CleanContribution $tradingRoot 'db/migration-contributions'

foreach ($directory in @($localRoot, $temporaryRoot)) {
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory | Out-Null
    }
    Assert-RegularDirectory $directory 'Local Flyway parent'
}

if (Test-Path -LiteralPath $bundle) {
    Assert-RegularDirectory $bundle 'Flyway bundle output'
    if ((Get-FullPath (Get-Item -LiteralPath $bundle -Force).FullName) -cne $expectedBundle) {
        throw 'Refusing to remove a Flyway bundle whose resolved path is not the exact local bundle path.'
    }
    Remove-Item -LiteralPath $bundle -Recurse -Force
}
New-Item -ItemType Directory -Path $bundle | Out-Null

$java = Get-Command java -ErrorAction SilentlyContinue
if ($null -ne $java) {
    $gradleWrapper = if ($env:OS -eq 'Windows_NT') {
        Join-Path $backendRoot 'gradlew.bat'
    } else {
        Join-Path $backendRoot 'gradlew'
    }
    if (-not (Test-Path -LiteralPath $gradleWrapper -PathType Leaf)) {
        throw "Backend Gradle wrapper is missing: $gradleWrapper"
    }
    $applicationArgs = @($centralMigration, $bundle, $tradingContribution) |
        ForEach-Object { Quote-ApplicationArgument $_ }
    & $gradleWrapper --no-daemon :db-migration:run "--args=$($applicationArgs -join ' ')"
    if ($LASTEXITCODE -ne 0) {
        throw 'The backend migration bundle assembler failed.'
    }
} else {
    $docker = Get-Command docker -ErrorAction SilentlyContinue
    if ($null -eq $docker) {
        throw 'Java 21 or Docker is required to run the backend migration bundle assembler.'
    }
    $dockerArguments = @(
        'run', '--rm',
        '--mount', "type=bind,source=$root,target=/workspace",
        '--mount', 'type=volume,source=idea2strategy-gradle,target=/root/.gradle',
        '-w', '/workspace/backend',
        'eclipse-temurin:21-jdk',
        'java', '-classpath', 'gradle/wrapper/gradle-wrapper.jar',
        'org.gradle.wrapper.GradleWrapperMain', '--no-daemon', ':db-migration:run',
        '--args=/workspace/backend/db-migration/src/main/resources/db/migration /workspace/.harness/local/tmp/flyway-bundle /workspace/trading-engine/db/migration-contributions'
    )
    & docker @dockerArguments
    if ($LASTEXITCODE -ne 0) {
        throw 'The containerized backend migration bundle assembler failed.'
    }
}

foreach ($required in @('V1__initial_schema.sql', 'migration-bundle.manifest', 'migration-bundle.sha256')) {
    if (-not (Test-Path -LiteralPath (Join-Path $bundle $required) -PathType Leaf)) {
        throw "Generated Flyway bundle is missing: $required"
    }
}

$backendRevision = (& git -C $backendRoot rev-parse HEAD).Trim()
$tradingRevision = (& git -C $tradingRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $backendRevision -notmatch '^[0-9a-f]{40}$' -or $tradingRevision -notmatch '^[0-9a-f]{40}$') {
    throw 'Unable to identify exact backend and trading submodule revisions.'
}

[pscustomobject]@{
    status = 'passed'
    bundle = $bundle
    sha256 = (Get-Content -LiteralPath (Join-Path $bundle 'migration-bundle.sha256') -Raw).Trim()
    backend_revision = $backendRevision
    trading_revision = $tradingRevision
} | ConvertTo-Json -Compress
