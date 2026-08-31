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
    $indexEntry = (& git -C $Root ls-files --stage -- $SubmodulePath) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $indexEntry -notmatch '^160000\s+([0-9a-f]{40})\s+0\s+') {
        throw "Unable to read the staged gitlink for $SubmodulePath from the root index."
    }
    $pinnedRevision = $Matches[1]
    $checkedOutRevision = (& git -C $Repository rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $checkedOutRevision -cne $pinnedRevision) {
        throw "$SubmodulePath must be checked out at the exact staged gitlink revision ($pinnedRevision); found $checkedOutRevision."
    }
}

function Quote-ApplicationArgument([string]$Value) {
    if ($Value.Contains('"')) {
        throw "Flyway bundle paths must not contain double quote characters: $Value"
    }
    return '"' + $Value + '"'
}

function Convert-CrlfToLf([byte[]]$Bytes) {
    $normalized = New-Object System.IO.MemoryStream
    try {
        for ($index = 0; $index -lt $Bytes.Length; $index++) {
            if ($Bytes[$index] -eq 13 -and $index + 1 -lt $Bytes.Length -and $Bytes[$index + 1] -eq 10) {
                $normalized.WriteByte(10)
                $index++
            } else {
                $normalized.WriteByte($Bytes[$index])
            }
        }
        return $normalized.ToArray()
    } finally {
        $normalized.Dispose()
    }
}

function Normalize-BundleForCrossPlatformUse([string]$BundlePath) {
    $manifestPath = Join-Path $BundlePath 'migration-bundle.manifest'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw 'Generated Flyway manifest is missing before normalization.'
    }
    $manifestLines = @(Get-Content -LiteralPath $manifestPath)
    if ($manifestLines.Count -lt 2 -or $manifestLines[0] -cne 'idea2strategy-flyway-bundle-v1') {
        throw 'Generated Flyway manifest has an unsupported format.'
    }

    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $normalizedManifest = New-Object System.Text.StringBuilder
    [void]$normalizedManifest.Append("idea2strategy-flyway-bundle-v1`n")
    foreach ($line in $manifestLines[1..($manifestLines.Count - 1)]) {
        if ($line -notmatch '^([^\t]+[.]sql)\t[0-9a-f]{64}$') {
            throw "Generated Flyway manifest entry is invalid: $line"
        }
        $fileName = $Matches[1]
        $migrationPath = Join-Path $BundlePath $fileName
        if (-not (Test-Path -LiteralPath $migrationPath -PathType Leaf)) {
            throw "Generated Flyway migration is missing: $fileName"
        }
        $normalizedBytes = Convert-CrlfToLf ([System.IO.File]::ReadAllBytes($migrationPath))
        [System.IO.File]::WriteAllBytes($migrationPath, $normalizedBytes)
        $migrationHash = (Get-FileHash -LiteralPath $migrationPath -Algorithm SHA256).Hash.ToLowerInvariant()
        [void]$normalizedManifest.Append("$fileName`t$migrationHash`n")
    }

    [System.IO.File]::WriteAllBytes($manifestPath, $utf8.GetBytes($normalizedManifest.ToString()))
    $bundleHash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    [System.IO.File]::WriteAllBytes(
        (Join-Path $BundlePath 'migration-bundle.sha256'),
        $utf8.GetBytes($bundleHash)
    )
}

$root = Get-FullPath (Split-Path -Parent $PSScriptRoot)
$backendRoot = Join-Path $root 'backend'
$backtestRoot = Join-Path $root 'backtest-engine'
$tradingRoot = Join-Path $root 'trading-engine'
$dataPipelineRoot = Join-Path $root 'data-pipeline'
$centralMigration = Join-Path $backendRoot 'db-migration/src/main/resources/db/migration'
$backtestContribution = Join-Path $backtestRoot 'db/migration-contributions'
$tradingContribution = Join-Path $tradingRoot 'db/migration-contributions'
$dataPipelineContribution = Join-Path $dataPipelineRoot 'db/migration-contributions'
$localRoot = Join-Path $root '.local'
$temporaryRoot = Join-Path $localRoot 'tmp'
$bundle = Join-Path $temporaryRoot 'flyway-bundle'
$expectedBundle = Get-FullPath (Join-Path $root '.local/tmp/flyway-bundle')

if ((Get-FullPath $bundle) -cne $expectedBundle) {
    throw 'Refusing to prepare a Flyway bundle outside the exact local bundle path.'
}

Assert-RegularDirectory $backendRoot 'Backend submodule'
Assert-RegularDirectory $backtestRoot 'Backtest submodule'
Assert-RegularDirectory $tradingRoot 'Trading submodule'
Assert-RegularDirectory $dataPipelineRoot 'Data Pipeline submodule'
Assert-RegularDirectory $centralMigration 'Central migration'
Assert-RegularDirectory $backtestContribution 'Backtest migration contribution'
Assert-RegularDirectory $tradingContribution 'Trading migration contribution'
Assert-RegularDirectory $dataPipelineContribution 'Data Pipeline migration contribution'
Assert-PinnedSubmodule $root 'backend' $backendRoot
Assert-PinnedSubmodule $root 'backtest-engine' $backtestRoot
Assert-PinnedSubmodule $root 'trading-engine' $tradingRoot
Assert-PinnedSubmodule $root 'data-pipeline' $dataPipelineRoot
Assert-CleanContribution $tradingRoot 'db/migration-contributions'
Assert-CleanContribution $backtestRoot 'db/migration-contributions'
Assert-CleanContribution $dataPipelineRoot 'db/migration-contributions'

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
    $applicationArgs = @($centralMigration, $bundle, $backtestContribution, $tradingContribution, $dataPipelineContribution) |
        ForEach-Object { Quote-ApplicationArgument $_ }
    Push-Location $backendRoot
    try {
        & $gradleWrapper --no-daemon :db-migration:run "--args=$($applicationArgs -join ' ')"
        if ($LASTEXITCODE -ne 0) {
            throw 'The backend migration bundle assembler failed.'
        }
    } finally {
        Pop-Location
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
        '--args=/workspace/backend/db-migration/src/main/resources/db/migration /workspace/.local/tmp/flyway-bundle /workspace/backtest-engine/db/migration-contributions /workspace/trading-engine/db/migration-contributions /workspace/data-pipeline/db/migration-contributions'
    )
    & docker @dockerArguments
    if ($LASTEXITCODE -ne 0) {
        throw 'The containerized backend migration bundle assembler failed.'
    }
}

Normalize-BundleForCrossPlatformUse $bundle

foreach ($required in @('V1__initial_schema.sql', 'migration-bundle.manifest', 'migration-bundle.sha256')) {
    if (-not (Test-Path -LiteralPath (Join-Path $bundle $required) -PathType Leaf)) {
        throw "Generated Flyway bundle is missing: $required"
    }
}

$backendRevision = (& git -C $backendRoot rev-parse HEAD).Trim()
$backtestRevision = (& git -C $backtestRoot rev-parse HEAD).Trim()
$tradingRevision = (& git -C $tradingRoot rev-parse HEAD).Trim()
$dataPipelineRevision = (& git -C $dataPipelineRoot rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $backendRevision -notmatch '^[0-9a-f]{40}$' -or $backtestRevision -notmatch '^[0-9a-f]{40}$' -or
    $tradingRevision -notmatch '^[0-9a-f]{40}$' -or $dataPipelineRevision -notmatch '^[0-9a-f]{40}$') {
    throw 'Unable to identify exact backend, trading, and data pipeline submodule revisions.'
}

[pscustomobject]@{
    status = 'passed'
    bundle = $bundle
    sha256 = (Get-Content -LiteralPath (Join-Path $bundle 'migration-bundle.sha256') -Raw).Trim()
    backend_revision = $backendRevision
    backtest_revision = $backtestRevision
    trading_revision = $tradingRevision
    data_pipeline_revision = $dataPipelineRevision
} | ConvertTo-Json -Compress
