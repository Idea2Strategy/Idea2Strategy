[CmdletBinding()]
param(
    [string]$AwsProfile = "idea2strategy-dev",
    [string]$ExpectedInfrastructureRegion = "ap-northeast-2",
    [string]$ExpectedEmailRegion = "us-east-1",
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d{12}$')]
    [string]$ExpectedAwsAccountId,
    [string]$DomainName = "ideatostrategy.com",
    [string]$FromAddress = "no-reply@ideatostrategy.com",
    [switch]$RequireProductionAccess
)

$ErrorActionPreference = "Stop"
$aws = Get-Command aws -ErrorAction Stop
$profileArgs = if ([string]::IsNullOrWhiteSpace($AwsProfile)) { @() } else { @("--profile", $AwsProfile) }

function Invoke-AwsJson {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $strictErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $result = (& $aws.Source @profileArgs @Arguments --output json 2>&1) -join "`n"
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $strictErrorPreference
    if ($exitCode -ne 0) {
        throw "AWS CLI command failed without exposing response content."
    }
    try {
        return $result | ConvertFrom-Json
    } catch {
        throw "AWS CLI returned invalid JSON."
    }
}

$identity = Invoke-AwsJson -Arguments @("sts", "get-caller-identity")
if ([string]$identity.Account -cne $ExpectedAwsAccountId) {
    throw "Authenticated AWS account does not match ExpectedAwsAccountId."
}

$configuredRegion = (& $aws.Source @profileArgs configure get region 2>$null) -join ""
if ($LASTEXITCODE -ne 0 -or $configuredRegion.Trim() -cne $ExpectedInfrastructureRegion) {
    throw "AWS profile region must be exactly $ExpectedInfrastructureRegion."
}
if ($FromAddress -cne $FromAddress.ToLowerInvariant() -or
    -not $FromAddress.EndsWith("@$($DomainName.ToLowerInvariant())", [StringComparison]::Ordinal)) {
    throw "FromAddress must be a lowercase mailbox under DomainName."
}

$account = Invoke-AwsJson -Arguments @("sesv2", "get-account", "--region", $ExpectedEmailRegion)
if (-not [bool]$account.SendingEnabled) {
    throw "SES account-level sending is disabled."
}
if ($RequireProductionAccess -and -not [bool]$account.ProductionAccessEnabled) {
    throw "SES sandbox exit is required before unrestricted Development delivery."
}

$emailIdentity = Invoke-AwsJson -Arguments @(
    "sesv2", "get-email-identity",
    "--region", $ExpectedEmailRegion,
    "--email-identity", $DomainName
)
if (-not [bool]$emailIdentity.VerifiedForSendingStatus) {
    throw "SES domain identity is not verified for sending."
}
if ([string]$emailIdentity.DkimAttributes.Status -cne "SUCCESS") {
    throw "SES DKIM status is not SUCCESS."
}

[pscustomobject]@{
    account_matches           = $true
    infrastructure_region     = $ExpectedInfrastructureRegion
    email_region              = $ExpectedEmailRegion
    domain                    = $DomainName
    from_address              = $FromAddress
    sending_enabled           = [bool]$account.SendingEnabled
    production_access_enabled = [bool]$account.ProductionAccessEnabled
    identity_verified         = [bool]$emailIdentity.VerifiedForSendingStatus
    dkim_status               = [string]$emailIdentity.DkimAttributes.Status
} | ConvertTo-Json -Compress
