[CmdletBinding()]
param(
    [string]$TerraformRoot = "infra/terraform/environments/development",
    [string]$AwsProfile = "idea2strategy-terraform",
    [string]$AwsRegion = "ap-northeast-2",
    [Parameter(Mandatory = $true)][ValidatePattern('^\d{12}$')][string]$ExpectedAwsAccountId,
    [ValidateRange(30, 600)][int]$PublicProbeTimeoutSeconds = 300,
    [ValidateRange(1, 30)][int]$PublicProbeIntervalSeconds = 5
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

function Invoke-PublicProbeWithRetry {
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [Parameter(Mandatory = $true)][scriptblock]$Probe,
        [Parameter(Mandatory = $true)][scriptblock]$IsSuccessful
    )

    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($PublicProbeTimeoutSeconds)
    $lastFailure = 'probe did not run'
    while ($true) {
        try {
            $result = & $Probe
            if (& $IsSuccessful $result) { return $result }
            $lastFailure = "unexpected result '$result'"
        }
        catch {
            $lastFailure = $_.Exception.Message
        }
        if ([DateTimeOffset]::UtcNow -ge $deadline) { break }
        Start-Sleep -Seconds $PublicProbeIntervalSeconds
    }
    throw "$Label did not become ready within $PublicProbeTimeoutSeconds seconds. Last failure: $lastFailure"
}

$caller = Invoke-AwsJson -Arguments @('sts', 'get-caller-identity')
if ([string]$caller.Account -cne $ExpectedAwsAccountId) { throw "AWS account mismatch." }

$previousAwsProfile = [Environment]::GetEnvironmentVariable('AWS_PROFILE', 'Process')
try {
    if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) {
        $env:AWS_PROFILE = $AwsProfile
    } else {
        Remove-Item Env:AWS_PROFILE -ErrorAction SilentlyContinue
    }
    $rawOutputs = & $terraform.Source "-chdir=$terraformDirectory" output -json
    if ($LASTEXITCODE -ne 0) { throw "Unable to read the applied Terraform outputs." }
    $outputs = $rawOutputs | ConvertFrom-Json
} finally {
    if ($null -eq $previousAwsProfile) {
        Remove-Item Env:AWS_PROFILE -ErrorAction SilentlyContinue
    } else {
        $env:AWS_PROFILE = $previousAwsProfile
    }
}
if ([string]$outputs.aws_account_id.value -cne $ExpectedAwsAccountId) { throw "Terraform state account mismatch." }

$serviceUrl = ([string]$outputs.service_url.value).TrimEnd('/')
if ($serviceUrl -notmatch '^https://') { throw "Applied service URL is not HTTPS." }

$frontend = Invoke-PublicProbeWithRetry `
    -Label 'frontend' `
    -Probe { Invoke-WebRequest -Uri "$serviceUrl/" -Method Get -TimeoutSec 30 -MaximumRedirection 3 -UseBasicParsing } `
    -IsSuccessful { param($response) $response.StatusCode -eq 200 -and -not [string]::IsNullOrWhiteSpace($response.Content) }
foreach ($component in @('backend', 'backtest')) {
    $health = Invoke-PublicProbeWithRetry `
        -Label "$component health" `
        -Probe { Invoke-WebRequest -Uri "$serviceUrl/api/healthz/$component" -Method Get -TimeoutSec 30 -UseBasicParsing } `
        -IsSuccessful { param($response) $response.StatusCode -eq 200 -and -not [string]::IsNullOrWhiteSpace($response.Content) }
}

# An invalid single-use ticket must reach the backend WebSocket handshake and be
# rejected there. A CDN/proxy path that drops Upgrade headers returns a different
# status, so this also proves the public CloudFront -> Nginx -> backend route.
Add-Type -AssemblyName System.Net.Http
$webSocketProbeClient = [System.Net.Http.HttpClient]::new()
try {
    [void](Invoke-PublicProbeWithRetry `
        -Label 'market-data WebSocket handshake' `
        -Probe {
            $webSocketProbe = [System.Net.Http.HttpRequestMessage]::new(
                [System.Net.Http.HttpMethod]::Get,
                "$serviceUrl/ws/v1/market-data/prices?ticket=invalid-deployment-smoke"
            )
            $webSocketProbe.Version = [Version]::new(1, 1)
            [void]$webSocketProbe.Headers.TryAddWithoutValidation('Connection', 'Upgrade')
            [void]$webSocketProbe.Headers.TryAddWithoutValidation('Upgrade', 'websocket')
            [void]$webSocketProbe.Headers.TryAddWithoutValidation('Origin', $serviceUrl)
            [void]$webSocketProbe.Headers.TryAddWithoutValidation('Sec-WebSocket-Version', '13')
            [void]$webSocketProbe.Headers.TryAddWithoutValidation('Sec-WebSocket-Key', 'aWRlYTJzdHJhdGVneTEyMw==')
            $webSocketProbeResponse = $null
            try {
                $webSocketProbeResponse = $webSocketProbeClient.SendAsync($webSocketProbe).GetAwaiter().GetResult()
                return [int]$webSocketProbeResponse.StatusCode
            }
            finally {
                if ($null -ne $webSocketProbeResponse) { $webSocketProbeResponse.Dispose() }
                $webSocketProbe.Dispose()
            }
        } `
        -IsSuccessful { param($statusCode) $statusCode -eq [int][System.Net.HttpStatusCode]::Unauthorized })
}
finally {
    $webSocketProbeClient.Dispose()
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
  expected_image="$(aws ssm get-parameter --region '__AWS_REGION__' --name "/idea2strategy/dev/deployment/images/$service" --query Parameter.Value --output text)"
  case "$expected_image" in (*@sha256:*) ;; (*) exit 1 ;; esac
  configured_image="$(docker inspect --format '{{.Config.Image}}' "$container")"
  test "$configured_image" = "$expected_image"
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
  expected_image="$(aws ssm get-parameter --region '__AWS_REGION__' --name "/idea2strategy/dev/deployment/images/$service" --query Parameter.Value --output text)"
  configured_image="$(docker inspect --format '{{.Config.Image}}' "$container")"
  test "$configured_image" = "$expected_image"
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
$runtimeCheckScript = $runtimeCheckScript.Replace('__AWS_REGION__', $AwsRegion)
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
    market_data_websocket = 'passed'
    cloudfront_https = 'passed'
    frontend_s3 = 'passed'
    ssm = 'passed'
    core_runtime = 'passed'
    rds = 'passed'
    valkey = 'passed'
    queues = 'passed'
    cloudwatch = 'passed'
} | ConvertTo-Json -Compress
