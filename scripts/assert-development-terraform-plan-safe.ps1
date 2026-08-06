[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$PlanJsonPath,
    [string]$AllowedReplacementAddresses = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$plan = Get-Content -LiteralPath $PlanJsonPath -Raw | ConvertFrom-Json
$allowedAddresses = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$configuredAllowedAddresses = if ([string]::IsNullOrWhiteSpace($AllowedReplacementAddresses)) {
    @()
} else {
    @($AllowedReplacementAddresses.Split(';'))
}
foreach ($address in $configuredAllowedAddresses) {
    if ([string]::IsNullOrWhiteSpace($address) -or -not $allowedAddresses.Add($address)) {
        throw "Allowed replacement addresses must be non-empty and unique."
    }
}
$allowedReplacements = @(
    $plan.resource_changes |
        Where-Object {
            $actions = @($_.change.actions)
            $actions.Count -eq 2 -and
            $actions[0] -ceq "create" -and
            $actions[1] -ceq "delete" -and
            [string]$_.action_reason -ceq "replace_because_cannot_update" -and
            $allowedAddresses.Contains([string]$_.address)
        }
)
$destructive = @(
    $plan.resource_changes |
        Where-Object {
            $change = $_
            @($change.change.actions) -contains "delete" -and
            -not ($allowedReplacements | Where-Object { $_ -eq $change })
        } |
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
    allowed_replacement_count = $allowedReplacements.Count
    resource_change_count = @($plan.resource_changes).Count
} | ConvertTo-Json -Compress
