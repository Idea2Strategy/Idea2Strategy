[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

$ghCommand = Get-Command gh -ErrorAction SilentlyContinue
if ($null -ne $ghCommand) {
    $gh = $ghCommand.Source
} else {
    $fallback = 'C:\Program Files\GitHub CLI\gh.exe'
    if (-not (Test-Path -LiteralPath $fallback -PathType Leaf)) {
        throw 'GitHub CLI is required to verify exact develop CI results.'
    }
    $gh = $fallback
}

& $gh auth status *> $null
if ($LASTEXITCODE -ne 0) {
    throw 'GitHub CLI is not authenticated.'
}

$targets = @(
    @{ Repository = 'Idea2Strategy/Idea2Strategy'; Path = $root },
    @{ Repository = 'Idea2Strategy/Idea2Strategy-backend'; Path = (Join-Path $root 'backend') },
    @{ Repository = 'Idea2Strategy/Idea2Strategy-trading-engine'; Path = (Join-Path $root 'trading-engine') },
    @{ Repository = 'Idea2Strategy/Idea2Strategy-backtest-engine'; Path = (Join-Path $root 'backtest-engine') },
    @{ Repository = 'Idea2Strategy/Idea2Strategy-data-pipeline'; Path = (Join-Path $root 'data-pipeline') },
    @{ Repository = 'Idea2Strategy/Idea2Strategy-ui'; Path = (Join-Path $root 'ui') }
)

$verified = @()
foreach ($target in $targets) {
    $sha = (git -C $target.Path rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $sha -notmatch '^[0-9a-f]{40}$') {
        throw "Cannot resolve the Git commit for $($target.Repository)."
    }

    $raw = & $gh run list `
        --repo $target.Repository `
        --commit $sha `
        --workflow CI `
        --limit 10 `
        --json status,conclusion,event,headSha,url
    if ($LASTEXITCODE -ne 0) {
        throw "Cannot read GitHub Actions for $($target.Repository)."
    }

    $runs = @($raw | ConvertFrom-Json)
    $success = $runs | Where-Object {
        $_.headSha -eq $sha -and
        $_.event -eq 'push' -and
        $_.status -eq 'completed' -and
        $_.conclusion -eq 'success'
    } | Select-Object -First 1

    if ($null -eq $success) {
        throw "No successful develop push CI run matches $($target.Repository)@$sha."
    }

    $verified += [pscustomobject]@{
        repository = $target.Repository
        commit = $sha
        run = $success.url
    }
}

[pscustomobject]@{
    status = 'passed'
    verified = $verified
} | ConvertTo-Json -Depth 4 -Compress
