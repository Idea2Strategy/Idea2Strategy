[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')][string]$RootSha,
    [Parameter(Mandatory = $true)][ValidatePattern('^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$')][string]$Bucket,
    [string]$AwsProfile = "idea2strategy-terraform",
    [string]$AwsRegion = "ap-northeast-2",
    [switch]$Execute
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
    if ($exitCode -ne 0) { throw "AWS policy artifact publication failed without exposing command output." }
    return (($output -join "`n") | ConvertFrom-Json)
}

$summary = [ordered]@{
    status = if ($Execute) { "ready-to-publish" } else { "validated-dry-run" }
    root_sha = $RootSha
    bucket = $Bucket
    artifact_fingerprint = $artifactSet.Fingerprint
    receipt_key = $artifactSet.ReceiptKey
    artifact_hashes = [ordered]@{
        "execution-policy" = $artifactSet.Artifacts['execution-policy'].sha256
        "runtime-policy" = $artifactSet.Artifacts['runtime-policy'].sha256
    }
}

if (-not $Execute -or -not $PSCmdlet.ShouldProcess(
        "s3://$Bucket/runtime/backtest/",
        "Publish exact versioned Backtest policy artifacts and their receipt")) {
    $summary | ConvertTo-Json -Depth 6
    return
}

$published = [ordered]@{}
foreach ($artifactId in @('execution-policy', 'runtime-policy')) {
    $artifact = $artifactSet.Artifacts[$artifactId]
    $response = Invoke-AwsJson @(
        's3api', 'put-object',
        '--bucket', $Bucket,
        '--key', [string]$artifact.key,
        '--body', [string]$artifact.path,
        '--server-side-encryption', 'AES256',
        '--content-type', 'application/json'
    )
    if ([string]::IsNullOrWhiteSpace([string]$response.VersionId)) {
        throw "Development Backtest policy artifacts require an S3 versioned bucket."
    }
    $published[$artifactId] = [ordered]@{
        key = [string]$artifact.key
        version_id = [string]$response.VersionId
        sha256 = [string]$artifact.sha256
    }
}

$receipt = [ordered]@{
    schema_version = 1
    status = "passed"
    root_sha = $RootSha
    artifact_fingerprint = $artifactSet.Fingerprint
    published_at = [DateTimeOffset]::UtcNow.ToString('o')
    backtest_policy_artifacts = $published
}
$temporary = [IO.Path]::GetTempFileName()
try {
    [IO.File]::WriteAllText(
        $temporary,
        ($receipt | ConvertTo-Json -Depth 8),
        [Text.UTF8Encoding]::new($false)
    )
    $receiptUpload = Invoke-AwsJson @(
        's3api', 'put-object',
        '--bucket', $Bucket,
        '--key', $artifactSet.ReceiptKey,
        '--body', $temporary,
        '--server-side-encryption', 'AES256',
        '--content-type', 'application/json'
    )
    if ([string]::IsNullOrWhiteSpace([string]$receiptUpload.VersionId)) {
        throw "Development Backtest policy artifact receipt requires an S3 versioned bucket."
    }
}
finally {
    Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
}

$receipt['receipt_key'] = $artifactSet.ReceiptKey
$receipt['receipt_version_id'] = [string]$receiptUpload.VersionId
$receipt | ConvertTo-Json -Depth 8
