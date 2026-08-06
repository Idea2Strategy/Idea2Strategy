[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')][string]$RootSha,
    [Parameter(Mandatory = $true)][ValidatePattern('^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$')][string]$ReceiptBucket,
    [string]$AwsProfile = "idea2strategy-terraform",
    [string]$AwsRegion = "ap-northeast-2",
    [string]$BundleRoot = "db/flyway-ci-bundle",
    [string]$PolicyArtifactRoot = "proposals/development-runtime-policy/artifacts",
    [string]$ScoringArtifactRoot = "proposals/development-scoring-template/artifacts",
    [switch]$AllowMissingReceipt,
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

function Resolve-RepositoryPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return $Path }
    return Join-Path $root $Path
}

function Get-ValidatedArtifactHash([string]$ArtifactRoot, [string]$ArtifactName) {
    $resolvedRoot = Resolve-RepositoryPath $ArtifactRoot
    $manifestPath = Join-Path $resolvedRoot "artifact-manifest.json"
    $artifactPath = Join-Path $resolvedRoot $ArtifactName
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
        throw "Database bootstrap artifact manifest or payload is missing: $ArtifactName"
    }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $property = $manifest.artifacts.PSObject.Properties[$ArtifactName]
    if ($null -eq $property -or [string]$property.Value -notmatch '^[0-9a-f]{64}$') {
        throw "Database bootstrap artifact manifest hash is malformed: $ArtifactName"
    }
    $actual = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -cne [string]$property.Value) {
        throw "Database bootstrap artifact hash mismatch: $ArtifactName"
    }
    return $actual
}

$resolvedBundleRoot = Resolve-RepositoryPath $BundleRoot
$bundle = Get-ValidatedDevelopmentFlywayBundle -BundleRoot $resolvedBundleRoot
$policySeedSha256 = Get-ValidatedArtifactHash $PolicyArtifactRoot "policy-seed.sql"
$scoringSeedSha256 = Get-ValidatedArtifactHash $ScoringArtifactRoot "scoring-template-seed.sql"
$artifactFingerprint = Get-DevelopmentDatabaseBootstrapFingerprint `
    -BundleSha256 $bundle.Digest `
    -PolicySeedSha256 $policySeedSha256 `
    -ScoringSeedSha256 $scoringSeedSha256
$exactReceiptKey = "deployment-bootstrap/$RootSha/$($bundle.Digest)/receipt.json"
$artifactReceiptKey = "deployment-bootstrap/artifacts/$artifactFingerprint/receipt.json"

$aws = Get-Command aws -ErrorAction SilentlyContinue
if ($null -eq $aws) { throw "AWS CLI v2 is required." }

function Get-AwsCommonArguments {
    $arguments = @('--region', $AwsRegion, '--output', 'json')
    if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) { $arguments += @('--profile', $AwsProfile) }
    return $arguments
}

function Invoke-AwsJson([string[]]$Arguments) {
    $output = & $aws.Source @Arguments @(Get-AwsCommonArguments)
    if ($LASTEXITCODE -ne 0) { throw "AWS receipt verification failed." }
    return (($output -join "`n") | ConvertFrom-Json)
}

function Get-VersionedReceipt([string]$ReceiptKey) {
    $receiptPath = [IO.Path]::GetTempFileName()
    try {
        $previousErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $output = & $aws.Source @('s3api', 'get-object', '--bucket', $ReceiptBucket, '--key', $ReceiptKey, $receiptPath) @(Get-AwsCommonArguments) 2>$null
            $downloadExitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
        if ($downloadExitCode -ne 0) { return $null }
        $download = (($output -join "`n") | ConvertFrom-Json)
        if ([string]::IsNullOrWhiteSpace([string]$download.VersionId)) {
            throw "Database bootstrap receipt must come from a versioned S3 object."
        }
        return [pscustomobject]@{
            Key = $ReceiptKey
            VersionId = [string]$download.VersionId
            Receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
        }
    }
    finally {
        Remove-Item -LiteralPath $receiptPath -Force -ErrorAction SilentlyContinue
    }
}

function Test-ReceiptMatchesArtifacts([object]$Receipt) {
    try {
        if ([string]$Receipt.status -cne "passed" -or
            [string]$Receipt.root_sha -notmatch '^[0-9a-f]{40}$' -or
            [string]$Receipt.bundle_sha256 -cne $bundle.Digest -or
            [string]$Receipt.policy_seed_sha256 -cne $policySeedSha256 -or
            [string]$Receipt.scoring_seed_sha256 -cne $scoringSeedSha256 -or
            [int]$Receipt.migrations -ne $bundle.MigrationCount -or
            [int]$Receipt.tables -ne 179 -or
            @($Receipt.scoring_versions).Count -ne 4 -or
            [int]$Receipt.policy_row_counts.fee -lt 1 -or
            [int]$Receipt.policy_row_counts.buffer -lt 1 -or
            [int]$Receipt.policy_row_counts.execution -lt 1) {
            return $false
        }
        $fingerprintProperty = $Receipt.PSObject.Properties['artifact_fingerprint']
        if ($null -ne $fingerprintProperty -and [string]$fingerprintProperty.Value -cne $artifactFingerprint) {
            return $false
        }
        return $true
    }
    catch {
        return $false
    }
}

$candidateKeys = [Collections.Generic.List[string]]::new()
$candidateKeys.Add($exactReceiptKey)
$candidateKeys.Add($artifactReceiptKey)
$listing = Invoke-AwsJson @('s3api', 'list-objects-v2', '--bucket', $ReceiptBucket, '--prefix', 'deployment-bootstrap/')
$legacyPattern = '^deployment-bootstrap/[0-9a-f]{40}/' + [regex]::Escape($bundle.Digest) + '/receipt\.json$'
foreach ($item in @($listing.Contents | Where-Object { [string]$_.Key -match $legacyPattern } | Sort-Object LastModified -Descending)) {
    if (-not $candidateKeys.Contains([string]$item.Key)) { $candidateKeys.Add([string]$item.Key) }
}

$selected = $null
foreach ($candidateKey in $candidateKeys) {
    $candidate = Get-VersionedReceipt $candidateKey
    if ($null -ne $candidate -and (Test-ReceiptMatchesArtifacts $candidate.Receipt)) {
        $selected = $candidate
        break
    }
}
if ($null -eq $selected) {
    if ($AllowMissingReceipt) {
        [pscustomobject]@{
            status = "missing"
            requested_root_sha = $RootSha
            artifact_fingerprint = $artifactFingerprint
            bundle_sha256 = $bundle.Digest
            migrations = $bundle.MigrationCount
            required_authorization = "BOOTSTRAP_DEVELOPMENT_DATABASE"
        } | ConvertTo-Json -Compress
        return
    }
    throw "No versioned database bootstrap receipt matches artifact fingerprint '$artifactFingerprint'. Re-run Development release with database_bootstrap_authorization set to BOOTSTRAP_DEVELOPMENT_DATABASE and approve the Development environment bootstrap gate."
}

$receipt = $selected.Receipt
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

$receiptRootSha = [string]$receipt.root_sha
[pscustomobject]@{
    status = "passed"
    requested_root_sha = $RootSha
    receipt_root_sha = $receiptRootSha
    reused = ($receiptRootSha -cne $RootSha)
    artifact_fingerprint = $artifactFingerprint
    bundle_sha256 = $bundle.Digest
    migrations = $bundle.MigrationCount
    receipt_key = $selected.Key
    receipt_version = $selected.VersionId
} | ConvertTo-Json -Compress
