[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$PlanJsonPath,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-f]{40}-[0-9]+$')]
    [string]$ExpectedReleaseId
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Get-PropertyValue([object]$Object, [string]$Name) {
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Assert-PropertyUnchanged([object]$Before, [object]$After, [string]$Name, [string]$Address) {
    $beforeProperty = $Before.PSObject.Properties[$Name]
    $afterProperty = $After.PSObject.Properties[$Name]
    if (($null -eq $beforeProperty) -ne ($null -eq $afterProperty)) {
        throw "$Address changed the shape of $Name."
    }
    if ($null -eq $beforeProperty) { return }
    $beforeJson = $beforeProperty.Value | ConvertTo-Json -Compress -Depth 100
    $afterJson = $afterProperty.Value | ConvertTo-Json -Compress -Depth 100
    if ([string]$beforeJson -cne [string]$afterJson) {
        throw "$Address changed $Name during a frontend-only release."
    }
}

function Get-Origin([object]$Resource, [string]$OriginId) {
    $matches = @(
        @(Get-PropertyValue -Object $Resource -Name "origin") |
            Where-Object { [string](Get-PropertyValue -Object $_ -Name "origin_id") -ceq $OriginId }
    )
    if ($matches.Count -ne 1) {
        throw "Expected exactly one CloudFront origin named $OriginId."
    }
    return $matches[0]
}

function Assert-Update([object]$Change, [string]$Address, [string]$Type, [string]$Provider) {
    if ([string]$Change.address -cne $Address -or
        [string]$Change.mode -cne "managed" -or
        [string]$Change.type -cne $Type -or
        [string]$Change.provider_name -cne $Provider) {
        throw "Unexpected Terraform resource identity for $Address."
    }
    $actions = @($Change.change.actions)
    if ($actions.Count -ne 1 -or [string]$actions[0] -cne "update") {
        throw "$Address must be an in-place update."
    }
    if ($null -eq $Change.change.before -or $null -eq $Change.change.after) {
        throw "$Address must have before and after state."
    }
}

$plan = Get-Content -LiteralPath $PlanJsonPath -Raw | ConvertFrom-Json
$mutations = @(
    @($plan.resource_changes) |
        Where-Object {
            if ([string]$_.mode -cne "managed") { return $false }
            $actions = @($_.change.actions)
            return -not ($actions.Count -eq 1 -and
                ([string]$actions[0] -ceq "no-op" -or [string]$actions[0] -ceq "read"))
        }
)

$expectedAddresses = @(
    "aws_cloudfront_distribution.frontend[0]",
    "aws_ssm_parameter.frontend_release[0]",
    "terraform_data.public_release_guard[0]"
)
$actualAddresses = @($mutations | ForEach-Object { [string]$_.address } | Sort-Object)
if ($mutations.Count -ne $expectedAddresses.Count -or
    (@($actualAddresses) -join "|") -cne (@($expectedAddresses | Sort-Object) -join "|")) {
    throw "The frontend-only plan must update exactly the CloudFront release origin, release SSM parameter, and public release guard."
}

$cloudFront = @($mutations | Where-Object { [string]$_.address -ceq "aws_cloudfront_distribution.frontend[0]" })[0]
Assert-Update -Change $cloudFront -Address "aws_cloudfront_distribution.frontend[0]" -Type "aws_cloudfront_distribution" -Provider "registry.terraform.io/hashicorp/aws"

foreach ($stableField in @(
    "enabled", "is_ipv6_enabled", "comment", "default_root_object", "price_class",
    "aliases", "web_acl_id", "default_cache_behavior", "ordered_cache_behavior",
    "restrictions", "viewer_certificate"
)) {
    Assert-PropertyUnchanged -Before $cloudFront.change.before -After $cloudFront.change.after -Name $stableField -Address $cloudFront.address
}

$beforeOrigins = @(Get-PropertyValue -Object $cloudFront.change.before -Name "origin")
$afterOrigins = @(Get-PropertyValue -Object $cloudFront.change.after -Name "origin")
if ($beforeOrigins.Count -ne $afterOrigins.Count) {
    throw "The frontend-only plan must not add or remove CloudFront origins."
}
$beforeFrontendOrigin = Get-Origin -Resource $cloudFront.change.before -OriginId "frontend-s3"
$afterFrontendOrigin = Get-Origin -Resource $cloudFront.change.after -OriginId "frontend-s3"
$beforeFrontendPath = [string](Get-PropertyValue -Object $beforeFrontendOrigin -Name "origin_path")
$afterFrontendPath = [string](Get-PropertyValue -Object $afterFrontendOrigin -Name "origin_path")
if ($beforeFrontendPath -ceq $afterFrontendPath -or
    $afterFrontendPath -cne "/_releases/$ExpectedReleaseId") {
    throw "CloudFront must switch to the exact immutable frontend release."
}

$beforeFrontendClone = $beforeFrontendOrigin | ConvertTo-Json -Depth 100 | ConvertFrom-Json
$afterFrontendClone = $afterFrontendOrigin | ConvertTo-Json -Depth 100 | ConvertFrom-Json
$beforeFrontendClone.origin_path = "__FRONTEND_RELEASE__"
$afterFrontendClone.origin_path = "__FRONTEND_RELEASE__"
if (($beforeFrontendClone | ConvertTo-Json -Compress -Depth 100) -cne
    ($afterFrontendClone | ConvertTo-Json -Compress -Depth 100)) {
    throw "The frontend S3 origin changed beyond origin_path."
}

foreach ($beforeOrigin in $beforeOrigins) {
    $originId = [string](Get-PropertyValue -Object $beforeOrigin -Name "origin_id")
    if ($originId -ceq "frontend-s3") { continue }
    $afterOrigin = Get-Origin -Resource $cloudFront.change.after -OriginId $originId
    if (($beforeOrigin | ConvertTo-Json -Compress -Depth 100) -cne
        ($afterOrigin | ConvertTo-Json -Compress -Depth 100)) {
        throw "CloudFront origin $originId changed during a frontend-only release."
    }
}

$parameter = @($mutations | Where-Object { [string]$_.address -ceq "aws_ssm_parameter.frontend_release[0]" })[0]
Assert-Update -Change $parameter -Address "aws_ssm_parameter.frontend_release[0]" -Type "aws_ssm_parameter" -Provider "registry.terraform.io/hashicorp/aws"
foreach ($stableField in @("name", "type", "data_type", "tier", "key_id")) {
    Assert-PropertyUnchanged -Before $parameter.change.before -After $parameter.change.after -Name $stableField -Address $parameter.address
}
if ([string](Get-PropertyValue -Object $parameter.change.after -Name "name") -cne "/idea2strategy/dev/deployment/frontend-release" -or
    [string](Get-PropertyValue -Object $parameter.change.after -Name "value") -cne $ExpectedReleaseId) {
    throw "The frontend release SSM parameter must record the exact release ID."
}

$guard = @($mutations | Where-Object { [string]$_.address -ceq "terraform_data.public_release_guard[0]" })[0]
Assert-Update -Change $guard -Address "terraform_data.public_release_guard[0]" -Type "terraform_data" -Provider "registry.terraform.io/hashicorp/terraform"
$afterInput = Get-PropertyValue -Object $guard.change.after -Name "input"
$afterOutput = Get-PropertyValue -Object $guard.change.after -Name "output"
if ([string](Get-PropertyValue -Object $afterInput -Name "frontend_release_id") -cne $ExpectedReleaseId) {
    throw "The public release guard input must bind the exact frontend release ID."
}
$afterUnknown = Get-PropertyValue -Object $guard.change -Name "after_unknown"
$outputUnknown = Get-PropertyValue -Object $afterUnknown -Name "output"
if ($null -ne $afterOutput) {
    if ([string](Get-PropertyValue -Object $afterOutput -Name "frontend_release_id") -cne $ExpectedReleaseId) {
        throw "The known public release guard output must bind the exact frontend release ID."
    }
}
elseif ($outputUnknown -ne $true) {
    throw "The public release guard output must be exact or explicitly unknown until apply."
}
Assert-PropertyUnchanged -Before $guard.change.before -After $guard.change.after -Name "triggers_replace" -Address $guard.address

[pscustomobject]@{
    status = "passed"
    release_id = $ExpectedReleaseId
    resource_change_count = $mutations.Count
} | ConvertTo-Json -Compress
