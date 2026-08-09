[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidatePattern('^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$')][string]$Bucket,
    [string]$AwsProfile = "idea2strategy-terraform",
    [string]$AwsRegion = "ap-northeast-2"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "lib/development-backtest-policy-artifacts.ps1")
$artifactSet = Get-DevelopmentBacktestPolicyArtifactSet -RepositoryRoot $root

function Get-AwsArguments([string[]]$Arguments) {
    $result = @($Arguments) + @('--region', $AwsRegion, '--output', 'json')
    if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) { $result += @('--profile', $AwsProfile) }
    return $result
}

function Invoke-AwsJson([string[]]$Arguments) {
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = & aws @(Get-AwsArguments $Arguments) 2>$null
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($exitCode -ne 0) {
        throw "No verified Development Backtest policy artifact receipt exists. Run the authorized Development bootstrap publication first."
    }
    return (($output -join "`n") | ConvertFrom-Json)
}

$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ("idea2strategy-backtest-policy-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
try {
    $receiptPath = Join-Path $temporaryRoot 'receipt.json'
    $receiptObject = Invoke-AwsJson @(
        's3api', 'get-object', '--bucket', $Bucket, '--key', $artifactSet.ReceiptKey, $receiptPath
    )
    if ([string]::IsNullOrWhiteSpace([string]$receiptObject.VersionId)) {
        throw "Development Backtest policy artifact receipt is not versioned."
    }
    $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
    if ([int]$receipt.schema_version -ne 1 -or [string]$receipt.status -cne 'passed' -or
        [string]$receipt.artifact_fingerprint -cne $artifactSet.Fingerprint) {
        throw "Development Backtest policy artifact receipt does not match the repository artifact set."
    }

    $verified = [ordered]@{}
    foreach ($artifactId in @('execution-policy', 'runtime-policy')) {
        $expected = $artifactSet.Artifacts[$artifactId]
        $property = $receipt.backtest_policy_artifacts.PSObject.Properties[$artifactId]
        if ($null -eq $property) { throw "Backtest policy receipt is missing $artifactId." }
        $pin = $property.Value
        if ([string]$pin.key -cne [string]$expected.key -or
            [string]$pin.sha256 -cne [string]$expected.sha256 -or
            [string]::IsNullOrWhiteSpace([string]$pin.version_id)) {
            throw "Backtest policy receipt pin does not match $artifactId."
        }
        $download = Join-Path $temporaryRoot "$artifactId.json"
        $null = Invoke-AwsJson @(
            's3api', 'get-object', '--bucket', $Bucket, '--key', [string]$pin.key,
            '--version-id', [string]$pin.version_id, $download
        )
        $actual = (Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -cne [string]$expected.sha256) {
            throw "Published Backtest policy artifact hash mismatch: $artifactId"
        }
        $verified[$artifactId] = [ordered]@{
            key = [string]$pin.key
            version_id = [string]$pin.version_id
            sha256 = [string]$pin.sha256
        }
    }

    [ordered]@{
        status = 'passed'
        artifact_fingerprint = $artifactSet.Fingerprint
        receipt_key = $artifactSet.ReceiptKey
        receipt_version_id = [string]$receiptObject.VersionId
        backtest_policy_artifacts = $verified
    } | ConvertTo-Json -Depth 8
}
finally {
    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force -ErrorAction SilentlyContinue
}
