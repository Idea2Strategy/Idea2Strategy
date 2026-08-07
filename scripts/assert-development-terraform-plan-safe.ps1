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
$reviewedReplacementPolicies = @{
    "aws_ecs_task_definition.pipeline[0]" = @{
        type = "aws_ecs_task_definition"
        stable_fields = @(
            "family", "requires_compatibilities", "network_mode", "cpu", "memory",
            "execution_role_arn", "task_role_arn"
        )
    }
    "aws_instance.service[0]" = @{
        type = "aws_instance"
        stable_fields = @(
            "instance_type", "subnet_id", "iam_instance_profile", "vpc_security_group_ids"
        )
        required_after = @{ associate_public_ip_address = $true }
    }
    "aws_instance.trading[0]" = @{
        type = "aws_instance"
        stable_fields = @(
            "instance_type", "subnet_id", "iam_instance_profile", "vpc_security_group_ids"
        )
        required_after = @{ associate_public_ip_address = $true }
    }
    "aws_secretsmanager_secret_version.core_internal[0]" = @{
        type = "aws_secretsmanager_secret_version"
        stable_fields = @("secret_id")
    }
}
$allowedAddresses = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$configuredAllowedAddresses = if ([string]::IsNullOrWhiteSpace($AllowedReplacementAddresses)) {
    @()
} else {
    @($AllowedReplacementAddresses.Split(';'))
}
foreach ($address in $configuredAllowedAddresses) {
    if ([string]::IsNullOrWhiteSpace($address) -or
        -not $reviewedReplacementPolicies.ContainsKey($address) -or
        -not $allowedAddresses.Add($address)) {
        throw "Allowed replacement addresses must be non-empty and unique."
    }
}

function Test-StableReplacementIdentity([object]$Change) {
    $address = [string]$Change.address
    if (-not $allowedAddresses.Contains($address)) { return $false }
    $policy = $reviewedReplacementPolicies[$address]
    if ([string]$Change.mode -cne "managed" -or
        [string]$Change.type -cne [string]$policy.type -or
        [string]$Change.provider_name -cne "registry.terraform.io/hashicorp/aws" -or
        $null -eq $Change.change.before -or
        $null -eq $Change.change.after -or
        [string]::IsNullOrWhiteSpace([string]$Change.change.before.id)) {
        return $false
    }
    foreach ($field in @($policy.stable_fields)) {
        $beforeProperty = $Change.change.before.PSObject.Properties[$field]
        $afterProperty = $Change.change.after.PSObject.Properties[$field]
        if ($null -eq $beforeProperty -or $null -eq $afterProperty) { return $false }
        $beforeJson = $beforeProperty.Value | ConvertTo-Json -Compress -Depth 20
        $afterJson = $afterProperty.Value | ConvertTo-Json -Compress -Depth 20
        if ([string]$beforeJson -cne [string]$afterJson) { return $false }
    }
    if ($policy.ContainsKey("required_after")) {
        foreach ($field in @($policy.required_after.Keys)) {
            $afterProperty = $Change.change.after.PSObject.Properties[$field]
            if ($null -eq $afterProperty -or $afterProperty.Value -cne $policy.required_after[$field]) {
                return $false
            }
        }
    }
    return $true
}

function Test-ApprovedDeposedDelete([object]$Change) {
    $address = [string]$Change.address
    if (-not $allowedAddresses.Contains($address)) { return $false }
    $policy = $reviewedReplacementPolicies[$address]
    $deposedProperty = $Change.PSObject.Properties["deposed"]
    $actions = @($Change.change.actions)
    if ($null -eq $deposedProperty -or
        [string]::IsNullOrWhiteSpace([string]$deposedProperty.Value) -or
        $actions.Count -ne 1 -or
        $actions[0] -cne "delete" -or
        [string]$Change.mode -cne "managed" -or
        [string]$Change.type -cne [string]$policy.type -or
        [string]$Change.provider_name -cne "registry.terraform.io/hashicorp/aws" -or
        $null -eq $Change.change.before -or
        $null -ne $Change.change.after -or
        [string]::IsNullOrWhiteSpace([string]$Change.change.before.id)) {
        return $false
    }
    $currentObjects = @(
        $plan.resource_changes |
            Where-Object {
                [string]$_.address -ceq $address -and
                $null -eq $_.PSObject.Properties["deposed"]
            }
    )
    if ($currentObjects.Count -ne 1) { return $false }
    $current = $currentObjects[0]
    $currentActions = @($current.change.actions)
    if ([string]$current.mode -cne "managed" -or
        [string]$current.type -cne [string]$policy.type -or
        [string]$current.provider_name -cne "registry.terraform.io/hashicorp/aws" -or
        (($currentActions -contains "delete") -and
            -not (Test-StableReplacementIdentity -Change $current))) {
        return $false
    }
    return $true
}

$allowedReplacements = @(
    $plan.resource_changes |
        Where-Object {
            $actions = @($_.change.actions)
            $actions.Count -eq 2 -and
            $actions[0] -ceq "create" -and
            $actions[1] -ceq "delete" -and
            [string]$_.action_reason -ceq "replace_because_cannot_update" -and
            (Test-StableReplacementIdentity -Change $_)
        }
)
$allowedDeposedDeletes = @(
    $plan.resource_changes |
        Where-Object { Test-ApprovedDeposedDelete -Change $_ }
)
$destructive = @(
    $plan.resource_changes |
        Where-Object {
            $change = $_
            @($change.change.actions) -contains "delete" -and
            -not ($allowedReplacements | Where-Object { $_ -eq $change }) -and
            -not ($allowedDeposedDeletes | Where-Object { $_ -eq $change })
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
    allowed_deposed_delete_count = $allowedDeposedDeletes.Count
    resource_change_count = @($plan.resource_changes).Count
} | ConvertTo-Json -Compress
