[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$PlanJsonPath
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$plan = Get-Content -LiteralPath $PlanJsonPath -Raw | ConvertFrom-Json
$destructive = @(
    $plan.resource_changes |
        Where-Object { @($_.change.actions) -contains "delete" } |
        ForEach-Object {
            [pscustomobject]@{
                address = [string]$_.address
                actions = (@($_.change.actions) -join ",")
            }
        }
)

if ($destructive.Count -gt 0) {
    $details = ($destructive | ForEach-Object { "$($_.address) [$($_.actions)]" }) -join "; "
    throw "Development saved plan contains delete or replacement actions: $details"
}

[pscustomobject]@{
    status = "passed"
    delete_or_replace_count = 0
    resource_change_count = @($plan.resource_changes).Count
} | ConvertTo-Json -Compress
