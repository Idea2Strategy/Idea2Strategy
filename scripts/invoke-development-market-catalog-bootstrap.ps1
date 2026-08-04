[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = "High")]
param(
    [string]$AwsProfile = "idea2strategy-terraform",
    [string]$Region = "ap-northeast-2",
    [string]$ExpectedAwsAccountId = "",
    [string]$TerraformRoot = "infra/terraform/environments/development",
    [ValidateSet("DryRun", "Apply")]
    [string]$Phase = "DryRun",
    [string]$PipelineImageDigest = "",
    [string]$ReviewedDryRunSourceDigest = "",
    [string]$ReviewedDryRunReceiptVersionId = "",
    [string]$ReviewedDryRunReceiptSha256 = "",
    [int]$ExpectedObjectCount = 768,
    [int]$ExpectedManifestCount = 96,
    [string]$InstanceType = "t4g.small",
    [switch]$Execute
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$pipelineSourceCommit = "ac3cecf5fcd1918d6902fbbaa38ce347af56c23b"
$inlinePolicyName = "idea2strategy-development-market-catalog-bootstrap-transient"
$purposeTag = "idea2strategy-development-market-catalog-bootstrap"
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
    return Invoke-ExternalJson $script:aws (@($Arguments) + @("--profile", $AwsProfile, "--region", $Region, "--output", "json"))
}

function Get-TerraformOutput([string]$Name) {
    # All target discovery is credential-free metadata from: terraform output -json <name>
    $text = (& $script:terraform "-chdir=$script:terraformPath" output -json $Name 2>$null) -join "`n"
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($text)) {
        throw "Apply the reviewed Development foundation before running the market catalog bootstrap."
    }
    return $text | ConvertFrom-Json
}

function ConvertTo-BashLiteral([string]$Value) {
    if ($Value.Contains("'")) { throw "Bootstrap target contains an unsupported quote character." }
    return "'$Value'"
}

function Write-Utf8NoBomFile([string]$LiteralPath, [string]$Content) {
    [IO.File]::WriteAllText($LiteralPath, $Content, [Text.UTF8Encoding]::new($false))
}

if ($Region -ne "ap-northeast-2") { throw "The Development market catalog bootstrap is restricted to ap-northeast-2." }
if ($InstanceType -notmatch '^t4g\.(micro|small|medium)$') { throw "Use a bounded ARM64 t4g instance for the one-shot pipeline image." }
if ($PipelineImageDigest -notmatch '^sha256:[0-9a-f]{64}$') { throw "PipelineImageDigest must be an exact lowercase sha256 digest." }
if ($ExpectedObjectCount -ne 768 -or $ExpectedManifestCount -ne 96) {
    throw "Development bootstrap gates are fixed at 768 objects and 96 manifests."
}
if ($Phase -eq "Apply") {
    if ($ReviewedDryRunSourceDigest -notmatch '^[0-9a-f]{64}$') { throw "Apply requires the reviewed dry-run source digest." }
    if ([string]::IsNullOrWhiteSpace($ReviewedDryRunReceiptVersionId)) { throw "Apply requires the exact versioned dry-run receipt ID." }
    if ($ReviewedDryRunReceiptSha256 -notmatch '^[0-9a-f]{64}$') { throw "Apply requires the reviewed dry-run receipt SHA-256." }
}

$head = (& git -C $root rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $head -notmatch '^[0-9a-f]{40}$') { throw "Unable to identify the exact root commit." }
$trackedStatus = (& git -C $root status --porcelain=v1 --untracked-files=no) -join "`n"
if (-not [string]::IsNullOrWhiteSpace($trackedStatus)) { throw "Market catalog bootstrap requires a checkout with no tracked changes." }
$gitlinkLine = ((& git -C $root ls-tree HEAD data-pipeline) -join "`n").Trim()
if ($LASTEXITCODE -ne 0 -or $gitlinkLine -notmatch "^160000 commit $pipelineSourceCommit\s+data-pipeline$") {
    throw "Root must pin the reviewed data-pipeline provider commit $pipelineSourceCommit."
}

$hostScriptPath = Join-Path $root "scripts/aws/development-market-catalog-bootstrap.sh"
if (-not (Test-Path -LiteralPath $hostScriptPath -PathType Leaf)) { throw "The host bootstrap script is missing." }
$hostScriptSha256 = (Get-FileHash -LiteralPath $hostScriptPath -Algorithm SHA256).Hash.ToLowerInvariant()

$script:terraform = Get-Executable "terraform"
$script:aws = Get-Executable "aws" (Join-Path $env:ProgramFiles "Amazon/AWSCLIV2/aws.exe")
$script:terraformPath = Join-Path $root $TerraformRoot
$target = Get-TerraformOutput "database_bootstrap"
$marketLoaderSecretArn = [string](Get-TerraformOutput "market_loader_secret_arn")
$marketDataBucket = [string](Get-TerraformOutput "market_data_bucket")
$pipelineSecretArn = [string]$target.runtime_database_secrets.pipeline

$caller = Invoke-AwsJson @("sts", "get-caller-identity")
if ([string]::IsNullOrWhiteSpace($ExpectedAwsAccountId) -or $ExpectedAwsAccountId -notmatch '^\d{12}$') {
    throw "ExpectedAwsAccountId must be the reviewed 12-digit Development account."
}
if ([string]$caller.Account -cne $ExpectedAwsAccountId) { throw "AWS account mismatch." }

# ECR is owned by the isolated artifact-foundation state, not the Development
# runtime state. Discover the one fixed repository from the already verified
# account instead of coupling this one-shot operation to another Terraform state.
$repositoryName = "idea2strategy-dev/pipeline-worker"
$repository = Invoke-AwsJson @("ecr", "describe-repositories", "--repository-names", $repositoryName)
if (@($repository.repositories).Count -ne 1) { throw "The pipeline-worker ECR repository was not found." }
$pipelineRepository = [string]$repository.repositories[0].repositoryUri
$repositoryArn = [string]$repository.repositories[0].repositoryArn

foreach ($secretArn in @($marketLoaderSecretArn, $pipelineSecretArn)) {
    if ($secretArn -notmatch '^arn:aws:secretsmanager:') { throw "Terraform returned a malformed database secret ARN." }
    $secretDescription = Invoke-AwsJson @("secretsmanager", "describe-secret", "--secret-id", $secretArn)
    $currentVersions = @($secretDescription.VersionIdsToStages.PSObject.Properties | Where-Object { @($_.Value) -contains "AWSCURRENT" })
    if ($currentVersions.Count -ne 1) { throw "Each database secret must expose exactly one AWSCURRENT version." }
}
if ($marketDataBucket -notmatch '^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$') { throw "Terraform returned a malformed market-data bucket." }
if ($pipelineRepository -notmatch '^\d{12}\.dkr\.ecr\.ap-northeast-2\.amazonaws\.com/(.+)$') {
    throw "AWS returned a malformed pipeline-worker ECR repository URL."
}
if ($Matches[1] -cne $repositoryName) { throw "AWS returned an unexpected pipeline-worker ECR repository." }
$pipelineImage = "$pipelineRepository@$PipelineImageDigest"

if (-not $pipelineRepository.StartsWith("$ExpectedAwsAccountId.dkr.ecr.")) { throw "ECR repository belongs to a different AWS account." }

$image = Invoke-AwsJson @("ecr", "describe-images", "--repository-name", $repositoryName, "--image-ids", "imageDigest=$PipelineImageDigest")
if (@($image.imageDetails).Count -ne 1 -or [string]$image.imageDetails[0].imageDigest -cne $PipelineImageDigest) {
    throw "The exact immutable pipeline-worker image digest is not present in ECR."
}
$versioning = Invoke-AwsJson @("s3api", "get-bucket-versioning", "--bucket", $marketDataBucket)
if ([string]$versioning.Status -cne "Enabled") { throw "Market-data evidence bucket must have versioning enabled." }

$images = Invoke-AwsJson @(
    "ec2", "describe-images",
    "--owners", "099720109477",
    "--filters",
    "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*",
    "Name=architecture,Values=arm64",
    "Name=virtualization-type,Values=hvm",
    "Name=state,Values=available"
)
$bootstrapImage = @($images.Images | Sort-Object CreationDate -Descending | Select-Object -First 1)
if ($bootstrapImage.Count -ne 1 -or [string]$bootstrapImage[0].ImageId -notmatch '^ami-[0-9a-f]+$') {
    throw "Unable to pin one current Canonical Ubuntu 24.04 ARM64 bootstrap AMI."
}
$bootstrapAmiId = [string]$bootstrapImage[0].ImageId

$imageDigestPart = $PipelineImageDigest.Substring(7)
$artifactPrefix = "market-catalog-bootstrap/$head/$pipelineSourceCommit/$imageDigestPart"
$hostScriptKey = "$artifactPrefix/development-market-catalog-bootstrap.sh"
$dryRunReceiptKey = "$artifactPrefix/dry-run-receipt.json"
$applyReceiptKey = "$artifactPrefix/apply-receipt.json"
$temporaryRoot = Join-Path $root ".harness/local/tmp/market-catalog-bootstrap/$head"
if (-not (Test-Path -LiteralPath $temporaryRoot -PathType Container)) {
    New-Item -ItemType Directory -Path $temporaryRoot -Force | Out-Null
}

if ($Phase -eq "Apply") {
    $reviewedReceiptPath = Join-Path $temporaryRoot "reviewed-dry-run-receipt.json"
    $null = Invoke-AwsJson @(
        "s3api", "get-object", "--bucket", $marketDataBucket, "--key", $dryRunReceiptKey,
        "--version-id", $ReviewedDryRunReceiptVersionId, $reviewedReceiptPath
    )
    $actualReceiptSha256 = (Get-FileHash -LiteralPath $reviewedReceiptPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualReceiptSha256 -cne $ReviewedDryRunReceiptSha256) { throw "Reviewed dry-run receipt SHA-256 mismatch." }
    $reviewedReceipt = Get-Content -LiteralPath $reviewedReceiptPath -Raw | ConvertFrom-Json
    if ($reviewedReceipt.status -cne "passed" -or $reviewedReceipt.phase -cne "DryRun" -or
        $reviewedReceipt.root_sha -cne $head -or $reviewedReceipt.pipeline_source_commit -cne $pipelineSourceCommit -or
        $reviewedReceipt.pipeline_image -cne $pipelineImage -or $reviewedReceipt.bucket -cne $marketDataBucket -or
        $reviewedReceipt.dry_run.status -cne "DRY_RUN" -or
        $reviewedReceipt.dry_run.source_digest -cne $ReviewedDryRunSourceDigest -or
        [int]$reviewedReceipt.dry_run.verified_object_count -ne $ExpectedObjectCount -or
        [int]$reviewedReceipt.dry_run.manifest_count -ne $ExpectedManifestCount) {
        throw "Reviewed dry-run receipt does not match the exact root, image, bucket, digest, and count gates."
    }
}

$safePlan = [ordered]@{
    status = if ($Execute) { "ready-to-execute" } else { "validated-plan" }
    phase = $Phase
    root_sha = $head
    pipeline_source_commit = $pipelineSourceCommit
    pipeline_image = $pipelineImage
    region = $Region
    instance_type = $InstanceType
    ami_id = $bootstrapAmiId
    bucket = $marketDataBucket
    expected_object_count = $ExpectedObjectCount
    expected_manifest_count = $ExpectedManifestCount
    artifact_prefix = $artifactPrefix
    secret_values_in_argv = $false
}

if (-not $Execute -or -not $PSCmdlet.ShouldProcess(
    "Development legacy market catalog and versioned evidence bucket",
    "Run $Phase on an ephemeral ARM64 SSM instance using an immutable pipeline image")) {
    $safePlan | ConvertTo-Json -Depth 5
    return
}

$instanceId = ""
$policyAttached = $false
try {
    $scriptUpload = Invoke-AwsJson @("s3api", "put-object", "--bucket", $marketDataBucket, "--key", $hostScriptKey, "--body", $hostScriptPath)
    if ([string]::IsNullOrWhiteSpace([string]$scriptUpload.VersionId)) { throw "Host script must be stored as a versioned S3 object." }

    $policyDocument = [ordered]@{
        Version = "2012-10-17"
        Statement = @(
            [ordered]@{
                Sid = "ReadExactDatabaseCredentials"
                Effect = "Allow"
                Action = @("secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret")
                Resource = @($marketLoaderSecretArn, $pipelineSecretArn)
            },
            [ordered]@{
                Sid = "AuthenticateToEcr"
                Effect = "Allow"
                Action = @("ecr:GetAuthorizationToken")
                Resource = "*"
            },
            [ordered]@{
                Sid = "PullExactPipelineImage"
                Effect = "Allow"
                Action = @("ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer")
                Resource = $repositoryArn
            },
            [ordered]@{
                Sid = "AuditVersionPinnedMarketObjects"
                Effect = "Allow"
                Action = @("s3:GetObject", "s3:GetObjectVersion", "s3:GetObjectAttributes")
                Resource = "arn:aws:s3:::$marketDataBucket/*"
            },
            [ordered]@{
                Sid = "ReadMarketBucketMetadata"
                Effect = "Allow"
                Action = @("s3:ListBucket", "s3:GetBucketLocation")
                Resource = "arn:aws:s3:::$marketDataBucket"
            }
        )
    }
    $policyPath = Join-Path $temporaryRoot "transient-policy.json"
    Write-Utf8NoBomFile $policyPath ($policyDocument | ConvertTo-Json -Depth 10)
    # PutRolePolicy exists only for the one-shot command window and contains no secret values.
    $null = Invoke-AwsJson @("iam", "put-role-policy", "--role-name", [string]$target.role_name, "--policy-name", $inlinePolicyName, "--policy-document", "file://$policyPath")
    $policyAttached = $true

    $userDataPath = Join-Path $temporaryRoot "user-data.sh"
    $userData = @'
#!/usr/bin/env bash
set -Eeuo pipefail
set +x
export DEBIAN_FRONTEND=noninteractive
systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service || true
apt-get update -qq
apt-get install -y -qq docker.io jq python3 ca-certificates
systemctl enable --now docker
touch /var/lib/idea2strategy-market-catalog-bootstrap-ready
'@
    Write-Utf8NoBomFile $userDataPath $userData

    $existing = Invoke-AwsJson @("ec2", "describe-instances", "--filters", "Name=tag:Purpose,Values=$purposeTag", "Name=instance-state-name,Values=pending,running,stopping,stopped")
    $existingInstances = @($existing.Reservations | ForEach-Object { $_.Instances })
    if ($existingInstances.Count -ne 0) { throw "Another market catalog bootstrap instance is still present." }

    $tagSpecification = "ResourceType=instance,Tags=[{Key=Name,Value=idea2strategy-dev-market-catalog-bootstrap},{Key=Project,Value=idea2strategy},{Key=Environment,Value=dev},{Key=Purpose,Value=$purposeTag},{Key=SourceCommit,Value=$head}]"
    $launch = Invoke-AwsJson @(
        "ec2", "run-instances", "--image-id", $bootstrapAmiId, "--instance-type", $InstanceType,
        "--iam-instance-profile", "Name=$([string]$target.instance_profile_name)",
        "--subnet-id", [string]$target.subnet_id, "--security-group-ids", [string]$target.security_group_id,
        "--associate-public-ip-address",
        "--metadata-options", "HttpTokens=required,HttpEndpoint=enabled,HttpPutResponseHopLimit=1",
        "--block-device-mappings", "DeviceName=/dev/sda1,Ebs={VolumeSize=16,VolumeType=gp3,Encrypted=true,DeleteOnTermination=true}",
        "--tag-specifications", $tagSpecification, "--user-data", "file://$userDataPath", "--count", "1"
    )
    $instanceId = [string]$launch.Instances[0].InstanceId
    if ($instanceId -notmatch '^i-[0-9a-f]+$') { throw "EC2 did not return one exact bootstrap instance ID." }
    & $script:aws ec2 wait instance-running --instance-ids $instanceId --profile $AwsProfile --region $Region
    if ($LASTEXITCODE -ne 0) { throw "Market catalog bootstrap instance did not reach running state." }

    $ssmOnline = $false
    for ($attempt = 0; $attempt -lt 60; $attempt++) {
        $information = Invoke-AwsJson @("ssm", "describe-instance-information", "--filters", "Key=InstanceIds,Values=$instanceId")
        if (@($information.InstanceInformationList).Count -eq 1 -and $information.InstanceInformationList[0].PingStatus -eq "Online") {
            $ssmOnline = $true
            break
        }
        Start-Sleep -Seconds 10
    }
    if (-not $ssmOnline) { throw "Market catalog bootstrap instance did not become SSM Online." }

    $remoteRoot = "/var/lib/idea2strategy/market-catalog-bootstrap/$head"
    $remoteScript = "$remoteRoot/development-market-catalog-bootstrap.sh"
    $hostPhase = if ($Phase -eq "DryRun") { "dry-run" } else { "apply" }
    $expectedSourceDigest = if ($Phase -eq "Apply") { $ReviewedDryRunSourceDigest } else { "" }
    $command = @(
        "set -Eeuo pipefail; set +x",
        "while [ ! -f /var/lib/idea2strategy-market-catalog-bootstrap-ready ]; do sleep 5; done",
        "install -d -m 0700 $(ConvertTo-BashLiteral $remoteRoot)",
        "docker run --rm --network host --volume $(ConvertTo-BashLiteral "${remoteRoot}:${remoteRoot}") --env AWS_REGION=$(ConvertTo-BashLiteral $Region) --env AWS_DEFAULT_REGION=$(ConvertTo-BashLiteral $Region) $(ConvertTo-BashLiteral $awsCliImage) s3api get-object --bucket $(ConvertTo-BashLiteral $marketDataBucket) --key $(ConvertTo-BashLiteral $hostScriptKey) --version-id $(ConvertTo-BashLiteral ([string]$scriptUpload.VersionId)) $(ConvertTo-BashLiteral $remoteScript) >/dev/null",
        "printf '%s  %s\n' $(ConvertTo-BashLiteral $hostScriptSha256) $(ConvertTo-BashLiteral $remoteScript) | sha256sum --check --status",
        "chmod 0700 $(ConvertTo-BashLiteral $remoteScript)",
        "$(ConvertTo-BashLiteral $remoteScript) --phase $(ConvertTo-BashLiteral $hostPhase) --pipeline-image $(ConvertTo-BashLiteral $pipelineImage) --pipeline-source-commit $(ConvertTo-BashLiteral $pipelineSourceCommit) --source-secret-arn $(ConvertTo-BashLiteral $marketLoaderSecretArn) --target-secret-arn $(ConvertTo-BashLiteral $pipelineSecretArn) --bucket $(ConvertTo-BashLiteral $marketDataBucket) --region $(ConvertTo-BashLiteral $Region) --root-sha $(ConvertTo-BashLiteral $head) --expected-object-count $(ConvertTo-BashLiteral ([string]$ExpectedObjectCount)) --expected-manifest-count $(ConvertTo-BashLiteral ([string]$ExpectedManifestCount)) --expected-source-digest $(ConvertTo-BashLiteral $expectedSourceDigest) --work-directory $(ConvertTo-BashLiteral "$remoteRoot/work")"
    )
    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($command -join "`n")))
    $parametersPath = Join-Path $temporaryRoot "ssm-command-parameters.json"
    Write-Utf8NoBomFile $parametersPath (@{ commands = @("printf '%s' '$encodedCommand' | base64 -d | bash") } | ConvertTo-Json -Depth 5)
    $sent = Invoke-AwsJson @("ssm", "send-command", "--instance-ids", $instanceId, "--document-name", "AWS-RunShellScript", "--comment", "Idea2Strategy exact market catalog $Phase $head", "--parameters", "file://$parametersPath", "--timeout-seconds", "3600")
    $commandId = [string]$sent.Command.CommandId
    & $script:aws ssm wait command-executed --command-id $commandId --instance-id $instanceId --profile $AwsProfile --region $Region
    if ($LASTEXITCODE -ne 0) {
        try {
            $failedInvocation = Invoke-AwsJson @("ssm", "get-command-invocation", "--command-id", $commandId, "--instance-id", $instanceId)
            $diagnostics = ([string]$failedInvocation.StandardErrorContent).Trim()
            if (-not [string]::IsNullOrWhiteSpace($diagnostics)) {
                Write-Warning "Sanitized bootstrap diagnostics:`n$diagnostics"
            }
        }
        catch {
            Write-Warning "The failed SSM invocation diagnostics could not be retrieved before cleanup."
        }
        throw "Market catalog SSM command did not succeed."
    }
    $invocation = Invoke-AwsJson @("ssm", "get-command-invocation", "--command-id", $commandId, "--instance-id", $instanceId)
    if ($invocation.Status -ne "Success") { throw "Market catalog SSM command failed with status '$($invocation.Status)'." }
    $receipt = [string]$invocation.StandardOutputContent | ConvertFrom-Json
    if ($receipt.status -cne "passed" -or $receipt.phase -cne $Phase -or $receipt.root_sha -cne $head -or
        $receipt.pipeline_source_commit -cne $pipelineSourceCommit -or $receipt.pipeline_image -cne $pipelineImage -or
        $receipt.bucket -cne $marketDataBucket -or $receipt.dry_run.status -cne "DRY_RUN" -or
        [int]$receipt.dry_run.verified_object_count -ne $ExpectedObjectCount -or
        [int]$receipt.dry_run.manifest_count -ne $ExpectedManifestCount) {
        throw "Market catalog receipt failed the exact identity and count gates."
    }
    if ($Phase -eq "Apply" -and ($receipt.dry_run.source_digest -cne $ReviewedDryRunSourceDigest -or
        $receipt.applied.status -notin @("APPLIED", "ALREADY_APPLIED") -or
        $receipt.replay.status -cne "ALREADY_APPLIED" -or [int]$receipt.replay.inserted_row_count -ne 0)) {
        throw "Apply receipt did not prove reviewed digest application and replay no-op."
    }

    $receiptPath = Join-Path $temporaryRoot "$($Phase.ToLowerInvariant())-receipt.json"
    Write-Utf8NoBomFile $receiptPath ($receipt | ConvertTo-Json -Depth 30 -Compress)
    $receiptSha256 = (Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $receiptKey = if ($Phase -eq "DryRun") { $dryRunReceiptKey } else { $applyReceiptKey }
    $receiptUpload = Invoke-AwsJson @(
        "s3api", "put-object", "--bucket", $marketDataBucket, "--key", $receiptKey, "--body", $receiptPath,
        "--metadata", "sha256=$receiptSha256,root-sha=$head,pipeline-source-commit=$pipelineSourceCommit"
    )
    if ([string]::IsNullOrWhiteSpace([string]$receiptUpload.VersionId)) { throw "Evidence receipt must be stored as a versioned S3 object." }

    [ordered]@{
        status = "passed"
        phase = $Phase
        root_sha = $head
        pipeline_source_commit = $pipelineSourceCommit
        pipeline_image = $pipelineImage
        source_digest = [string]$receipt.dry_run.source_digest
        verified_object_count = [int]$receipt.dry_run.verified_object_count
        manifest_count = [int]$receipt.dry_run.manifest_count
        receipt_key = $receiptKey
        receipt_version_id = [string]$receiptUpload.VersionId
        receipt_sha256 = $receiptSha256
        replay_status = if ($Phase -eq "Apply") { [string]$receipt.replay.status } else { $null }
    } | ConvertTo-Json -Depth 5
}
finally {
    if ($instanceId -match '^i-[0-9a-f]+$') {
        try { $null = Invoke-AwsJson @("ec2", "terminate-instances", "--instance-ids", $instanceId) } catch { Write-Warning "TerminateInstances cleanup failed for the exact ephemeral instance." }
    }
    if ($policyAttached) {
        try { $null = Invoke-AwsJson @("iam", "delete-role-policy", "--role-name", [string]$target.role_name, "--policy-name", $inlinePolicyName) } catch { Write-Warning "DeleteRolePolicy cleanup failed for the transient market catalog policy." }
    }
}
