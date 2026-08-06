[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidatePattern('^[0-9a-f]{40}$')][string]$RootSha,
    [Parameter(Mandatory = $true)][ValidatePattern('^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$')][string]$ReceiptBucket,
    [string]$AwsProfile = "idea2strategy-terraform",
    [string]$AwsRegion = "ap-northeast-2",
    [ValidatePattern('^[a-z][a-z0-9_]{2,62}$')][string]$RuntimeDatabaseName = "idea2strategy_runtime",
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
if ($RuntimeDatabaseName -ceq "idea2strategy" -or $RuntimeDatabaseName -in @("postgres", "rdsadmin")) {
    throw "RuntimeDatabaseName must identify the isolated canonical runtime database, not a preserved or administrative database."
}

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
$resolvedScoringSeedPath = Join-Path (Resolve-RepositoryPath $ScoringArtifactRoot) "scoring-template-seed.sql"
$expectedScoringVersionCount = @(Get-DevelopmentScoringSeedIds -SeedSqlPath $resolvedScoringSeedPath).Count
$artifactFingerprint = Get-DevelopmentDatabaseBootstrapFingerprint `
    -BundleSha256 $bundle.Digest `
    -PolicySeedSha256 $policySeedSha256 `
    -ScoringSeedSha256 $scoringSeedSha256 `
    -DatabaseName $RuntimeDatabaseName
$exactReceiptKey = "deployment-bootstrap/$RootSha/$($bundle.Digest)/receipt.json"
$artifactReceiptKey = "deployment-bootstrap/artifacts/$artifactFingerprint/receipt.json"

$aws = Get-Command aws -ErrorAction SilentlyContinue
if ($null -eq $aws) { throw "AWS CLI v2 is required." }

function Get-AwsCommonArguments {
    $arguments = @('--region', $AwsRegion, '--output', 'json')
    if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) { $arguments += @('--profile', $AwsProfile) }
    return $arguments
}

function Get-AwsFailureCategory([string]$ErrorText) {
    if ($ErrorText -match '(?i)(NoSuchKey|specified key does not exist)') { return 'missing' }
    if ($ErrorText -match '(?i)(AccessDenied|KMSAccessDenied|UnauthorizedOperation|not authorized|status code:\s*403)') { return 'access-denied' }
    if ($ErrorText -match '(?i)(SlowDown|Throttl|RequestLimitExceeded|TooManyRequests)') { return 'throttled' }
    if ($ErrorText -match '(?i)(timeout|timed out|connection|endpoint|name resolution|temporarily unavailable)') { return 'transport' }
    return 'aws-error'
}

function Invoke-AwsCapture([string[]]$Arguments) {
    $stdoutPath = [IO.Path]::GetTempFileName()
    $stderrPath = [IO.Path]::GetTempFileName()
    try {
        $previousErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            & $aws.Source @Arguments @(Get-AwsCommonArguments) 1>$stdoutPath 2>$stderrPath
            $exitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
        return [pscustomobject]@{
            ExitCode = $exitCode
            Output = (Get-Content -LiteralPath $stdoutPath -Raw -ErrorAction SilentlyContinue)
            Error = (Get-Content -LiteralPath $stderrPath -Raw -ErrorAction SilentlyContinue)
        }
    }
    finally {
        Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-AwsJson([string[]]$Arguments) {
    $capture = Invoke-AwsCapture $Arguments
    if ($capture.ExitCode -ne 0) {
        $category = Get-AwsFailureCategory ([string]$capture.Error)
        throw "AWS receipt verification operation '$($Arguments[0])' failed ($category)."
    }
    if ([string]::IsNullOrWhiteSpace([string]$capture.Output)) { return $null }
    return ([string]$capture.Output | ConvertFrom-Json)
}

function Get-VersionedReceipt([string]$ReceiptKey) {
    $receiptPath = [IO.Path]::GetTempFileName()
    try {
        $capture = Invoke-AwsCapture @('s3api', 'get-object', '--bucket', $ReceiptBucket, '--key', $ReceiptKey, $receiptPath)
        if ($capture.ExitCode -ne 0) {
            $category = Get-AwsFailureCategory ([string]$capture.Error)
            if ($category -eq 'missing') { return $null }
            throw "Unable to read database bootstrap receipt '$ReceiptKey' ($category)."
        }
        $download = ([string]$capture.Output | ConvertFrom-Json)
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
            [string]$Receipt.database_name -cne $RuntimeDatabaseName -or
            [int]$Receipt.migrations -ne $bundle.MigrationCount -or
            [int]$Receipt.tables -lt 1 -or
            @($Receipt.scoring_versions).Count -ne $expectedScoringVersionCount -or
            [int]$Receipt.policy_row_counts.fee -lt 1 -or
            [int]$Receipt.policy_row_counts.buffer -lt 1 -or
            [int]$Receipt.policy_row_counts.execution -lt 1 -or
            [int]$Receipt.instrument_count -lt 500 -or
            $null -eq $Receipt.trading_runtime_artifacts) {
            return $false
        }
        $rightsExpiry = [DateTimeOffset]::MinValue
        if (-not [DateTimeOffset]::TryParse([string]$Receipt.rights_expires_at, [ref]$rightsExpiry) -or
            $rightsExpiry -le [DateTimeOffset]::UtcNow.AddHours(2)) {
            return $false
        }
        foreach ($artifactName in @('instrument-mapping', 'provider-rights')) {
            $artifactProperty = $Receipt.trading_runtime_artifacts.PSObject.Properties[$artifactName]
            if ($null -eq $artifactProperty -or
                [string]$artifactProperty.Value.runtime -cne 'market-gateway' -or
                [string]$artifactProperty.Value.key -notmatch '^runtime/trading/[A-Za-z0-9._/-]+$' -or
                [string]$artifactProperty.Value.version_id -eq '' -or
                [string]$artifactProperty.Value.sha256 -notmatch '^[0-9a-f]{64}$') {
                return $false
            }
        }
        if ([string]$Receipt.trading_runtime_artifacts.PSObject.Properties['instrument-mapping'].Value.local_path -cne 'instruments.json' -or
            [string]$Receipt.trading_runtime_artifacts.PSObject.Properties['provider-rights'].Value.local_path -cne 'alpaca-sip-rights.json') {
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
$listingContents = @()
if ($null -ne $listing -and $null -ne $listing.PSObject.Properties['Contents']) {
    $listingContents = @($listing.Contents)
}
foreach ($item in @($listingContents | Where-Object { [string]$_.Key -match $legacyPattern } | Sort-Object LastModified -Descending)) {
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
            database_name = $RuntimeDatabaseName
            migrations = $bundle.MigrationCount
            required_authorization = "BOOTSTRAP_DEVELOPMENT_DATABASE"
        } | ConvertTo-Json -Compress
        return
    }
    throw "No versioned database bootstrap receipt matches artifact fingerprint '$artifactFingerprint'. Re-run Development release with database_bootstrap_authorization set to BOOTSTRAP_DEVELOPMENT_DATABASE and approve the Development environment bootstrap gate."
}

$receipt = $selected.Receipt
$expectedConsumers = @("backend", "backtest", "batch", "pipeline", "trading")
$secretVersionsProperty = $receipt.PSObject.Properties['secret_versions']
if ($null -eq $secretVersionsProperty -or $null -eq $secretVersionsProperty.Value) {
    throw "Database bootstrap receipt has no runtime secret version evidence."
}
$receiptConsumers = @($receipt.secret_versions.PSObject.Properties.Name | Sort-Object)
if (($receiptConsumers -join ",") -cne ($expectedConsumers -join ",")) {
    throw "Database bootstrap receipt must identify exactly five runtime secret versions."
}
foreach ($consumer in $expectedConsumers) {
    $versionId = [string]$receipt.secret_versions.$consumer
    if ([string]::IsNullOrWhiteSpace($versionId)) { throw "Database bootstrap receipt has no secret version for '$consumer'." }
}

$currentSecretVersions = [ordered]@{}
foreach ($consumer in $expectedConsumers) {
    if (-not $RuntimeDatabaseSecretNames.ContainsKey($consumer) -or
        [string]::IsNullOrWhiteSpace([string]$RuntimeDatabaseSecretNames[$consumer])) {
        throw "Runtime database secret name is missing for '$consumer'."
    }
    $description = Invoke-AwsJson @("secretsmanager", "describe-secret", "--secret-id", [string]$RuntimeDatabaseSecretNames[$consumer])
    if ($null -eq $description -or $null -eq $description.PSObject.Properties['VersionIdsToStages']) {
        throw "Database secret '$consumer' has no version-stage metadata."
    }
    $currentVersions = @($description.VersionIdsToStages.PSObject.Properties | Where-Object { @($_.Value) -contains 'AWSCURRENT' })
    if ($currentVersions.Count -ne 1) {
        throw "Database secret '$consumer' must expose exactly one independently current AWSCURRENT version."
    }
    $currentSecretVersions[$consumer] = [string]$currentVersions[0].Name
}

$secretVersionsCurrent = (($expectedConsumers | Where-Object {
    [string]$receipt.secret_versions.$_ -cne [string]$currentSecretVersions[$_]
}).Count -eq 0)
if (-not $secretVersionsCurrent) {
    if ($AllowMissingReceipt) {
        [pscustomobject]@{
            status = "stale"
            requested_root_sha = $RootSha
            artifact_fingerprint = $artifactFingerprint
            reason = "runtime-secret-version-mismatch"
            required_authorization = "BOOTSTRAP_DEVELOPMENT_DATABASE"
        } | ConvertTo-Json -Compress
        return
    }
    throw "Database bootstrap receipt runtime secret versions are not AWSCURRENT. Re-run the authorized Development database bootstrap before deployment."
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
    receipt_secret_versions_current = $secretVersionsCurrent
    current_secret_versions = $currentSecretVersions
    instrument_count = [int]$receipt.instrument_count
    rights_expires_at = [string]$receipt.rights_expires_at
    trading_runtime_artifacts = $receipt.trading_runtime_artifacts
} | ConvertTo-Json -Compress
