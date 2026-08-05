[CmdletBinding()]
param(
    [string]$TerraformRoot = "infra/terraform/environments/development",
    [string]$AwsProfile = "idea2strategy-terraform",
    [string]$AwsRegion = "ap-northeast-2",
    [Parameter(Mandatory = $true)][ValidatePattern('^\d{12}$')][string]$ExpectedAwsAccountId
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$terraformDirectory = Join-Path $root $TerraformRoot
$aws = Get-Command aws -ErrorAction SilentlyContinue
$awsExecutable = if ($null -ne $aws) { $aws.Source } else { Join-Path $env:ProgramFiles "Amazon\AWSCLIV2\aws.exe" }
if (-not (Test-Path -LiteralPath $awsExecutable -PathType Leaf)) { throw "AWS CLI v2 is required." }
$terraform = Get-Command terraform -ErrorAction SilentlyContinue
if ($null -eq $terraform) { throw "Terraform 1.15.x is required." }

function Invoke-AwsJson([string[]]$Arguments) {
    $awsCommonArguments = @('--region', $AwsRegion, '--output', 'json')
    if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) {
        $awsCommonArguments += @('--profile', $AwsProfile)
    }
    $result = & $awsExecutable @Arguments @awsCommonArguments
    if ($LASTEXITCODE -ne 0) { throw "AWS read-only verification failed." }
    return $result | ConvertFrom-Json
}

$caller = Invoke-AwsJson -Arguments @('sts', 'get-caller-identity')
if ([string]$caller.Account -cne $ExpectedAwsAccountId) { throw "AWS account mismatch." }

$outputs = (& $terraform.Source "-chdir=$terraformDirectory" output -json) | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw "Unable to read the applied Terraform outputs." }
if ([string]$outputs.aws_account_id.value -cne $ExpectedAwsAccountId) { throw "Terraform state account mismatch." }

$serviceUrl = ([string]$outputs.service_url.value).TrimEnd('/')
if ($serviceUrl -notmatch '^https://') { throw "Applied service URL is not HTTPS." }

$frontend = Invoke-WebRequest -Uri "$serviceUrl/" -Method Get -TimeoutSec 30 -MaximumRedirection 3 -UseBasicParsing
if ($frontend.StatusCode -ne 200 -or [string]::IsNullOrWhiteSpace($frontend.Content)) {
    throw "Frontend did not return a non-empty HTTP 200 response."
}
foreach ($component in @('backend', 'backtest')) {
    $health = Invoke-WebRequest -Uri "$serviceUrl/api/healthz/$component" -Method Get -TimeoutSec 30 -UseBasicParsing
    if ($health.StatusCode -ne 200 -or [string]::IsNullOrWhiteSpace($health.Content)) {
        throw "$component health check failed."
    }
}

$distributionId = [string]$outputs.cloudfront_distribution_id.value
$distribution = Invoke-AwsJson -Arguments @('cloudfront', 'get-distribution', '--id', $distributionId)
if ($distribution.Distribution.Status -cne 'Deployed' -or
    [bool]$distribution.Distribution.DistributionConfig.ViewerCertificate.CloudFrontDefaultCertificate) {
    throw "CloudFront is not deployed with the reviewed ACM viewer certificate."
}

$frontendBucket = [string]$outputs.frontend_bucket.value
$publicBlock = Invoke-AwsJson -Arguments @('s3api', 'get-public-access-block', '--bucket', $frontendBucket)
$block = $publicBlock.PublicAccessBlockConfiguration
if (-not ($block.BlockPublicAcls -and $block.IgnorePublicAcls -and $block.BlockPublicPolicy -and $block.RestrictPublicBuckets)) {
    throw "Frontend bucket public access block is incomplete."
}
$versioning = Invoke-AwsJson -Arguments @('s3api', 'get-bucket-versioning', '--bucket', $frontendBucket)
if ($versioning.Status -cne 'Enabled') { throw "Frontend bucket versioning is not enabled." }

$serviceInstanceId = [string]$outputs.service_instance_id.value
$managed = Invoke-AwsJson -Arguments @('ssm', 'describe-instance-information', '--filters', "Key=InstanceIds,Values=$serviceInstanceId")
if (@($managed.InstanceInformationList).Count -ne 1 -or $managed.InstanceInformationList[0].PingStatus -cne 'Online') {
    throw "Core instance is not online in Systems Manager."
}

$runtimeCheckScript = @'
set -eu
cd /opt/idea2strategy
container_is_runtime_ready() {
  local running="$1"
  local status="$2"
  local restarting="$3"
  local health="$4"
  test "$running" = true || return 1
  test "$status" = running || return 1
  test "$restarting" = false || return 1
  test "$health" = missing || test "$health" = healthy
}
declare -A initial_container initial_restarts
for service in backend-api backend-worker backtest-api; do
  container="$(docker compose --project-name idea2strategy ps -q "$service")"
  test -n "$container"
  running="$(docker inspect --format '{{.State.Running}}' "$container")"
  status="$(docker inspect --format '{{.State.Status}}' "$container")"
  restarting="$(docker inspect --format '{{.State.Restarting}}' "$container")"
  health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' "$container")"
  if ! container_is_runtime_ready "$running" "$status" "$restarting" "$health"; then
    exit 1
  fi
  restarts="$(docker inspect --format '{{.RestartCount}}' "$container")"
  initial_container["$service"]="$container"
  initial_restarts["$service"]="$restarts"
done
sleep 20
for service in backend-api backend-worker backtest-api; do
  container="$(docker compose --project-name idea2strategy ps -q "$service")"
  test -n "$container"
  test "$container" = "${initial_container[$service]}"
  running="$(docker inspect --format '{{.State.Running}}' "$container")"
  status="$(docker inspect --format '{{.State.Status}}' "$container")"
  restarting="$(docker inspect --format '{{.State.Restarting}}' "$container")"
  health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' "$container")"
  if ! container_is_runtime_ready "$running" "$status" "$restarting" "$health"; then
    exit 1
  fi
  restarts="$(docker inspect --format '{{.RestartCount}}' "$container")"
  test "$restarts" -eq "${initial_restarts[$service]}"
done
echo CORE_RUNTIME_STABLE
'@
$runtimeCheckScriptBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($runtimeCheckScript))
$runtimeParameters = @{ commands = @("printf '%s' '$runtimeCheckScriptBase64' | base64 -d | bash") } | ConvertTo-Json -Compress
$runtimeParametersPath = [IO.Path]::GetTempFileName()
try {
    [IO.File]::WriteAllText($runtimeParametersPath, $runtimeParameters, [Text.UTF8Encoding]::new($false))
    $runtimeCommand = Invoke-AwsJson -Arguments @(
        'ssm', 'send-command',
        '--instance-ids', $serviceInstanceId,
        '--document-name', 'AWS-RunShellScript',
        '--parameters', "file://$runtimeParametersPath"
    )
}
finally {
    Remove-Item -LiteralPath $runtimeParametersPath -Force -ErrorAction SilentlyContinue
}
$runtimeCommandId = [string]$runtimeCommand.Command.CommandId
$runtimeInvocation = $null
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    Start-Sleep -Seconds 2
    try {
        $runtimeInvocation = Invoke-AwsJson -Arguments @(
            'ssm', 'get-command-invocation',
            '--command-id', $runtimeCommandId,
            '--instance-id', $serviceInstanceId
        )
    }
    catch {
        continue
    }
    if ([string]$runtimeInvocation.Status -in @('Success', 'Failed', 'Cancelled', 'TimedOut')) { break }
}
if ($null -eq $runtimeInvocation -or [string]$runtimeInvocation.Status -cne 'Success' -or
    -not ([string]$runtimeInvocation.StandardOutputContent).Contains('CORE_RUNTIME_STABLE')) {
    throw "Core containers are unhealthy or restarted during the stability window."
}

$rdsEndpoint = [string]$outputs.rds_endpoint.value
$databases = Invoke-AwsJson -Arguments @('rds', 'describe-db-instances')
$database = @($databases.DBInstances | Where-Object { $_.Endpoint.Address -ceq $rdsEndpoint })
if ($database.Count -ne 1 -or $database[0].DBInstanceStatus -cne 'available' -or
    [bool]$database[0].PubliclyAccessible -or -not [bool]$database[0].DeletionProtection) {
    throw "RDS availability, private placement, or deletion protection check failed."
}

$cacheEndpoint = [string]$outputs.cache_endpoint.value
$caches = Invoke-AwsJson -Arguments @('elasticache', 'describe-serverless-caches')
$cache = @($caches.ServerlessCaches | Where-Object { $_.Endpoint.Address -ceq $cacheEndpoint })
if ($cache.Count -ne 1 -or $cache[0].Status -cne 'available') { throw "Valkey Serverless is not available." }

foreach ($queueProperty in $outputs.queue_urls.value.PSObject.Properties) {
    $attributes = Invoke-AwsJson -Arguments @('sqs', 'get-queue-attributes', '--queue-url', [string]$queueProperty.Value, '--attribute-names', 'QueueArn', 'RedrivePolicy', 'SqsManagedSseEnabled')
    if ([string]::IsNullOrWhiteSpace([string]$attributes.Attributes.QueueArn) -or
        [string]::IsNullOrWhiteSpace([string]$attributes.Attributes.RedrivePolicy) -or
        [string]$attributes.Attributes.SqsManagedSseEnabled -cne 'true') {
        throw "Queue '$($queueProperty.Name)' is missing identity, DLQ redrive policy, or managed SSE."
    }
}

$logGroups = Invoke-AwsJson -Arguments @('logs', 'describe-log-groups', '--log-group-name-prefix', '/idea2strategy/dev/')
$names = @($logGroups.logGroups | ForEach-Object { $_.logGroupName })
foreach ($requiredLog in @('/idea2strategy/dev/core', '/idea2strategy/dev/trading', '/idea2strategy/dev/backtest', '/idea2strategy/dev/pipeline')) {
    if ($names -notcontains $requiredLog) { throw "CloudWatch log group is missing: $requiredLog" }
}

[pscustomobject]@{
    status = 'passed'
    account_masked = ('*' * 8) + $ExpectedAwsAccountId.Substring(8)
    region = $AwsRegion
    service_url = $serviceUrl
    frontend = 'passed'
    backend_health = 'passed'
    backtest_health = 'passed'
    cloudfront_https = 'passed'
    frontend_s3 = 'passed'
    ssm = 'passed'
    core_runtime = 'passed'
    rds = 'passed'
    valkey = 'passed'
    queues = 'passed'
    cloudwatch = 'passed'
} | ConvertTo-Json -Compress
