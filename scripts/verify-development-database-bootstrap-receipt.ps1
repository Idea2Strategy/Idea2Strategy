[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')][string]$RootSha,
    [Parameter(Mandatory = $true)][ValidatePattern('^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$')][string]$ReceiptBucket,
    [string]$AwsProfile = "idea2strategy-terraform",
    [string]$AwsRegion = "ap-northeast-2",
    [string]$BundleRoot = "db/flyway-ci-bundle",
    [hashtable]$RuntimeDatabaseSecretNames = @{
        backend  = "idea2strategy-dev/database/backend-runtime"
        batch    = "idea2strategy-dev/database/batch-runtime"
        backtest = "idea2strategy-dev/database/backtest-runtime"
        trading  = "idea2strategy-dev/database/trading-runtime"
        pipeline = "idea2strategy-dev/database/pipeline-runtime"
    }
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "lib/development-database-bootstrap-manifest.ps1")
$resolvedBundleRoot = if ([IO.Path]::IsPathRooted($BundleRoot)) { $BundleRoot } else { Join-Path $root $BundleRoot }
$bundle = Get-ValidatedDevelopmentFlywayBundle -BundleRoot $resolvedBundleRoot
$receiptKey = "deployment-bootstrap/$RootSha/$($bundle.Digest)/receipt.json"

$aws = Get-Command aws -ErrorAction SilentlyContinue
if ($null -eq $aws) { throw "AWS CLI v2 is required." }

function Invoke-AwsJson([string[]]$Arguments) {
    $commonArguments = @('--region', $AwsRegion, '--output', 'json')
    if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) { $commonArguments += @('--profile', $AwsProfile) }
    $output = & $aws.Source @Arguments @commonArguments
    if ($LASTEXITCODE -ne 0) { throw "AWS receipt verification failed." }
    return (($output -join "`n") | ConvertFrom-Json)
}

$receiptPath = [IO.Path]::GetTempFileName()
try {
    $download = Invoke-AwsJson @("s3api", "get-object", "--bucket", $ReceiptBucket, "--key", $receiptKey, $receiptPath)
    if ([string]::IsNullOrWhiteSpace([string]$download.VersionId)) {
        throw "Database bootstrap receipt must come from a versioned S3 object."
    }
    $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
}
finally {
    Remove-Item -LiteralPath $receiptPath -Force -ErrorAction SilentlyContinue
}

if ([string]$receipt.status -cne "passed" -or
    [string]$receipt.root_sha -cne $RootSha -or
    [string]$receipt.bundle_sha256 -cne $bundle.Digest -or
    [int]$receipt.migrations -ne $bundle.MigrationCount -or
    [int]$receipt.tables -ne 179 -or
    @($receipt.scoring_versions).Count -ne 4 -or
    [int]$receipt.policy_row_counts.fee -lt 1 -or
    [int]$receipt.policy_row_counts.buffer -lt 1 -or
    [int]$receipt.policy_row_counts.execution -lt 1) {
    throw "Database bootstrap receipt does not match the exact release candidate and Flyway bundle."
}

$expectedConsumers = @("backend", "backtest", "batch", "pipeline", "trading")
$receiptConsumers = @($receipt.secret_versions.PSObject.Properties.Name | Sort-Object)
if (($receiptConsumers -join ",") -cne ($expectedConsumers -join ",")) {
    throw "Database bootstrap receipt must identify exactly five runtime secret versions."
}
foreach ($consumer in $expectedConsumers) {
    $versionId = [string]$receipt.secret_versions.$consumer
    if ([string]::IsNullOrWhiteSpace($versionId)) { throw "Database bootstrap receipt has no secret version for '$consumer'." }
    $description = Invoke-AwsJson @("secretsmanager", "describe-secret", "--secret-id", [string]$RuntimeDatabaseSecretNames[$consumer])
    $stages = @($description.VersionIdsToStages.PSObject.Properties[$versionId].Value)
    if ($stages -notcontains "AWSCURRENT") {
        throw "Database secret '$consumer' no longer uses the receipt-bound version as AWSCURRENT."
    }
}

[pscustomobject]@{
    status = "passed"
    root_sha = $RootSha
    bundle_sha256 = $bundle.Digest
    migrations = $bundle.MigrationCount
    receipt_key = $receiptKey
    receipt_version = [string]$download.VersionId
} | ConvertTo-Json -Compress
