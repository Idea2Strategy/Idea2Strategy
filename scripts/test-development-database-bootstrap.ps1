[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function Read-RequiredFile([string]$RelativePath) {
    $path = Join-Path $root $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required database bootstrap file is missing: $RelativePath"
    }
    return Get-Content -LiteralPath $path -Raw
}

function Assert-Contains([string]$Text, [string]$Needle, [string]$Message) {
    if (-not $Text.Contains($Needle)) { throw $Message }
}

function Assert-NotContains([string]$Text, [string]$Needle, [string]$Message) {
    if ($Text.Contains($Needle)) { throw $Message }
}

function Assert-Throws([scriptblock]$Action, [string]$ExpectedMessage, [string]$Message) {
    try {
        & $Action
    } catch {
        if ($_.Exception.Message -notlike "*$ExpectedMessage*") {
            throw "$Message Expected an error containing '$ExpectedMessage', got '$($_.Exception.Message)'."
        }
        return
    }
    throw "$Message Expected an exception."
}

function Write-Utf8NoBomTestFile([string]$Path, [string]$Content) {
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

function New-TestFlywayBundle([string]$Path, [hashtable]$Migrations, [string[]]$ManifestOrder) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    foreach ($name in $Migrations.Keys) {
        Write-Utf8NoBomTestFile (Join-Path $Path $name) ([string]$Migrations[$name])
    }
    $entries = foreach ($name in $ManifestOrder) {
        $hash = (Get-FileHash -LiteralPath (Join-Path $Path $name) -Algorithm SHA256).Hash.ToLowerInvariant()
        "$name`t$hash"
    }
    $manifest = (@("idea2strategy-flyway-bundle-v1") + @($entries)) -join "`n"
    $manifest += "`n"
    $manifestPath = Join-Path $Path "migration-bundle.manifest"
    Write-Utf8NoBomTestFile $manifestPath $manifest
    $digest = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-Utf8NoBomTestFile (Join-Path $Path "migration-bundle.sha256") "$digest`n"
}

$database = Read-RequiredFile "infra/terraform/environments/development/database.tf"
$runtime = Read-RequiredFile "infra/terraform/environments/development/runtime.tf"
$variables = Read-RequiredFile "infra/terraform/environments/development/variables.tf"
$compute = Read-RequiredFile "infra/terraform/environments/development/compute.tf"
$iam = Read-RequiredFile "infra/terraform/environments/development/iam.tf"
$security = Read-RequiredFile "infra/terraform/environments/development/security.tf"
$outputs = Read-RequiredFile "infra/terraform/environments/development/outputs.tf"
$orchestrator = Read-RequiredFile "scripts/invoke-development-database-bootstrap.ps1"
$receiptVerifier = Read-RequiredFile "scripts/verify-development-database-bootstrap-receipt.ps1"
$bootstrap = Read-RequiredFile "scripts/aws/development-database-bootstrap.sh"
$releaseWorkflow = Read-RequiredFile ".github/workflows/development-release.yml"
$artifactRoot = Join-Path $root "proposals/development-runtime-policy/artifacts"
$artifactManifest = Read-RequiredFile "proposals/development-runtime-policy/artifacts/artifact-manifest.json" | ConvertFrom-Json
$executionPolicy = Read-RequiredFile "proposals/development-runtime-policy/artifacts/execution-policy.json" | ConvertFrom-Json
$runtimePolicy = Read-RequiredFile "proposals/development-runtime-policy/artifacts/runtime-policy.json" | ConvertFrom-Json
$policySeed = Read-RequiredFile "proposals/development-runtime-policy/artifacts/policy-seed.sql"
$scoringSeed = Read-RequiredFile "proposals/development-scoring-template/artifacts/scoring-template-seed.sql"
$scoringManifest = Read-RequiredFile "proposals/development-scoring-template/artifacts/artifact-manifest.json" | ConvertFrom-Json
$migrationManifestLines = @(Get-Content -LiteralPath (Join-Path $root "db/flyway-ci-bundle/migration-bundle.manifest"))
$expectedMigrationCount = $migrationManifestLines.Count - 1
$manifestValidatorPath = Join-Path $root "scripts/lib/development-database-bootstrap-manifest.ps1"
if (-not (Test-Path -LiteralPath $manifestValidatorPath -PathType Leaf)) {
    throw "Dynamic Flyway manifest validator is missing."
}
. $manifestValidatorPath

$receiptTokens = $null
$receiptParseErrors = $null
$receiptAst = [Management.Automation.Language.Parser]::ParseInput($receiptVerifier, [ref]$receiptTokens, [ref]$receiptParseErrors)
if ($receiptParseErrors.Count -gt 0) { throw "Receipt verifier must parse before its failure classifier can be tested." }
$failureClassifierAst = $receiptAst.Find({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-AwsFailureCategory'
    }, $true)
if ($null -eq $failureClassifierAst) { throw "AWS receipt failure classifier is missing." }
Invoke-Expression $failureClassifierAst.Extent.Text
if ((Get-AwsFailureCategory 'An error occurred (NoSuchKey) when calling GetObject') -cne 'missing' -or
    (Get-AwsFailureCategory 'An error occurred (AccessDenied) when calling GetObject') -cne 'access-denied' -or
    (Get-AwsFailureCategory 'An error occurred (SlowDown) when calling GetObject') -cne 'throttled' -or
    (Get-AwsFailureCategory 'Could not connect to the endpoint URL') -cne 'transport') {
    throw "AWS receipt failures must distinguish missing objects from authorization and transient failures."
}

$fingerprintInputs = @{
    BundleSha256 = "1" * 64
    PolicySeedSha256 = "2" * 64
    ScoringSeedSha256 = "3" * 64
    DatabaseName = "idea2strategy_runtime"
}
$artifactFingerprint = Get-DevelopmentDatabaseBootstrapFingerprint @fingerprintInputs
if ($artifactFingerprint -notmatch '^[0-9a-f]{64}$' -or
    $artifactFingerprint -cne (Get-DevelopmentDatabaseBootstrapFingerprint @fingerprintInputs)) {
    throw "Database bootstrap artifact fingerprint must be deterministic lowercase SHA-256."
}
$changedFingerprint = Get-DevelopmentDatabaseBootstrapFingerprint `
    -BundleSha256 ("4" * 64) `
    -PolicySeedSha256 $fingerprintInputs.PolicySeedSha256 `
    -ScoringSeedSha256 $fingerprintInputs.ScoringSeedSha256 `
    -DatabaseName $fingerprintInputs.DatabaseName
if ($changedFingerprint -ceq $artifactFingerprint) {
    throw "Database bootstrap artifact fingerprint must change when an input digest changes."
}
$changedDatabaseFingerprint = Get-DevelopmentDatabaseBootstrapFingerprint `
    -BundleSha256 $fingerprintInputs.BundleSha256 `
    -PolicySeedSha256 $fingerprintInputs.PolicySeedSha256 `
    -ScoringSeedSha256 $fingerprintInputs.ScoringSeedSha256 `
    -DatabaseName "idea2strategy_runtime_next"
if ($changedDatabaseFingerprint -ceq $artifactFingerprint) {
    throw "Database bootstrap artifact fingerprint must bind the exact target database."
}

$publishedBundle = Get-ValidatedDevelopmentFlywayBundle -BundleRoot (Join-Path $root "db/flyway-ci-bundle")
if ($publishedBundle.MigrationCount -ne $expectedMigrationCount) {
    throw "Published Flyway bundle migration count was not derived from its exact manifest."
}

$testBundleRoot = Join-Path $root ".harness/local/tmp/test-development-database-bootstrap-manifest-$PID"
try {
    $futureBundle = Join-Path $testBundleRoot "future"
    New-TestFlywayBundle $futureBundle @{
        "V1__first.sql" = "SELECT 1;`n"
        "V2__second.sql" = "SELECT 2;`n"
        "R__runtime_grants.sql" = "SELECT 3;`n"
    } @("V1__first.sql", "V2__second.sql", "R__runtime_grants.sql")
    $futureResult = Get-ValidatedDevelopmentFlywayBundle -BundleRoot $futureBundle
    if ($futureResult.MigrationCount -ne 3) {
        throw "Future versioned and repeatable migrations must be accepted without a source-code count change."
    }

    $emptyBundle = Join-Path $testBundleRoot "empty"
    New-TestFlywayBundle $emptyBundle @{} @()
    Assert-Throws { Get-ValidatedDevelopmentFlywayBundle -BundleRoot $emptyBundle } "at least one migration" "Header-only manifests must fail closed."

    $duplicateBundle = Join-Path $testBundleRoot "duplicate"
    New-TestFlywayBundle $duplicateBundle @{ "V1__first.sql" = "SELECT 1;`n" } @("V1__first.sql", "V1__first.sql")
    Assert-Throws { Get-ValidatedDevelopmentFlywayBundle -BundleRoot $duplicateBundle } "duplicate" "Duplicate manifest entries must fail closed."

    $duplicateVersionBundle = Join-Path $testBundleRoot "duplicate-version"
    New-TestFlywayBundle $duplicateVersionBundle @{
        "V20260806100000__identity.sql" = "SELECT 1;`n"
        "V20260806100000__strategy.sql" = "SELECT 2;`n"
    } @("V20260806100000__identity.sql", "V20260806100000__strategy.sql")
    Assert-Throws { Get-ValidatedDevelopmentFlywayBundle -BundleRoot $duplicateVersionBundle } "duplicate version" "Independent service migrations must not reuse a Flyway version."

    $normalizedDuplicateVersionBundle = Join-Path $testBundleRoot "normalized-duplicate-version"
    New-TestFlywayBundle $normalizedDuplicateVersionBundle @{
        "V01_002__identity.sql" = "SELECT 1;`n"
        "V1.2__strategy.sql" = "SELECT 2;`n"
    } @("V01_002__identity.sql", "V1.2__strategy.sql")
    Assert-Throws { Get-ValidatedDevelopmentFlywayBundle -BundleRoot $normalizedDuplicateVersionBundle } "duplicate version" "Flyway-equivalent version spellings must collide before deployment."

    $dynamicScoringSeed = Join-Path $testBundleRoot "dynamic-scoring-seed.sql"
    Write-Utf8NoBomTestFile $dynamicScoringSeed @"
SELECT '11111111-1111-1111-1111-111111111111';
SELECT '22222222-2222-2222-2222-222222222222';
SELECT '11111111-1111-1111-1111-111111111111';
"@
    $dynamicScoringIds = @(Get-DevelopmentScoringSeedIds -SeedSqlPath $dynamicScoringSeed)
    if ($dynamicScoringIds.Count -ne 2) {
        throw "Scoring receipt cardinality must be derived from unique IDs in the exact seed artifact."
    }

    $driftBundle = Join-Path $testBundleRoot "checksum-drift"
    New-TestFlywayBundle $driftBundle @{ "V1__first.sql" = "SELECT 1;`n" } @("V1__first.sql")
    Write-Utf8NoBomTestFile (Join-Path $driftBundle "V1__first.sql") "SELECT 2;`n"
    Assert-Throws { Get-ValidatedDevelopmentFlywayBundle -BundleRoot $driftBundle } "checksum mismatch" "Migration checksum drift must fail closed."

    $extraBundle = Join-Path $testBundleRoot "unlisted"
    New-TestFlywayBundle $extraBundle @{ "V1__first.sql" = "SELECT 1;`n" } @("V1__first.sql")
    Write-Utf8NoBomTestFile (Join-Path $extraBundle "V2__unlisted.sql") "SELECT 2;`n"
    Assert-Throws { Get-ValidatedDevelopmentFlywayBundle -BundleRoot $extraBundle } "not listed" "Unlisted SQL files must fail closed."
} finally {
    if (Test-Path -LiteralPath $testBundleRoot) {
        Remove-Item -LiteralPath $testBundleRoot -Recurse -Force
    }
}

foreach ($artifactName in @("execution-policy.json", "runtime-policy.json", "policy-seed.sql")) {
    $expectedHash = [string]$artifactManifest.artifacts.$artifactName
    $actualHash = (Get-FileHash -LiteralPath (Join-Path $artifactRoot $artifactName) -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($expectedHash -cne $actualHash) { throw "Development policy artifact hash mismatch: $artifactName" }
}
if ($artifactManifest.sourceApprovalPullRequest -ne 225 -or
    $artifactManifest.sourceApprovalCommit -cne "47932bf5febda9aa9603fd4d77e7f2ed2b60c23c") {
    throw "Development policy artifacts must identify the exact reviewed proposal evidence."
}
if ($executionPolicy.schemaVersion -ne 1 -or $executionPolicy.policies.Count -ne 1) {
    throw "Development execution policy must publish exactly one schema-v1 policy."
}
$policy = $executionPolicy.policies[0]
if ($policy.version -cne "development-official-backtest-2026-q3-v1" -or
    $policy.feeRate -cne "0.002" -or $policy.slippageRateBps -ne 5 -or
    $policy.goodTillCancelledHorizonSeconds -ne 7776000 -or $policy.maxOrderHorizonSeconds -ne 7776000) {
    throw "Development execution policy diverges from the reviewed proposal."
}
if ($runtimePolicy.schemaVersion -ne 1 -or $runtimePolicy.attempt.maxAttempts -ne 3 -or
    $runtimePolicy.attempt.leaseDurationSeconds -ne 300 -or
    $runtimePolicy.attempt.attemptTimeoutSeconds -ne 1800 -or
    $runtimePolicy.attempt.maxCpuTimeSeconds -ne 300 -or
    $runtimePolicy.attempt.maxMemoryBytes -ne 536870912 -or
    $runtimePolicy.microstructure.maxVolumeParticipationBps -ne 1000 -or
    $runtimePolicy.microstructure.buyingPowerBufferBps -ne 1 -or
    $runtimePolicy.riskLimits.maxStrategyNotional -cne "1000000" -or
    $runtimePolicy.riskLimits.maxGrossExposure -cne "1000000" -or
    $runtimePolicy.riskLimits.maxInstrumentExposure -cne "250000") {
    throw "Development runtime policy diverges from the reviewed proposal."
}
foreach ($needle in @(
    "INSERT INTO trading.fee_policy_versions",
    "INSERT INTO trading.buying_power_buffer_policy_versions",
    "INSERT INTO backtest.execution_policy_versions",
    [string]$artifactManifest.artifacts."execution-policy.json",
    [string]$artifactManifest.artifacts."runtime-policy.json",
    [string]$policy.feePolicyId,
    [string]$policy.buyingPowerBufferPolicyId
)) {
    Assert-Contains $policySeed $needle "Development policy seed is missing reviewed value: $needle"
}

if ($scoringManifest.status -cne "proposed" -or $scoringManifest.approved -ne $false) {
    throw "Development scoring seed must remain an explicitly unapproved proposal."
}
$expectedScoringSeedHash = [string]$scoringManifest.artifacts."scoring-template-seed.sql"
$actualScoringSeedHash = (Get-FileHash -LiteralPath (Join-Path $root "proposals/development-scoring-template/artifacts/scoring-template-seed.sql") -Algorithm SHA256).Hash.ToLowerInvariant()
if ($expectedScoringSeedHash -cne $actualScoringSeedHash) {
    throw "Development scoring seed artifact hash mismatch."
}
foreach ($templateCode in @(
    "SINGLE_TOTAL_RETURN_V1",
    "SINGLE_SHARPE_V1",
    "SINGLE_MAX_DRAWDOWN_V1",
    "COMPOSITE_BALANCED_V1"
)) {
    Assert-Contains $scoringSeed $templateCode "Development scoring seed is missing proposed template: $templateCode"
}
Assert-Contains $scoringSeed "INSERT INTO competition.scoring_template_versions" "Scoring seed must target the scoring template catalog."
Assert-NotContains $scoringSeed "INSERT INTO trading." "Scoring seed must remain independent from fee and buffer policy seeds."
Assert-NotContains $scoringSeed "INSERT INTO backtest." "Scoring seed must remain independent from execution policy seeds."

Assert-Contains $database 'resource "aws_secretsmanager_secret" "runtime_database"' "Terraform must own runtime database secret metadata."
Assert-Contains $database 'for_each = var.runtime_database_secret_names' "All five configured runtime database secrets must be owned."
Assert-Contains $database 'prevent_destroy = true' "Runtime database secret metadata must be protected from destroy."
if ($database.Contains('aws_secretsmanager_secret_version')) {
    throw "Terraform must not own runtime database secret values."
}
if ($runtime.Contains('data "aws_secretsmanager_secret" "runtime_database"')) {
    throw "Runtime database secrets must not remain unmanaged data sources."
}

foreach ($needle in @(
    'resource "aws_iam_role" "database_bootstrap"',
    'AmazonSSMManagedInstanceCore',
    'resource "aws_iam_instance_profile" "database_bootstrap"',
    'deployment-bootstrap/*',
    'resource "aws_security_group" "database_bootstrap"',
    'resource "aws_vpc_security_group_ingress_rule" "rds_from_database_bootstrap"'
)) {
    Assert-Contains ($iam + $security) $needle "Dedicated database bootstrap IAM/network boundary is missing: $needle"
}
Assert-Contains $outputs 'output "database_bootstrap"' "Terraform must expose a credential-free bootstrap target descriptor."
Assert-Contains $outputs 'database_port            = aws_db_instance.this.port' "Database bootstrap must receive the exact Terraform-managed RDS port."
Assert-Contains $variables 'variable "runtime_database_name"' "The canonical runtime database must be separate from the preserved legacy loader database."
Assert-Contains $outputs 'database_name            = var.runtime_database_name' "Database bootstrap must target the canonical runtime database."
Assert-Contains $compute 'database_name                               = var.runtime_database_name' "Every runtime host must target the canonical runtime database."
Assert-Contains $database 'value = var.runtime_database_name' "The applied SSM database name must identify the canonical runtime database, not the preserved RDS initial database."
Assert-NotContains $bootstrap '-c "SELECT 1 FROM pg_database' "psql variables are not expanded reliably through -c; use standard input."
Assert-Contains $bootstrap 'REVOKE CONNECT ON DATABASE "$database_name" FROM $seed_role' "The temporary seed role must relinquish database access before it is dropped."
Assert-Contains $bootstrap 'REVOKE USAGE ON SCHEMA trading, backtest FROM $seed_role' "The temporary seed role must relinquish schema access before it is dropped."
Assert-Contains $bootstrap 'REVOKE SELECT, INSERT ON TABLE trading.fee_policy_versions' "The temporary seed role must relinquish table access before it is dropped."
Assert-Contains $bootstrap 'REVOKE USAGE ON SCHEMA competition FROM $seed_role' "The temporary seed role must relinquish scoring schema access before it is dropped."
Assert-Contains $bootstrap 'REVOKE SELECT, INSERT ON TABLE competition.scoring_template_versions' "The temporary seed role must relinquish scoring table access before it is dropped."
Assert-NotContains $bootstrap 'DROP OWNED BY $seed_role' "RDS master is not automatically a member of the temporary role and cannot use DROP OWNED BY."
Assert-NotContains $bootstrap 'ALTER ROLE %s LOGIN INHERIT NOSUPERUSER' "Runtime login rotation must not require PostgreSQL superuser-only ALTER ROLE clauses on RDS."

foreach ($needle in @(
    '[switch]$Execute',
    'function Get-AwsCommonArguments',
    'function Get-SanitizedSsmFailure',
    'StandardErrorContent',
    'Select-Object -Last 12',
    "CommandId '`$commandId'",
    'if (-not [string]::IsNullOrWhiteSpace($AwsProfile))',
    '$awsFallback = ""',
    'if (-not [string]::IsNullOrWhiteSpace([string]$env:ProgramFiles))',
    '[string]$PolicySeedSqlPath',
    '[string]$PolicySeedSha256',
    '[string]$ScoringSeedSqlPath',
    '[string]$ScoringSeedSha256',
    'policy-seed.sql',
    'policy_seed_sha256',
    'scoring-template-seed.sql',
    'scoring_seed_sha256',
    '--expected-migration-count',
    '$expectedMigrationCount = $validatedBundle.MigrationCount',
    '[int]$receipt.migrations -ne $expectedMigrationCount',
    '--database-port',
    'PutRolePolicy',
    'DeleteRolePolicy',
    'TerminateInstances',
    'AWS-RunShellScript',
    'base64 -d | bash',
    'HttpTokens=required',
    'HttpPutResponseHopLimit=2',
    'GetSecretValue',
    'PutSecretValue',
    'deployment-bootstrap',
    'Get-DevelopmentDatabaseBootstrapFingerprint',
    'deployment-bootstrap/artifacts/$artifactFingerprint/receipt.json',
    'artifact_fingerprint',
    'finally'
)) {
    Assert-Contains $orchestrator $needle "Orchestrator safety boundary is missing: $needle"
}
Assert-NotContains $orchestrator '@($Arguments) + @("--profile", $AwsProfile' "GitHub OIDC execution must not pass an empty AWS profile argument."
Assert-NotContains $orchestrator 'Get-Executable "aws" (Join-Path $env:ProgramFiles' "Linux runners must not evaluate the Windows AWS CLI fallback path."
foreach ($discoveryBoundary in @(
    'function Test-DatabaseBootstrapTarget',
    'function Resolve-AppliedDatabaseBootstrapTarget',
    "'ssm', 'get-parameters'",
    'Name=tag:Name,Values=idea2strategy-dev-public-a',
    'Name=group-name,Values=idea2strategy-dev-database-bootstrap',
    'idea2strategy-dev-database-bootstrap-instance-profile',
    'idea2strategy-dev-database-bootstrap-role',
    'subnet and security group belong to different VPCs',
    'instance profile has an unexpected role attachment',
    'if (Test-DatabaseBootstrapTarget $candidateTarget)'
)) {
    Assert-Contains $orchestrator $discoveryBoundary "Applied AWS bootstrap target discovery is missing: $discoveryBoundary"
}
Assert-NotContains $orchestrator 'Apply the reviewed Terraform secret-metadata/bootstrap-boundary plan before running this procedure.' "Bootstrap must fall back to exact applied AWS discovery when the local Terraform output schema has changed."
foreach ($databaseBoundary in @(
    '[string]$RuntimeDatabaseName = "idea2strategy_runtime"',
    '$RuntimeDatabaseName -ceq "idea2strategy"',
    '$target.database_name = $RuntimeDatabaseName',
    '[string]$receipt.database_name -cne $RuntimeDatabaseName',
    '-DatabaseName $RuntimeDatabaseName'
)) {
    Assert-Contains $orchestrator $databaseBoundary "Orchestrator must bind bootstrap execution and receipt evidence to the reviewed canonical database: $databaseBoundary"
}

foreach ($needle in @(
    '[switch]$AllowMissingReceipt',
    'Get-DevelopmentDatabaseBootstrapFingerprint',
    'deployment-bootstrap/artifacts/$artifactFingerprint/receipt.json',
    'list-objects-v2',
    'policy_seed_sha256',
    'scoring_seed_sha256',
    'requested_root_sha',
    'receipt_root_sha',
    'status = "missing"',
    'BOOTSTRAP_DEVELOPMENT_DATABASE'
)) {
    Assert-Contains $receiptVerifier $needle "Receipt reuse boundary is missing: $needle"
}
Assert-Contains $receiptVerifier '[string]$RuntimeDatabaseName = "idea2strategy_runtime"' "Receipt verification must name the reviewed canonical database."
Assert-Contains $receiptVerifier '[string]$Receipt.database_name -cne $RuntimeDatabaseName' "A receipt for another database must not be reusable."
Assert-Contains $receiptVerifier '-DatabaseName $RuntimeDatabaseName' "Receipt fingerprints must bind the canonical database name."
Assert-NotContains $receiptVerifier '[string]$receipt.root_sha -cne $RootSha' "Artifact-identical receipts must be reusable across root commits."
Assert-Contains $receiptVerifier 'function Get-AwsFailureCategory' "Receipt reads must classify AWS failures instead of treating all failures as missing objects."
Assert-Contains $receiptVerifier 'NoSuchKey' "Only an explicit S3 missing-object response may be treated as a missing receipt."
Assert-Contains $receiptVerifier 'access-denied' "S3/IAM/KMS authorization failures must remain actionable errors."
Assert-Contains $receiptVerifier 'current_secret_versions' "Receipt verification must report the independently current runtime secret versions."
Assert-NotContains $receiptVerifier 'no longer uses the receipt-bound version as AWSCURRENT' "Normal runtime secret rotation must not invalidate an artifact-bound database receipt."
Assert-NotContains $receiptVerifier '[int]$Receipt.tables -ne 179' "Receipt reuse must not embed a schema table-count constant."
Assert-NotContains $receiptVerifier '@($Receipt.scoring_versions).Count -ne 4' "Receipt reuse must derive scoring catalog cardinality from the hash-bound seed."
Assert-Contains $orchestrator 'function Remove-StaleBootstrapInstances' "A prior timed-out bootstrap instance must be recovered before a new run."
Assert-Contains $orchestrator '[string]$ExecutionId' "Each bootstrap lease must identify the exact workflow execution."
Assert-Contains $orchestrator '[switch]$ReclaimPriorExecution' "Workflow concurrency must explicitly authorize reclaiming a prior execution."
Assert-Contains $orchestrator 'Key=ExecutionId,Value=$ExecutionId' "Ephemeral instances must carry their exact execution lease owner."
Assert-Contains $orchestrator '$ReclaimPriorExecution -and $observedExecutionId -cne $CurrentExecutionId' "A completed prior workflow execution must be reclaimable without a fixed cooldown."
Assert-Contains $orchestrator 'wait instance-terminated' "Stale bootstrap recovery must finish before launching a replacement."
Assert-NotContains $orchestrator '[int]$receipt.tables -ne 179' "Orchestrator receipt validation must not embed a schema table-count constant."
Assert-NotContains $orchestrator '@($receipt.scoring_versions).Count -ne 4' "Orchestrator receipt validation must accept the exact hash-bound scoring catalog size."
Assert-NotContains $orchestrator 'HttpPutResponseHopLimit=1' "The pinned AWS CLI container requires two IMDSv2 network hops to use the instance role."
if ($orchestrator -match '(?i)Write-(Host|Output).*(password|SecretString)') {
    throw "Orchestrator must not print password or SecretString values."
}
Assert-Contains $orchestrator 'function Write-Utf8NoBomFile' "Orchestrator must provide a PowerShell 5.1-compatible UTF-8 no-BOM writer."
if ($orchestrator.Contains('-Encoding utf8NoBOM')) {
    throw "The utf8NoBOM encoding name is unavailable in Windows PowerShell 5.1."
}
Assert-Contains $orchestrator '$existing.Reservations | ForEach-Object { $_.Instances }' "Empty AWS Reservations arrays must be flattened safely on Windows PowerShell 5.1."
if ($orchestrator.Contains('@($existing.Reservations.Instances).Count')) {
    throw "Windows PowerShell 5.1 miscounts a property projection over an empty AWS Reservations array."
}
Assert-Contains $orchestrator "printf '%s  %s\n'" "Remote checksum verification must emit a real newline escape."
if ($orchestrator.Contains("printf '%s  %s\\n'")) {
    throw "A double backslash makes sha256sum treat the newline text as part of the filename."
}
Assert-NotContains $orchestrator 'ssm wait command-executed' "The AWS CLI command-executed waiter expires before the 30-minute SSM command timeout."
Assert-Contains $orchestrator 'ssm get-command-invocation' "The orchestrator must poll the exact SSM invocation until a terminal status."
Assert-Contains $orchestrator '$commandDeadline' "SSM invocation polling must have an explicit deadline matching the remote timeout."
Assert-Contains $orchestrator 'Start-Sleep -Seconds 5' "SSM invocation polling must be bounded without a hot loop."
foreach ($resilienceBoundary in @(
    'database-bootstrap-provisioning-failed',
    'Database bootstrap host readiness timed out.',
    'docker pull',
    'function Invoke-WithRetry',
    '$primaryError',
    'Cleanup also failed'
)) {
    Assert-Contains $orchestrator $resilienceBoundary "Bootstrap provisioning and cleanup resilience is missing: $resilienceBoundary"
}
Assert-Contains $orchestrator 'resolve:ssm:/aws/service/canonical/ubuntu/server/noble/stable/current/amd64/hvm/ebs-gp3/ami-id' "Bootstrap AMI resolution must use Canonical's supported public parameter boundary."
Assert-NotContains $orchestrator 'Sort-Object CreationDate -Descending' "Bootstrap must not select an unreviewed AMI by sorting the live EC2 catalog."

foreach ($consumer in @("backend", "batch", "backtest", "trading", "pipeline")) {
    Assert-Contains $bootstrap "idea2strategy_${consumer}_runtime" "Bootstrap LOGIN role is missing for $consumer."
    Assert-Contains $bootstrap "idea2strategy_${consumer}" "Bootstrap group role is missing for $consumer."
}
foreach ($needle in @(
    'set +x',
    'trap cleanup EXIT',
    'sha256sum --check',
    'redgate/flyway@sha256:',
    'amazon/aws-cli@sha256:',
    'migrate',
    'flyway -outOfOrder=true migrate >&2',
    'validate',
    'PIPELINE_WORKER_DATABASE_URL',
    'postgresql+psycopg://',
    'secretsmanager put-secret-value',
    'AWSPENDING',
    'update-secret-version-stage',
    'rollback_runtime_credentials',
    'rotation_started',
    'old_versions',
    'pull_image',
    'credential rollback failed and requires operator attention',
    'rollback_status',
    'pending_cleanup_complete',
    "WHERE EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'idea2strategy_%s_runtime')",
    'rolcanlogin',
    'pg_auth_members',
    'idea2strategy_policy_seed_bootstrap',
    'trading.fee_policy_versions',
    'trading.buying_power_buffer_policy_versions',
    'backtest.execution_policy_versions',
    'competition.scoring_template_versions',
    '--single-transaction',
    'policy_seed_sha256',
    'scoring_seed_sha256',
    'scoring_versions',
    'policy_versions',
    'PGDATABASE=postgres',
    'CREATE DATABASE',
    '--expected-migration-count',
    'expected_migration_count',
    'declare -A listed_migrations',
    'declare -A listed_versions',
    'Flyway migration is not listed in the manifest',
    'expected_scoring_ids',
    '--artifact-bucket',
    'instrument_count',
    'runtime/trading/instruments.json',
    'alpaca-sip-rights.json'
)) {
    Assert-Contains $bootstrap $needle "Host bootstrap safety or verification is missing: $needle"
}
Assert-Contains $bootstrap '--arg database_name "$database_name"' "The remote receipt must include the exact database that Flyway changed."
Assert-Contains $bootstrap 'database_name:$database_name' "The credential-free receipt JSON must bind the exact database target."
Assert-Contains $releaseWorkflow "runtime_database_name" "The release workflow must derive the reviewed runtime database name from Terraform variables."
Assert-Contains $releaseWorkflow "RuntimeDatabaseName = `$runtimeDatabaseName" "Receipt lookup and bootstrap execution must receive the same runtime database name."
$runtimeDatabaseArguments = [regex]::Matches($releaseWorkflow, '(?m)^\s+-RuntimeDatabaseName \$runtimeDatabaseName')
if ($runtimeDatabaseArguments.Count -ne 3) {
    throw "Bootstrap execution and both downstream receipt gates must pass the same runtime database name."
}
Assert-NotContains $bootstrap 'flyway migrate >&2' "Central multi-service migration bundles must explicitly apply validated late-arriving versions."
Assert-NotContains $bootstrap 'EXPECTED_MIGRATION_COUNT' "Host bootstrap must receive the locally validated manifest count instead of embedding a migration count."
Assert-NotContains $bootstrap "EXPECTED_TABLE_COUNT='179'" "The exact bundle receipt must not require a manually synchronized table-count constant."
Assert-Contains $bootstrap 'test "$table_count" -gt 0' "The receipt must still reject an empty application schema."
Assert-NotContains $bootstrap "jq -e 'length == 4'" "Scoring validation must derive cardinality from the hash-bound seed artifact."
Assert-NotContains $bootstrap '3c81fb2f387fa790e126e1aa40b18d389c44bcf9f7ef2cefdd6911fd2e1eec71' "Scoring row selection must not duplicate seed-specific hashes in executable code."
Assert-Contains $bootstrap '--version-stage AWSCURRENT' "Rollback-safe rotation must capture the current secret version before changing database passwords."
Assert-Contains $bootstrap '--version-stages AWSPENDING' "New credential values must be staged before database passwords change."
if ($bootstrap.IndexOf('--version-stages AWSPENDING') -gt $bootstrap.IndexOf('ALTER ROLE %s LOGIN')) {
    throw "Every new secret version must be staged before runtime database passwords are changed."
}
if ($bootstrap -match '(?m)^\s*echo\s+["'']?\$(master_json|master_password|password)\b' -or
    $bootstrap -match '(?m)^\s*printf\s+[^>\r\n]*\$(master_json|master_password)\b') {
    throw "Host bootstrap must not print credential-bearing variables."
}

$terraformFiles = Get-ChildItem -LiteralPath (Join-Path $root 'infra/terraform/environments/development') -Filter '*.tf' -File
$runtimeReferences = @($terraformFiles | Select-String -Pattern 'data\.aws_secretsmanager_secret\.runtime_database')
if ($runtimeReferences.Count -gt 0) {
    throw "Terraform still contains unmanaged runtime database secret references."
}

[pscustomobject]@{
    status = "passed"
    protected_secret_metadata = $true
    terraform_secret_versions = $false
    dedicated_bootstrap_boundary = $true
    consumers = 5
} | ConvertTo-Json -Compress
