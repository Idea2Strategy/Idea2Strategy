[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
    [string]$AwsProfile = "idea2strategy-terraform",
    [string]$Region = "ap-northeast-2",
    [string]$ExpectedAwsAccountId = "",
    [string]$TerraformRoot = "infra/terraform/environments/development",
    [ValidatePattern('^[a-z][a-z0-9_]{2,62}$')][string]$RuntimeDatabaseName = "idea2strategy_runtime",
    [string]$InstanceType = "t3.small",
    [string]$PolicySeedSqlPath = "",
    [string]$PolicySeedSha256 = "",
    [string]$ScoringSeedSqlPath = "",
    [string]$ScoringSeedSha256 = "",
    [ValidatePattern('^[0-9]+-[0-9]+$')][string]$ExecutionId = "0-0",
    [switch]$ReclaimPriorExecution,
    [switch]$Execute
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "lib/development-database-bootstrap-manifest.ps1")
$expectedConsumers = @("backend", "batch", "backtest", "trading", "pipeline")
$inlinePolicyName = "idea2strategy-development-database-bootstrap-transient-secrets"
$awsCliImage = "amazon/aws-cli@sha256:310813a7eae8fd88da1cc9c37970e3500b0ff3984479e1012f0a6fd44e453f63"

function Get-Executable([string]$Name, [string]$Fallback = "") {
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -ne $command) { return $command.Source }
    if ($Fallback -and (Test-Path -LiteralPath $Fallback -PathType Leaf)) { return $Fallback }
    throw "Required executable is unavailable: $Name"
}

function Invoke-ExternalJson([string]$Executable, [string[]]$Arguments) {
    $output = & $Executable @Arguments 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "External command failed without exposing its output: $([IO.Path]::GetFileName($Executable)) $($Arguments[0])"
    }
    $text = ($output -join "`n").Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    return $text | ConvertFrom-Json
}

function Invoke-AwsJson([string[]]$Arguments) {
    return Invoke-ExternalJson $script:aws (@($Arguments) + @(Get-AwsCommonArguments -Json))
}

function Get-AwsCommonArguments([switch]$Json) {
    $arguments = @("--region", $Region)
    if ($Json) { $arguments += @("--output", "json") }
    if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) { $arguments += @("--profile", $AwsProfile) }
    return $arguments
}

function Invoke-WithRetry([scriptblock]$Operation, [string]$Description, [int]$Attempts = 5) {
    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        try {
            return & $Operation
        }
        catch {
            if ($attempt -eq $Attempts) { throw "$Description failed after $Attempts attempts. $($_.Exception.Message)" }
            Start-Sleep -Seconds ([Math]::Min(20, $attempt * 4))
        }
    }
}

function Test-DatabaseBootstrapTarget([object]$Candidate) {
    if ($null -eq $Candidate) { return $false }
    foreach ($propertyName in @(
            'artifact_bucket',
            'database_host',
            'database_name',
            'database_port',
            'instance_profile_name',
            'role_name',
            'security_group_id',
            'subnet_id',
            'master_secret_arn',
            'runtime_database_secrets'
        )) {
        if ($null -eq $Candidate.PSObject.Properties[$propertyName]) { return $false }
    }
    if ([string]$Candidate.artifact_bucket -cne "idea2strategy-dev-$ExpectedAwsAccountId-market-data" -or
        [string]$Candidate.database_host -notmatch '^[A-Za-z0-9.-]+$' -or
        [string]$Candidate.database_name -notmatch '^[A-Za-z0-9_]+$' -or
        [string]$Candidate.database_port -notmatch '^\d+$' -or
        [string]$Candidate.instance_profile_name -cne 'idea2strategy-dev-database-bootstrap-instance-profile' -or
        [string]$Candidate.role_name -cne 'idea2strategy-dev-database-bootstrap-role' -or
        [string]$Candidate.security_group_id -notmatch '^sg-[0-9a-f]+$' -or
        [string]$Candidate.subnet_id -notmatch '^subnet-[0-9a-f]+$' -or
        [string]$Candidate.master_secret_arn -notmatch "^arn:aws:secretsmanager:$([regex]::Escape($Region)):${ExpectedAwsAccountId}:secret:") {
        return $false
    }
    $runtimeSecrets = $Candidate.runtime_database_secrets
    if ($null -eq $runtimeSecrets) { return $false }
    $secretProperties = @($runtimeSecrets.PSObject.Properties)
    $observedSecretNames = (($secretProperties.Name | Sort-Object) -join ',')
    $expectedSecretNames = (($expectedConsumers | Sort-Object) -join ',')
    if ($observedSecretNames -cne $expectedSecretNames) { return $false }
    $secretArnPattern = "^arn:aws:secretsmanager:$([regex]::Escape($Region)):${ExpectedAwsAccountId}:secret:"
    return @($secretProperties | Where-Object { [string]$_.Value -notmatch $secretArnPattern }).Count -eq 0
}

function Resolve-AppliedDatabaseBootstrapTarget {
    $parameterNames = @(
        '/idea2strategy/dev/database/host',
        '/idea2strategy/dev/database/port',
        '/idea2strategy/dev/database/name',
        '/idea2strategy/dev/database/master-secret-arn'
    )
    $parameterArguments = @('ssm', 'get-parameters', '--names') + $parameterNames
    $parameterResponse = Invoke-AwsJson $parameterArguments
    $parameterValues = @{}
    foreach ($parameter in @($parameterResponse.Parameters)) {
        $parameterValues[[string]$parameter.Name] = [string]$parameter.Value
    }
    if ($parameterValues.Count -ne $parameterNames.Count) {
        throw 'Applied database bootstrap SSM parameters are incomplete.'
    }

    $subnets = Invoke-AwsJson @('ec2', 'describe-subnets', '--filters', 'Name=tag:Name,Values=idea2strategy-dev-public-a', 'Name=state,Values=available')
    $subnet = @($subnets.Subnets)
    if ($subnet.Count -ne 1 -or [string]$subnet[0].SubnetId -notmatch '^subnet-[0-9a-f]+$') {
        throw 'Unable to discover the exact applied database bootstrap subnet.'
    }
    $securityGroups = Invoke-AwsJson @('ec2', 'describe-security-groups', '--filters', 'Name=group-name,Values=idea2strategy-dev-database-bootstrap')
    $securityGroup = @($securityGroups.SecurityGroups)
    if ($securityGroup.Count -ne 1 -or [string]$securityGroup[0].GroupId -notmatch '^sg-[0-9a-f]+$') {
        throw 'Unable to discover the exact applied database bootstrap security group.'
    }
    if ([string]$subnet[0].VpcId -cne [string]$securityGroup[0].VpcId) {
        throw 'Applied database bootstrap subnet and security group belong to different VPCs.'
    }

    $instanceProfileName = 'idea2strategy-dev-database-bootstrap-instance-profile'
    $roleName = 'idea2strategy-dev-database-bootstrap-role'
    $instanceProfile = Invoke-AwsJson @('iam', 'get-instance-profile', '--instance-profile-name', $instanceProfileName)
    $profileRoles = @($instanceProfile.InstanceProfile.Roles)
    if ($profileRoles.Count -ne 1 -or [string]$profileRoles[0].RoleName -cne $roleName) {
        throw 'Applied database bootstrap instance profile has an unexpected role attachment.'
    }
    $null = Invoke-AwsJson @('iam', 'get-role', '--role-name', $roleName)
    $runtimeSecrets = [ordered]@{}
    foreach ($consumer in $expectedConsumers) {
        $secret = Invoke-AwsJson @('secretsmanager', 'describe-secret', '--secret-id', "idea2strategy-dev/database/$consumer-runtime")
        if ([string]$secret.ARN -notmatch "^arn:aws:secretsmanager:$([regex]::Escape($Region)):${ExpectedAwsAccountId}:secret:") {
            throw "Unable to discover the applied runtime database secret for '$consumer'."
        }
        $runtimeSecrets[$consumer] = [string]$secret.ARN
    }
    $artifactBucket = "idea2strategy-dev-$ExpectedAwsAccountId-market-data"
    $null = Invoke-AwsJson @('s3api', 'head-bucket', '--bucket', $artifactBucket)

    return [pscustomobject]@{
        artifact_bucket = $artifactBucket
        database_host = $parameterValues['/idea2strategy/dev/database/host']
        database_name = $parameterValues['/idea2strategy/dev/database/name']
        database_port = $parameterValues['/idea2strategy/dev/database/port']
        instance_profile_name = $instanceProfileName
        role_name = $roleName
        security_group_id = [string]$securityGroup[0].GroupId
        subnet_id = [string]$subnet[0].SubnetId
        master_secret_arn = $parameterValues['/idea2strategy/dev/database/master-secret-arn']
        runtime_database_secrets = [pscustomobject]$runtimeSecrets
    }
}

function Remove-StaleBootstrapInstances([object[]]$Instances, [string]$CurrentExecutionId) {
    $staleCutoff = [DateTimeOffset]::UtcNow.AddMinutes(-60)
    $staleIds = [Collections.Generic.List[string]]::new()
    $activeIds = [Collections.Generic.List[string]]::new()
    foreach ($instance in @($Instances)) {
        $instanceId = [string]$instance.InstanceId
        if ($instanceId -notmatch '^i-[0-9a-f]+$') {
            throw "Existing database bootstrap instance has an invalid ID."
        }
        $state = [string]$instance.State.Name
        $executionTag = @($instance.Tags | Where-Object { [string]$_.Key -ceq 'ExecutionId' } | Select-Object -First 1)
        $observedExecutionId = if ($executionTag.Count -eq 1) { [string]$executionTag[0].Value } else { '' }
        $launchTime = [DateTimeOffset]::MaxValue
        if ($null -ne $instance.PSObject.Properties['LaunchTime']) {
            $parsedLaunchTime = [DateTimeOffset]::MinValue
            if ([DateTimeOffset]::TryParse([string]$instance.LaunchTime, [ref]$parsedLaunchTime)) {
                $launchTime = $parsedLaunchTime
            }
        }
        if ($state -in @('stopped', 'stopping') -or $launchTime -le $staleCutoff -or
            ($ReclaimPriorExecution -and $observedExecutionId -cne $CurrentExecutionId)) {
            $staleIds.Add($instanceId)
        }
        else {
            $activeIds.Add($instanceId)
        }
    }
    if ($activeIds.Count -gt 0) {
        throw "An active database bootstrap instance is still present: $($activeIds -join ',')."
    }
    if ($staleIds.Count -gt 0) {
        $terminationArguments = @('ec2', 'terminate-instances', '--instance-ids') + @($staleIds)
        $null = Invoke-AwsJson $terminationArguments
        $awsCommonArguments = @(Get-AwsCommonArguments)
        $waitArguments = @('ec2', 'wait', 'instance-terminated', '--instance-ids') + @($staleIds) + $awsCommonArguments
        & $script:aws @waitArguments
        if ($LASTEXITCODE -ne 0) {
            throw "Expired database bootstrap instances did not terminate before replacement."
        }
    }
}

function Get-SanitizedSsmFailure([object]$Invocation) {
    $errorText = [string]$Invocation.StandardErrorContent
    if ([string]::IsNullOrWhiteSpace($errorText)) {
        return "Remote stderr was empty."
    }
    $safeDiagnostics = @($errorText -split "`r?`n" | Where-Object {
            $_ -match '^(ERROR:|Detected resolved migration|Flyway still reports pending migrations|Flyway migration (checksum mismatch|is missing|is not listed)|Database bootstrap |failed to run commands:)'
        } | Select-Object -Last 12)
    if ($safeDiagnostics.Count -eq 0) {
        return "Remote stderr contained no allowlisted diagnostic."
    }
    return "Remote diagnostics: $($safeDiagnostics -join ' | ')"
}

function ConvertTo-BashLiteral([string]$Value) {
    if ($Value.Contains("'")) { throw "Bootstrap target contains an unsupported quote character." }
    return "'$Value'"
}

function Write-Utf8NoBomFile([string]$LiteralPath, [string]$Content) {
    [IO.File]::WriteAllText($LiteralPath, $Content, [Text.UTF8Encoding]::new($false))
}

if ($Region -ne "ap-northeast-2") { throw "The Development database bootstrap is restricted to ap-northeast-2." }
if ($InstanceType -notmatch '^t3\.(micro|small|medium)$') { throw "Use a bounded x86 t3 instance for the amd64-only Flyway image." }
if ($RuntimeDatabaseName -ceq "idea2strategy" -or $RuntimeDatabaseName -in @("postgres", "rdsadmin")) {
    throw "RuntimeDatabaseName must identify the isolated canonical runtime database, not a preserved or administrative database."
}
if ([string]::IsNullOrWhiteSpace($PolicySeedSqlPath) -or -not (Test-Path -LiteralPath $PolicySeedSqlPath -PathType Leaf)) {
    throw "PolicySeedSqlPath must identify the separately approved post-Flyway policy seed SQL artifact."
}
if ($PolicySeedSha256 -notmatch '^[0-9a-f]{64}$') { throw "PolicySeedSha256 must be the reviewed lowercase SHA-256." }
$resolvedPolicySeedPath = (Resolve-Path -LiteralPath $PolicySeedSqlPath).Path
$actualPolicySeedSha256 = (Get-FileHash -LiteralPath $resolvedPolicySeedPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualPolicySeedSha256 -cne $PolicySeedSha256) { throw "Approved policy seed SQL SHA-256 mismatch." }
if ([string]::IsNullOrWhiteSpace($ScoringSeedSqlPath) -or -not (Test-Path -LiteralPath $ScoringSeedSqlPath -PathType Leaf)) {
    throw "ScoringSeedSqlPath must identify the separately approved scoring template seed SQL artifact."
}
if ($ScoringSeedSha256 -notmatch '^[0-9a-f]{64}$') { throw "ScoringSeedSha256 must be the reviewed lowercase SHA-256." }
$resolvedScoringSeedPath = (Resolve-Path -LiteralPath $ScoringSeedSqlPath).Path
$actualScoringSeedSha256 = (Get-FileHash -LiteralPath $resolvedScoringSeedPath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualScoringSeedSha256 -cne $ScoringSeedSha256) { throw "Approved scoring seed SQL SHA-256 mismatch." }
$expectedScoringVersionCount = @(Get-DevelopmentScoringSeedIds -SeedSqlPath $resolvedScoringSeedPath).Count

$head = (& git -C $root rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $head -notmatch '^[0-9a-f]{40}$') { throw "Unable to identify the exact root commit." }
$trackedStatus = (& git -C $root status --porcelain=v1 --untracked-files=no) -join "`n"
if (-not [string]::IsNullOrWhiteSpace($trackedStatus)) { throw "Database bootstrap requires a checkout with no tracked changes." }

$bundleRoot = Join-Path $root "db/flyway-ci-bundle"
$hostScriptPath = Join-Path $root "scripts/aws/development-database-bootstrap.sh"
if (-not (Test-Path -LiteralPath $hostScriptPath -PathType Leaf)) { throw "Required bootstrap input is missing: $hostScriptPath" }
$validatedBundle = Get-ValidatedDevelopmentFlywayBundle -BundleRoot $bundleRoot
$bundleDigest = $validatedBundle.Digest
$expectedMigrationCount = $validatedBundle.MigrationCount

$awsFallback = ""
if (-not [string]::IsNullOrWhiteSpace([string]$env:ProgramFiles)) {
    $awsFallback = Join-Path $env:ProgramFiles "Amazon/AWSCLIV2/aws.exe"
}
$script:aws = Get-Executable "aws" $awsFallback
$caller = Invoke-AwsJson @("sts", "get-caller-identity")
if ([string]::IsNullOrWhiteSpace($ExpectedAwsAccountId) -or $ExpectedAwsAccountId -notmatch '^\d{12}$') {
    throw "ExpectedAwsAccountId must be the reviewed 12-digit Development account."
}
if ([string]$caller.Account -cne $ExpectedAwsAccountId) { throw "AWS account mismatch." }
$target = $null
$terraform = Get-Command terraform -ErrorAction SilentlyContinue
if ($null -ne $terraform) {
    $terraformPath = Join-Path $root $TerraformRoot
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $targetText = (& $terraform.Source "-chdir=$terraformPath" output -json database_bootstrap 2>$null) -join "`n"
        $targetExitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($targetExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($targetText)) {
        try {
            $candidateTarget = $targetText | ConvertFrom-Json
            if (Test-DatabaseBootstrapTarget $candidateTarget) { $target = $candidateTarget }
        }
        catch {
            $target = $null
        }
    }
}
if ($null -eq $target) {
    $target = Resolve-AppliedDatabaseBootstrapTarget
}
if (-not (Test-DatabaseBootstrapTarget $target)) {
    throw 'Applied database bootstrap target discovery returned an incomplete boundary.'
}
# Infrastructure discovery supplies the applied RDS endpoint and IAM/network
# boundary. The target database is a reviewed release input because the applied
# SSM/Terraform state can still name the preserved loader database until this
# same release updates it.
$target.database_name = $RuntimeDatabaseName
$bootstrapImageReference = "resolve:ssm:/aws/service/canonical/ubuntu/server/noble/stable/current/amd64/hvm/ebs-gp3/ami-id"

$secretProperties = @($target.runtime_database_secrets.PSObject.Properties)
$observedSecretNames = (($secretProperties.Name | Sort-Object) -join ',')
$expectedSecretNames = (($expectedConsumers | Sort-Object) -join ',')
if ($observedSecretNames -cne $expectedSecretNames) {
    throw "Terraform output must contain exactly five runtime database secret ARNs."
}
foreach ($secret in $secretProperties) {
    if ([string]$secret.Value -notmatch '^arn:aws:secretsmanager:') { throw "Runtime database secret ARN is malformed." }
    $null = Invoke-AwsJson @("secretsmanager", "describe-secret", "--secret-id", [string]$secret.Value)
}

$temporaryRoot = Join-Path $root ".harness/local/tmp/database-bootstrap/$head"
if (-not (Test-Path -LiteralPath $temporaryRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $temporaryRoot -Force | Out-Null
}
$archivePath = Join-Path $temporaryRoot "flyway-ci-bundle.tar.gz"
if (Test-Path -LiteralPath $archivePath -PathType Leaf) { Remove-Item -LiteralPath $archivePath -Force }
$tar = Get-Executable "tar"
& $tar -czf $archivePath -C (Join-Path $root "db") "flyway-ci-bundle"
if ($LASTEXITCODE -ne 0) { throw "Unable to create the Flyway bundle archive." }
$archiveDigest = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
$hostScriptDigest = (Get-FileHash -LiteralPath $hostScriptPath -Algorithm SHA256).Hash.ToLowerInvariant()
$artifactFingerprint = Get-DevelopmentDatabaseBootstrapFingerprint `
    -BundleSha256 $bundleDigest `
    -PolicySeedSha256 $PolicySeedSha256 `
    -ScoringSeedSha256 $ScoringSeedSha256 `
    -DatabaseName $RuntimeDatabaseName

$artifactPrefix = "deployment-bootstrap/$head/$bundleDigest"
$archiveKey = "$artifactPrefix/flyway-ci-bundle.tar.gz"
$hostScriptKey = "$artifactPrefix/development-database-bootstrap.sh"
$policySeedKey = "$artifactPrefix/policy-seed-$PolicySeedSha256.sql"
$scoringSeedKey = "$artifactPrefix/scoring-template-seed-$ScoringSeedSha256.sql"
$receiptKey = "$artifactPrefix/receipt.json"
$artifactReceiptKey = "deployment-bootstrap/artifacts/$artifactFingerprint/receipt.json"
$safePlan = [ordered]@{
    status = if ($Execute) { "ready-to-execute" } else { "validated-dry-run" }
    root_sha = $head
    bundle_sha256 = $bundleDigest
    migrations = $expectedMigrationCount
    archive_sha256 = $archiveDigest
    host_script_sha256 = $hostScriptDigest
    policy_seed_sha256 = $PolicySeedSha256
    scoring_seed_sha256 = $ScoringSeedSha256
    database_name = $RuntimeDatabaseName
    artifact_fingerprint = $artifactFingerprint
    region = $Region
    instance_type = $InstanceType
    ami_reference = $bootstrapImageReference
    consumers = $expectedConsumers
    artifact_prefix = $artifactPrefix
    artifact_receipt_key = $artifactReceiptKey
    secret_values_in_terraform = $false
}

if (-not $Execute -or -not $PSCmdlet.ShouldProcess(
    "Development private RDS and five runtime Secrets Manager versions",
    "Run exact one-shot Flyway and credential bootstrap on an ephemeral SSM instance")) {
    $safePlan | ConvertTo-Json -Depth 4
    return
}

$instanceId = ""
$policyAttached = $false
$commandId = ""
$result = $null
$primaryError = $null
$cleanupErrors = [Collections.Generic.List[string]]::new()
$cleanupFailure = ""
try {
    $archiveUpload = Invoke-AwsJson @("s3api", "put-object", "--bucket", [string]$target.artifact_bucket, "--key", $archiveKey, "--body", $archivePath)
    $scriptUpload = Invoke-AwsJson @("s3api", "put-object", "--bucket", [string]$target.artifact_bucket, "--key", $hostScriptKey, "--body", $hostScriptPath)
    $policySeedUpload = Invoke-AwsJson @("s3api", "put-object", "--bucket", [string]$target.artifact_bucket, "--key", $policySeedKey, "--body", $resolvedPolicySeedPath)
    $scoringSeedUpload = Invoke-AwsJson @("s3api", "put-object", "--bucket", [string]$target.artifact_bucket, "--key", $scoringSeedKey, "--body", $resolvedScoringSeedPath)
    if ([string]::IsNullOrWhiteSpace([string]$archiveUpload.VersionId) -or
        [string]::IsNullOrWhiteSpace([string]$scriptUpload.VersionId) -or
        [string]::IsNullOrWhiteSpace([string]$policySeedUpload.VersionId) -or
        [string]::IsNullOrWhiteSpace([string]$scoringSeedUpload.VersionId)) {
        throw "Bootstrap artifacts must be stored in a versioned S3 bucket."
    }

    $secretResources = @([string]$target.master_secret_arn) + @($secretProperties.Value | ForEach-Object { [string]$_ })
    $policyDocument = [ordered]@{
        Version = "2012-10-17"
        Statement = @(
            [ordered]@{
                Sid = "ReadOnlyRdsMasterCredential"
                Effect = "Allow"
                Action = @("secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret")
                Resource = @([string]$target.master_secret_arn)
            },
            [ordered]@{
                Sid = "RotateRuntimeCredentialVersions"
                Effect = "Allow"
                Action = @("secretsmanager:GetSecretValue", "secretsmanager:PutSecretValue", "secretsmanager:UpdateSecretVersionStage", "secretsmanager:DescribeSecret")
                Resource = @($secretResources | Select-Object -Skip 1)
            },
            [ordered]@{
                Sid = "PublishTradingRuntimeArtifacts"
                Effect = "Allow"
                Action = @("s3:PutObject")
                Resource = "arn:aws:s3:::$([string]$target.artifact_bucket)/runtime/trading/*"
            }
        )
    }
    $policyPath = Join-Path $temporaryRoot "transient-secret-policy.json"
    Write-Utf8NoBomFile $policyPath ($policyDocument | ConvertTo-Json -Depth 8)
    # PutRolePolicy: this exact secret policy exists only for the command window.
    $null = Invoke-AwsJson @("iam", "put-role-policy", "--role-name", [string]$target.role_name, "--policy-name", $inlinePolicyName, "--policy-document", "file://$policyPath")
    $policyAttached = $true
    $null = Invoke-WithRetry {
        Invoke-AwsJson @('iam', 'get-role-policy', '--role-name', [string]$target.role_name, '--policy-name', $inlinePolicyName)
    } 'Transient database bootstrap IAM policy propagation'

    $userDataPath = Join-Path $temporaryRoot "bootstrap-user-data.sh"
    $userData = @'
#!/usr/bin/env bash
set -Eeuo pipefail
set +x
export DEBIAN_FRONTEND=noninteractive
failure_marker=/var/lib/idea2strategy-database-bootstrap-provisioning-failed
trap 'status=$?; if [[ $status -ne 0 ]]; then printf "Database bootstrap host provisioning failed with status %s.\n" "$status" >"$failure_marker"; fi' EXIT
retry_command() {
  local attempt
  for attempt in 1 2 3 4 5; do
    "$@" && return 0
    sleep $((attempt * 5))
  done
  return 1
}
systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service || true
retry_command apt-get update -qq
retry_command apt-get install -y -qq docker.io jq postgresql-client python3 openssl ca-certificates
retry_command systemctl enable --now docker
touch /var/lib/idea2strategy-database-bootstrap-ready
rm -f "$failure_marker"
trap - EXIT
'@
    Write-Utf8NoBomFile $userDataPath $userData

    $existing = Invoke-AwsJson @("ec2", "describe-instances", "--filters", "Name=tag:Purpose,Values=idea2strategy-development-database-bootstrap", "Name=instance-state-name,Values=pending,running,stopping,stopped")
    $existingInstances = @($existing.Reservations | ForEach-Object { $_.Instances })
    Remove-StaleBootstrapInstances $existingInstances $ExecutionId

    $tagSpecification = "ResourceType=instance,Tags=[{Key=Name,Value=idea2strategy-dev-database-bootstrap},{Key=Project,Value=idea2strategy},{Key=Environment,Value=dev},{Key=Purpose,Value=idea2strategy-development-database-bootstrap},{Key=SourceCommit,Value=$head},{Key=ExecutionId,Value=$ExecutionId}]"
    $launch = Invoke-AwsJson @(
        "ec2", "run-instances",
        "--image-id", $bootstrapImageReference,
        "--instance-type", $InstanceType,
        "--iam-instance-profile", "Name=$([string]$target.instance_profile_name)",
        "--subnet-id", [string]$target.subnet_id,
        "--security-group-ids", [string]$target.security_group_id,
        "--associate-public-ip-address",
        # The pinned AWS CLI runs in a host-network container. IMDSv2 remains
        # mandatory, while a hop limit of two is required for that container to
        # obtain only this instance profile's short-lived role credentials.
        "--metadata-options", "HttpTokens=required,HttpEndpoint=enabled,HttpPutResponseHopLimit=2",
        "--block-device-mappings", "DeviceName=/dev/sda1,Ebs={VolumeSize=16,VolumeType=gp3,Encrypted=true,DeleteOnTermination=true}",
        "--tag-specifications", $tagSpecification,
        "--user-data", "file://$userDataPath",
        "--count", "1"
    )
    $instanceId = [string]$launch.Instances[0].InstanceId
    $resolvedBootstrapAmiId = [string]$launch.Instances[0].ImageId
    if ($instanceId -notmatch '^i-[0-9a-f]+$') { throw "EC2 did not return one exact bootstrap instance ID." }
    if ($resolvedBootstrapAmiId -notmatch '^ami-[0-9a-f]+$') { throw "EC2 did not resolve the Canonical bootstrap image reference." }
    $awsCommonArguments = @(Get-AwsCommonArguments)
    & $script:aws ec2 wait instance-running --instance-ids $instanceId @awsCommonArguments
    if ($LASTEXITCODE -ne 0) { throw "Bootstrap instance did not reach running state." }

    $ssmOnline = $false
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        $information = Invoke-AwsJson @("ssm", "describe-instance-information", "--filters", "Key=InstanceIds,Values=$instanceId")
        if (@($information.InstanceInformationList).Count -eq 1 -and $information.InstanceInformationList[0].PingStatus -eq "Online") {
            $ssmOnline = $true
            break
        }
        Start-Sleep -Seconds 10
    }
    if (-not $ssmOnline) { throw "Bootstrap instance did not become SSM Online." }

    $secretArnJson = [ordered]@{}
    foreach ($consumer in $expectedConsumers) { $secretArnJson[$consumer] = [string]$target.runtime_database_secrets.$consumer }
    $secretArnBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($secretArnJson | ConvertTo-Json -Compress)))
    $remoteRoot = "/var/lib/idea2strategy/database-bootstrap/$head"
    $archiveRemote = "$remoteRoot/flyway-ci-bundle.tar.gz"
    $scriptRemote = "$remoteRoot/development-database-bootstrap.sh"
    $policySeedRemote = "$remoteRoot/policy-seed.sql"
    $scoringSeedRemote = "$remoteRoot/scoring-template-seed.sql"
    $command = @(
        "set -Eeuo pipefail; set +x",
        'retry() { for attempt in 1 2 3 4 5; do "$@" && return 0; sleep $((attempt * 5)); done; return 1; }',
        'for attempt in $(seq 1 180); do if [ -f /var/lib/idea2strategy-database-bootstrap-ready ]; then break; fi; if [ -f /var/lib/idea2strategy-database-bootstrap-provisioning-failed ]; then cat /var/lib/idea2strategy-database-bootstrap-provisioning-failed >&2; exit 70; fi; sleep 5; done; if [ ! -f /var/lib/idea2strategy-database-bootstrap-ready ]; then echo "Database bootstrap host readiness timed out." >&2; exit 70; fi',
        "retry docker pull $(ConvertTo-BashLiteral $awsCliImage) >/dev/null",
        "install -d -m 0700 $(ConvertTo-BashLiteral $remoteRoot)",
        "retry docker run --rm --network host --volume $(ConvertTo-BashLiteral "${remoteRoot}:${remoteRoot}") --env AWS_REGION=$(ConvertTo-BashLiteral $Region) --env AWS_DEFAULT_REGION=$(ConvertTo-BashLiteral $Region) $(ConvertTo-BashLiteral $awsCliImage) s3api get-object --bucket $(ConvertTo-BashLiteral ([string]$target.artifact_bucket)) --key $(ConvertTo-BashLiteral $archiveKey) --version-id $(ConvertTo-BashLiteral ([string]$archiveUpload.VersionId)) $(ConvertTo-BashLiteral $archiveRemote) >/dev/null",
        "retry docker run --rm --network host --volume $(ConvertTo-BashLiteral "${remoteRoot}:${remoteRoot}") --env AWS_REGION=$(ConvertTo-BashLiteral $Region) --env AWS_DEFAULT_REGION=$(ConvertTo-BashLiteral $Region) $(ConvertTo-BashLiteral $awsCliImage) s3api get-object --bucket $(ConvertTo-BashLiteral ([string]$target.artifact_bucket)) --key $(ConvertTo-BashLiteral $hostScriptKey) --version-id $(ConvertTo-BashLiteral ([string]$scriptUpload.VersionId)) $(ConvertTo-BashLiteral $scriptRemote) >/dev/null",
        "retry docker run --rm --network host --volume $(ConvertTo-BashLiteral "${remoteRoot}:${remoteRoot}") --env AWS_REGION=$(ConvertTo-BashLiteral $Region) --env AWS_DEFAULT_REGION=$(ConvertTo-BashLiteral $Region) $(ConvertTo-BashLiteral $awsCliImage) s3api get-object --bucket $(ConvertTo-BashLiteral ([string]$target.artifact_bucket)) --key $(ConvertTo-BashLiteral $policySeedKey) --version-id $(ConvertTo-BashLiteral ([string]$policySeedUpload.VersionId)) $(ConvertTo-BashLiteral $policySeedRemote) >/dev/null",
        "retry docker run --rm --network host --volume $(ConvertTo-BashLiteral "${remoteRoot}:${remoteRoot}") --env AWS_REGION=$(ConvertTo-BashLiteral $Region) --env AWS_DEFAULT_REGION=$(ConvertTo-BashLiteral $Region) $(ConvertTo-BashLiteral $awsCliImage) s3api get-object --bucket $(ConvertTo-BashLiteral ([string]$target.artifact_bucket)) --key $(ConvertTo-BashLiteral $scoringSeedKey) --version-id $(ConvertTo-BashLiteral ([string]$scoringSeedUpload.VersionId)) $(ConvertTo-BashLiteral $scoringSeedRemote) >/dev/null",
        "printf '%s  %s\n' $(ConvertTo-BashLiteral $hostScriptDigest) $(ConvertTo-BashLiteral $scriptRemote) | sha256sum --check --status",
        "chmod 0700 $(ConvertTo-BashLiteral $scriptRemote)",
        "$(ConvertTo-BashLiteral $scriptRemote) --archive $(ConvertTo-BashLiteral $archiveRemote) --archive-sha256 $(ConvertTo-BashLiteral $archiveDigest) --bundle-sha256 $(ConvertTo-BashLiteral $bundleDigest) --expected-migration-count $(ConvertTo-BashLiteral ([string]$expectedMigrationCount)) --database-host $(ConvertTo-BashLiteral ([string]$target.database_host)) --database-name $(ConvertTo-BashLiteral ([string]$target.database_name)) --database-port $(ConvertTo-BashLiteral ([string]$target.database_port)) --master-secret-arn $(ConvertTo-BashLiteral ([string]$target.master_secret_arn)) --policy-seed-sql $(ConvertTo-BashLiteral $policySeedRemote) --policy-seed-sha256 $(ConvertTo-BashLiteral $PolicySeedSha256) --scoring-seed-sql $(ConvertTo-BashLiteral $scoringSeedRemote) --scoring-seed-sha256 $(ConvertTo-BashLiteral $ScoringSeedSha256) --region $(ConvertTo-BashLiteral $Region) --root-sha $(ConvertTo-BashLiteral $head) --runtime-secret-arns-base64 $(ConvertTo-BashLiteral $secretArnBase64) --work-directory $(ConvertTo-BashLiteral "$remoteRoot/work") --artifact-bucket $(ConvertTo-BashLiteral ([string]$target.artifact_bucket))"
    )
    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($command -join "`n")))
    $commandParametersPath = Join-Path $temporaryRoot "ssm-command-parameters.json"
    Write-Utf8NoBomFile $commandParametersPath (@{ commands = @("printf '%s' '$encodedCommand' | base64 -d | bash") } | ConvertTo-Json -Depth 5)
    $sent = Invoke-AwsJson @("ssm", "send-command", "--instance-ids", $instanceId, "--document-name", "AWS-RunShellScript", "--comment", "Idea2Strategy exact database bootstrap $head", "--parameters", "file://$commandParametersPath", "--timeout-seconds", "1800")
    $commandId = [string]$sent.Command.CommandId
    # AWS-RunShellScript emits only a credential-free JSON receipt on stdout.
    # The AWS CLI command-executed waiter stops after about 100 seconds, which is
    # shorter than this command's reviewed 30-minute timeout. Poll only status
    # metadata until the exact invocation reaches a terminal state instead.
    $commandDeadline = [DateTimeOffset]::UtcNow.AddMinutes(31)
    while ($true) {
        $awsJsonArguments = @(Get-AwsCommonArguments -Json)
        $statusOutput = & $script:aws ssm get-command-invocation --command-id $commandId --instance-id $instanceId `
            --query '{Status:Status,StatusDetails:StatusDetails}' @awsJsonArguments 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace(($statusOutput -join "`n"))) {
            $statusMetadata = (($statusOutput -join "`n") | ConvertFrom-Json)
            if ([string]$statusMetadata.Status -eq "Success") { break }
            if ([string]$statusMetadata.Status -in @("Cancelled", "Failed", "TimedOut", "Cancelling")) {
                $failedInvocation = Invoke-AwsJson @("ssm", "get-command-invocation", "--command-id", $commandId, "--instance-id", $instanceId)
                $failureDetail = Get-SanitizedSsmFailure $failedInvocation
                throw "Database bootstrap SSM command failed with status '$([string]$statusMetadata.Status)'. CommandId '$commandId'. $failureDetail"
            }
        }
        if ([DateTimeOffset]::UtcNow -ge $commandDeadline) {
            throw "Database bootstrap SSM command exceeded its reviewed 30-minute timeout."
        }
        Start-Sleep -Seconds 5
    }
    $invocation = Invoke-AwsJson @("ssm", "get-command-invocation", "--command-id", $commandId, "--instance-id", $instanceId)
    if ($invocation.Status -ne "Success") {
        $failureDetail = Get-SanitizedSsmFailure $invocation
        throw "Database bootstrap SSM command failed with status '$($invocation.Status)'. CommandId '$commandId'. $failureDetail"
    }
    $receipt = [string]$invocation.StandardOutputContent | ConvertFrom-Json
    if ($receipt.status -ne "passed" -or $receipt.root_sha -cne $head -or $receipt.bundle_sha256 -cne $bundleDigest -or
        $receipt.policy_seed_sha256 -cne $PolicySeedSha256 -or $receipt.scoring_seed_sha256 -cne $ScoringSeedSha256 -or
        [string]$receipt.database_name -cne $RuntimeDatabaseName -or
        @($receipt.scoring_versions).Count -ne $expectedScoringVersionCount -or [int]$receipt.migrations -ne $expectedMigrationCount -or
        [int]$receipt.tables -lt 1 -or
        [int]$receipt.instrument_count -lt 500 -or
        [string]$receipt.rights_expires_at -notmatch '^\d{4}-\d{2}-\d{2}T' -or
        $null -eq $receipt.trading_runtime_artifacts -or
        [int]$receipt.policy_row_counts.fee -lt 1 -or [int]$receipt.policy_row_counts.buffer -lt 1 -or
        [int]$receipt.policy_row_counts.execution -lt 1) {
        throw "Database bootstrap receipt did not match the exact release candidate."
    }
    $receipt | Add-Member -NotePropertyName artifact_fingerprint -NotePropertyValue $artifactFingerprint -Force
    $receiptPath = Join-Path $temporaryRoot "receipt.json"
    Write-Utf8NoBomFile $receiptPath ($receipt | ConvertTo-Json -Depth 8)
    $exactReceiptUpload = Invoke-AwsJson @("s3api", "put-object", "--bucket", [string]$target.artifact_bucket, "--key", $receiptKey, "--body", $receiptPath)
    $artifactReceiptUpload = Invoke-AwsJson @("s3api", "put-object", "--bucket", [string]$target.artifact_bucket, "--key", $artifactReceiptKey, "--body", $receiptPath)
    if ([string]::IsNullOrWhiteSpace([string]$exactReceiptUpload.VersionId) -or
        [string]::IsNullOrWhiteSpace([string]$artifactReceiptUpload.VersionId)) {
        throw "Database bootstrap receipts must be stored as versioned S3 objects."
    }

    $result = [ordered]@{
        status = "passed"
        root_sha = $head
        bundle_sha256 = $bundleDigest
        policy_seed_sha256 = $PolicySeedSha256
        scoring_seed_sha256 = $ScoringSeedSha256
        database_name = $RuntimeDatabaseName
        artifact_fingerprint = $artifactFingerprint
        bootstrap_ami_id = $resolvedBootstrapAmiId
        instance_id = $instanceId
        command_id = $commandId
        receipt_key = $receiptKey
        artifact_receipt_key = $artifactReceiptKey
        credential_values_printed = $false
    }
}
catch {
    $primaryError = $_
}
finally {
    if ($policyAttached) {
        # DeleteRolePolicy: revoke master-secret access before instance cleanup.
        $awsCommonArguments = @(Get-AwsCommonArguments)
        & $script:aws iam delete-role-policy --role-name ([string]$target.role_name) --policy-name $inlinePolicyName @awsCommonArguments 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { $cleanupErrors.Add("transient IAM policy removal") }
    }
    if ($instanceId -match '^i-[0-9a-f]+$') {
        # TerminateInstances: only the exact ID returned by this invocation.
        $awsJsonArguments = @(Get-AwsCommonArguments -Json)
        & $script:aws ec2 terminate-instances --instance-ids $instanceId @awsJsonArguments 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { $cleanupErrors.Add("exact EC2 termination request") }
        $awsCommonArguments = @(Get-AwsCommonArguments)
        & $script:aws ec2 wait instance-terminated --instance-ids $instanceId @awsCommonArguments 2>$null
        if ($LASTEXITCODE -ne 0) { $cleanupErrors.Add("exact EC2 termination waiter") }
    }
    if ($cleanupErrors.Count -gt 0) {
        $cleanupFailure = "Database bootstrap cleanup requires immediate operator attention: $($cleanupErrors -join ', ')."
    }
}

if ($null -ne $primaryError) {
    if (-not [string]::IsNullOrWhiteSpace($cleanupFailure)) {
        throw "$($primaryError.Exception.Message) Cleanup also failed: $cleanupFailure"
    }
    throw $primaryError
}
if (-not [string]::IsNullOrWhiteSpace($cleanupFailure)) { throw $cleanupFailure }

$result | ConvertTo-Json
