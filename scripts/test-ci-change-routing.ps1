$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$resolver = Join-Path $PSScriptRoot "resolve-ci-change-scope.ps1"
if (-not (Test-Path -LiteralPath $resolver -PathType Leaf)) {
    throw "CI change-scope resolver is missing."
}

function Assert-Scope {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string[]]$Paths = @(),
        [Parameter(Mandatory = $true)][hashtable]$Expected,
        [ValidateSet("pull_request", "push", "schedule", "workflow_dispatch")][string]$Event = "pull_request",
        [string]$Ref = "refs/pull/1/merge"
    )

    $scope = & $resolver -ChangedPath $Paths -EventName $Event -Ref $Ref -PassThru
    foreach ($entry in $Expected.GetEnumerator()) {
        $actual = $scope.PSObject.Properties[$entry.Key].Value
        if ([bool]$actual -ne [bool]$entry.Value) {
            throw "$Name expected $($entry.Key)=$($entry.Value), found $actual."
        }
    }
}

Assert-Scope -Name "docs only" -Paths @("docs/notes.md") -Expected @{ terraform = $false; integration = $false; full_e2e = $false }
Assert-Scope -Name "backend pointer" -Paths @("backend") -Expected @{ backend = $true; integration = $true; ui = $false }
Assert-Scope -Name "ui pointer" -Paths @("ui") -Expected @{ ui = $true; integration = $true; backend = $false }
Assert-Scope -Name "compose" -Paths @("compose.back.yml") -Expected @{ integration = $true; docker = $true }
Assert-Scope -Name "contract" -Paths @("contracts/data/example.md") -Expected @{ integration = $true; root = $true }
Assert-Scope -Name "terraform" -Paths @("infra/terraform/environments/development/main.tf") -Expected @{ terraform = $true; integration = $false }
Assert-Scope -Name "deployment workflow" -Paths @(".github/workflows/development-release.yml") -Expected @{ terraform = $true }
Assert-Scope -Name "main" -Paths @() -Event push -Ref "refs/heads/main" -Expected @{ terraform = $true; full_e2e = $true; security = $true }
Assert-Scope -Name "nightly" -Paths @() -Event schedule -Expected @{ full_e2e = $true; security = $true }
Assert-Scope -Name "manual" -Paths @() -Event workflow_dispatch -Expected @{ terraform = $true; full_e2e = $true; security = $true }

Write-Output "CI change routing checks passed."
