[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
    [string]$AwsProfile = "idea2strategy-terraform",
    [string]$Region = "ap-northeast-2",
    [string]$ExpectedAwsAccountId = "",
    [string]$TerraformRoot = "infra/terraform/environments/development",
    [string]$InstanceType = "t3.small",
    [string]$PolicySeedSqlPath = "",
    [string]$PolicySeedSha256 = "",
    [string]$ScoringSeedSqlPath = "",
    [string]$ScoringSeedSha256 = "",
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

function ConvertTo-BashLiteral([string]$Value) {
    if ($Value.Contains("'")) { throw "Bootstrap target contains an unsupported quote character." }
    return "'$Value'"
}

function Write-Utf8NoBomFile([string]$LiteralPath, [string]$Content) {
    [IO.File]::WriteAllText($LiteralPath, $Content, [Text.UTF8Encoding]::new($false))
}

if ($Region -ne "ap-northeast-2") { throw "The Development database bootstrap is restricted to ap-northeast-2." }
if ($InstanceType -notmatch '^t3\.(micro|small|medium)$') { throw "Use a bounded x86 t3 instance for the amd64-only Flyway image." }
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

$terraform = Get-Executable "terraform"
$awsFallback = ""
if (-not [string]::IsNullOrWhiteSpace([string]$env:ProgramFiles)) {
    $awsFallback = Join-Path $env:ProgramFiles "Amazon/AWSCLIV2/aws.exe"
}
$script:aws = Get-Executable "aws" $awsFallback
$terraformPath = Join-Path $root $TerraformRoot
$targetText = (& $terraform "-chdir=$terraformPath" output -json database_bootstrap 2>$null) -join "`n"
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($targetText)) {
    throw "Apply the reviewed Terraform secret-metadata/bootstrap-boundary plan before running this procedure."
}
$target = $targetText | ConvertFrom-Json

$caller = Invoke-AwsJson @("sts", "get-caller-identity")
if ([string]::IsNullOrWhiteSpace($ExpectedAwsAccountId) -or $ExpectedAwsAccountId -notmatch '^\d{12}$') {
    throw "ExpectedAwsAccountId must be the reviewed 12-digit Development account."
}
if ([string]$caller.Account -cne $ExpectedAwsAccountId) { throw "AWS account mismatch." }
$images = Invoke-AwsJson @(
    "ec2", "describe-images",
    "--owners", "099720109477",
    "--filters",
    "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*",
    "Name=architecture,Values=x86_64",
    "Name=virtualization-type,Values=hvm",
    "Name=state,Values=available"
)
$bootstrapImage = @($images.Images | Sort-Object CreationDate -Descending | Select-Object -First 1)
if ($bootstrapImage.Count -ne 1 -or [string]$bootstrapImage[0].ImageId -notmatch '^ami-[0-9a-f]+$') {
    throw "Unable to pin one current Canonical Ubuntu 24.04 amd64 bootstrap AMI."
}
$bootstrapAmiId = [string]$bootstrapImage[0].ImageId

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
    -ScoringSeedSha256 $ScoringSeedSha256

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
    artifact_fingerprint = $artifactFingerprint
    region = $Region
    instance_type = $InstanceType
    ami_id = $bootstrapAmiId
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
                Sid = "WriteOnlyRuntimeCredentialVersions"
                Effect = "Allow"
                Action = @("secretsmanager:PutSecretValue", "secretsmanager:DescribeSecret")
                Resource = @($secretResources | Select-Object -Skip 1)
            }
        )
    }
    $policyPath = Join-Path $temporaryRoot "transient-secret-policy.json"
    Write-Utf8NoBomFile $policyPath ($policyDocument | ConvertTo-Json -Depth 8)
    # PutRolePolicy: this exact secret policy exists only for the command window.
    $null = Invoke-AwsJson @("iam", "put-role-policy", "--role-name", [string]$target.role_name, "--policy-name", $inlinePolicyName, "--policy-document", "file://$policyPath")
    $policyAttached = $true

    $userDataPath = Join-Path $temporaryRoot "bootstrap-user-data.sh"
    $userData = @'
#!/usr/bin/env bash
set -Eeuo pipefail
set +x
export DEBIAN_FRONTEND=noninteractive
systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service || true
apt-get update -qq
apt-get install -y -qq docker.io jq postgresql-client python3 openssl ca-certificates
systemctl enable --now docker
touch /var/lib/idea2strategy-database-bootstrap-ready
'@
    Write-Utf8NoBomFile $userDataPath $userData

    $existing = Invoke-AwsJson @("ec2", "describe-instances", "--filters", "Name=tag:Purpose,Values=idea2strategy-development-database-bootstrap", "Name=instance-state-name,Values=pending,running,stopping,stopped")
    $existingInstances = @($existing.Reservations | ForEach-Object { $_.Instances })
    if ($existingInstances.Count -ne 0) { throw "Another database bootstrap instance is still present." }

    $tagSpecification = "ResourceType=instance,Tags=[{Key=Name,Value=idea2strategy-dev-database-bootstrap},{Key=Project,Value=idea2strategy},{Key=Environment,Value=dev},{Key=Purpose,Value=idea2strategy-development-database-bootstrap},{Key=SourceCommit,Value=$head}]"
    $launch = Invoke-AwsJson @(
        "ec2", "run-instances",
        "--image-id", $bootstrapAmiId,
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
    if ($instanceId -notmatch '^i-[0-9a-f]+$') { throw "EC2 did not return one exact bootstrap instance ID." }
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
        "while [ ! -f /var/lib/idea2strategy-database-bootstrap-ready ]; do sleep 5; done",
        "install -d -m 0700 $(ConvertTo-BashLiteral $remoteRoot)",
        "docker run --rm --network host --volume $(ConvertTo-BashLiteral "${remoteRoot}:${remoteRoot}") --env AWS_REGION=$(ConvertTo-BashLiteral $Region) --env AWS_DEFAULT_REGION=$(ConvertTo-BashLiteral $Region) $(ConvertTo-BashLiteral $awsCliImage) s3api get-object --bucket $(ConvertTo-BashLiteral ([string]$target.artifact_bucket)) --key $(ConvertTo-BashLiteral $archiveKey) --version-id $(ConvertTo-BashLiteral ([string]$archiveUpload.VersionId)) $(ConvertTo-BashLiteral $archiveRemote) >/dev/null",
        "docker run --rm --network host --volume $(ConvertTo-BashLiteral "${remoteRoot}:${remoteRoot}") --env AWS_REGION=$(ConvertTo-BashLiteral $Region) --env AWS_DEFAULT_REGION=$(ConvertTo-BashLiteral $Region) $(ConvertTo-BashLiteral $awsCliImage) s3api get-object --bucket $(ConvertTo-BashLiteral ([string]$target.artifact_bucket)) --key $(ConvertTo-BashLiteral $hostScriptKey) --version-id $(ConvertTo-BashLiteral ([string]$scriptUpload.VersionId)) $(ConvertTo-BashLiteral $scriptRemote) >/dev/null",
        "docker run --rm --network host --volume $(ConvertTo-BashLiteral "${remoteRoot}:${remoteRoot}") --env AWS_REGION=$(ConvertTo-BashLiteral $Region) --env AWS_DEFAULT_REGION=$(ConvertTo-BashLiteral $Region) $(ConvertTo-BashLiteral $awsCliImage) s3api get-object --bucket $(ConvertTo-BashLiteral ([string]$target.artifact_bucket)) --key $(ConvertTo-BashLiteral $policySeedKey) --version-id $(ConvertTo-BashLiteral ([string]$policySeedUpload.VersionId)) $(ConvertTo-BashLiteral $policySeedRemote) >/dev/null",
        "docker run --rm --network host --volume $(ConvertTo-BashLiteral "${remoteRoot}:${remoteRoot}") --env AWS_REGION=$(ConvertTo-BashLiteral $Region) --env AWS_DEFAULT_REGION=$(ConvertTo-BashLiteral $Region) $(ConvertTo-BashLiteral $awsCliImage) s3api get-object --bucket $(ConvertTo-BashLiteral ([string]$target.artifact_bucket)) --key $(ConvertTo-BashLiteral $scoringSeedKey) --version-id $(ConvertTo-BashLiteral ([string]$scoringSeedUpload.VersionId)) $(ConvertTo-BashLiteral $scoringSeedRemote) >/dev/null",
        "printf '%s  %s\n' $(ConvertTo-BashLiteral $hostScriptDigest) $(ConvertTo-BashLiteral $scriptRemote) | sha256sum --check --status",
        "chmod 0700 $(ConvertTo-BashLiteral $scriptRemote)",
        "$(ConvertTo-BashLiteral $scriptRemote) --archive $(ConvertTo-BashLiteral $archiveRemote) --archive-sha256 $(ConvertTo-BashLiteral $archiveDigest) --bundle-sha256 $(ConvertTo-BashLiteral $bundleDigest) --expected-migration-count $(ConvertTo-BashLiteral ([string]$expectedMigrationCount)) --database-host $(ConvertTo-BashLiteral ([string]$target.database_host)) --database-name $(ConvertTo-BashLiteral ([string]$target.database_name)) --database-port $(ConvertTo-BashLiteral ([string]$target.database_port)) --master-secret-arn $(ConvertTo-BashLiteral ([string]$target.master_secret_arn)) --policy-seed-sql $(ConvertTo-BashLiteral $policySeedRemote) --policy-seed-sha256 $(ConvertTo-BashLiteral $PolicySeedSha256) --scoring-seed-sql $(ConvertTo-BashLiteral $scoringSeedRemote) --scoring-seed-sha256 $(ConvertTo-BashLiteral $ScoringSeedSha256) --region $(ConvertTo-BashLiteral $Region) --root-sha $(ConvertTo-BashLiteral $head) --runtime-secret-arns-base64 $(ConvertTo-BashLiteral $secretArnBase64) --work-directory $(ConvertTo-BashLiteral "$remoteRoot/work")"
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
                throw "Database bootstrap SSM command failed with status '$([string]$statusMetadata.Status)'."
            }
        }
        if ([DateTimeOffset]::UtcNow -ge $commandDeadline) {
            throw "Database bootstrap SSM command exceeded its reviewed 30-minute timeout."
        }
        Start-Sleep -Seconds 5
    }
    $invocation = Invoke-AwsJson @("ssm", "get-command-invocation", "--command-id", $commandId, "--instance-id", $instanceId)
    if ($invocation.Status -ne "Success") { throw "Database bootstrap SSM command failed with status '$($invocation.Status)'." }
    $receipt = [string]$invocation.StandardOutputContent | ConvertFrom-Json
    if ($receipt.status -ne "passed" -or $receipt.root_sha -cne $head -or $receipt.bundle_sha256 -cne $bundleDigest -or
        $receipt.policy_seed_sha256 -cne $PolicySeedSha256 -or $receipt.scoring_seed_sha256 -cne $ScoringSeedSha256 -or
        @($receipt.scoring_versions).Count -ne 4 -or [int]$receipt.migrations -ne $expectedMigrationCount -or
        [int]$receipt.tables -ne 179 -or
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
        artifact_fingerprint = $artifactFingerprint
        instance_id = $instanceId
        command_id = $commandId
        receipt_key = $receiptKey
        artifact_receipt_key = $artifactReceiptKey
        credential_values_printed = $false
    }
}
finally {
    $cleanupErrors = [Collections.Generic.List[string]]::new()
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
        throw "Database bootstrap cleanup requires immediate operator attention: $($cleanupErrors -join ', ')."
    }
}

$result | ConvertTo-Json
