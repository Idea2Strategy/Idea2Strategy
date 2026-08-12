[CmdletBinding()]
param(
    [string[]]$ChangedPath = @(),
    [string]$BaseSha = "",
    [string]$HeadSha = "HEAD",
    [ValidateSet("pull_request", "push", "schedule", "workflow_dispatch")][string]$EventName = "pull_request",
    [string]$Ref = "",
    [string]$GithubOutput = "",
    [switch]$PassThru
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$paths = @($ChangedPath | ForEach-Object {
    $normalisedPath = ([string]$_).Replace('\', '/')
    if ($normalisedPath.StartsWith('./', [System.StringComparison]::Ordinal)) {
        $normalisedPath = $normalisedPath.Substring(2)
    }
    $normalisedPath
} | Where-Object { $_ })
if ($paths.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($BaseSha)) {
    $paths = @(& git diff --name-only --no-renames $BaseSha $HeadSha)
    if ($LASTEXITCODE -ne 0) { throw "Unable to resolve changed paths from $BaseSha to $HeadSha." }
    $paths = @($paths | ForEach-Object { ([string]$_).Replace('\', '/') })
}

function Test-AnyPath {
    param([Parameter(Mandatory = $true)][string[]]$Pattern)
    foreach ($path in $paths) {
        foreach ($candidate in $Pattern) {
            if ($path -like $candidate) { return $true }
        }
    }
    return $false
}

$isMain = $Ref -ceq "refs/heads/main"
$isManual = $EventName -ceq "workflow_dispatch"
$isNightly = $EventName -ceq "schedule"
$full = $isMain -or $isManual -or $isNightly

$scope = [ordered]@{
    backend = Test-AnyPath @("backend", "backend/*")
    trading = Test-AnyPath @("trading-engine", "trading-engine/*")
    backtest = Test-AnyPath @("backtest-engine", "backtest-engine/*")
    data_pipeline = Test-AnyPath @("data-pipeline", "data-pipeline/*")
    ui = Test-AnyPath @("ui", "ui/*")
    root = Test-AnyPath @("db/*", "contracts/*", "specs/*", "package.json", "pnpm-lock.yaml", ".harness/*")
    docker = Test-AnyPath @("compose.*.yml", "infra/docker/*", "scripts/dev.ps1", "scripts/dev-menu.ps1", "scripts/test-docker-development.ps1")
    integration = Test-AnyPath @(
        "backend", "backtest-engine", "data-pipeline", "trading-engine", "ui",
        "db/*", "contracts/*", "compose.*.yml", "infra/docker/*", "db/flyway-ci-bundle/*",
        "scripts/prepare-flyway-bundle.ps1", "scripts/test-flyway-*.ps1", "scripts/integration/*"
    )
    terraform = $full -or (Test-AnyPath @("infra/*", "scripts/aws/*", "scripts/*terraform*.ps1", "scripts/*development*.ps1", "scripts/*deployment*.ps1", ".github/workflows/*"))
    full_e2e = $full
    security = $full
}
$scope["any_service"] = $scope.backend -or $scope.trading -or $scope.backtest -or $scope.data_pipeline -or $scope.ui
$scope["any_changed"] = $paths.Count -gt 0

$result = [pscustomobject]$scope
if (-not [string]::IsNullOrWhiteSpace($GithubOutput)) {
    foreach ($entry in $scope.GetEnumerator()) {
        $line = "$($entry.Key)=$([bool]$entry.Value).ToString().ToLowerInvariant()"
        Add-Content -LiteralPath $GithubOutput -Value $line -Encoding utf8
    }
}
if ($PassThru) { return $result }
$result | ConvertTo-Json -Compress
