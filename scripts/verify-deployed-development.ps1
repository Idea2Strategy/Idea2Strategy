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
    $result = & $awsExecutable @Arguments --profile $AwsProfile --region $AwsRegion --output json
    if ($LASTEXITCODE -ne 0) { throw "AWS read-only verification failed." }
    return $result | ConvertFrom-Json
}

$caller = Invoke-AwsJson @('sts', 'get-caller-identity')
if ([string]$caller.Account -cne $ExpectedAwsAccountId) { throw "AWS account mismatch." }

$outputs = (& $terraform.Source -chdir=$terraformDirectory output -json) | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw "Unable to read the applied Terraform outputs." }
if ([string]$outputs.aws_account_id.value -cne $ExpectedAwsAccountId) { throw "Terraform state account mismatch." }

$serviceUrl = ([string]$outputs.service_url.value).TrimEnd('/')
if ($serviceUrl -notmatch '^https://') { throw "Applied service URL is not HTTPS." }

$frontend = Invoke-WebRequest -Uri "$serviceUrl/" -Method Get -TimeoutSec 30 -MaximumRedirection 3
if ($frontend.StatusCode -ne 200 -or [string]::IsNullOrWhiteSpace($frontend.Content)) {
    throw "Frontend did not return a non-empty HTTP 200 response."
}
foreach ($component in @('backend', 'backtest')) {
    $health = Invoke-WebRequest -Uri "$serviceUrl/api/healthz/$component" -Method Get -TimeoutSec 30
    if ($health.StatusCode -ne 200 -or [string]::IsNullOrWhiteSpace($health.Content)) {
        throw "$component health check failed."
    }
}

$distributionId = [string]$outputs.cloudfront_distribution_id.value
$distribution = Invoke-AwsJson @('cloudfront', 'get-distribution', '--id', $distributionId)
if ($distribution.Distribution.Status -cne 'Deployed' -or
    [bool]$distribution.Distribution.DistributionConfig.ViewerCertificate.CloudFrontDefaultCertificate) {
    throw "CloudFront is not deployed with the reviewed ACM viewer certificate."
}

$frontendBucket = [string]$outputs.frontend_bucket.value
$publicBlock = Invoke-AwsJson @('s3api', 'get-public-access-block', '--bucket', $frontendBucket)
$block = $publicBlock.PublicAccessBlockConfiguration
if (-not ($block.BlockPublicAcls -and $block.IgnorePublicAcls -and $block.BlockPublicPolicy -and $block.RestrictPublicBuckets)) {
    throw "Frontend bucket public access block is incomplete."
}
$versioning = Invoke-AwsJson @('s3api', 'get-bucket-versioning', '--bucket', $frontendBucket)
if ($versioning.Status -cne 'Enabled') { throw "Frontend bucket versioning is not enabled." }

$serviceInstanceId = [string]$outputs.service_instance_id.value
$managed = Invoke-AwsJson @('ssm', 'describe-instance-information', '--filters', "Key=InstanceIds,Values=$serviceInstanceId")
if (@($managed.InstanceInformationList).Count -ne 1 -or $managed.InstanceInformationList[0].PingStatus -cne 'Online') {
    throw "Core instance is not online in Systems Manager."
}

$rdsEndpoint = [string]$outputs.rds_endpoint.value
$databases = Invoke-AwsJson @('rds', 'describe-db-instances')
$database = @($databases.DBInstances | Where-Object { $_.Endpoint.Address -ceq $rdsEndpoint })
if ($database.Count -ne 1 -or $database[0].DBInstanceStatus -cne 'available' -or
    [bool]$database[0].PubliclyAccessible -or -not [bool]$database[0].DeletionProtection) {
    throw "RDS availability, private placement, or deletion protection check failed."
}

$cacheEndpoint = [string]$outputs.cache_endpoint.value
$caches = Invoke-AwsJson @('elasticache', 'describe-serverless-caches')
$cache = @($caches.ServerlessCaches | Where-Object { $_.Endpoint.Address -ceq $cacheEndpoint })
if ($cache.Count -ne 1 -or $cache[0].Status -cne 'available') { throw "Valkey Serverless is not available." }

foreach ($queueProperty in $outputs.queue_urls.value.PSObject.Properties) {
    $attributes = Invoke-AwsJson @('sqs', 'get-queue-attributes', '--queue-url', [string]$queueProperty.Value, '--attribute-names', 'QueueArn', 'RedrivePolicy', 'SqsManagedSseEnabled')
    if ([string]::IsNullOrWhiteSpace([string]$attributes.Attributes.QueueArn) -or
        [string]::IsNullOrWhiteSpace([string]$attributes.Attributes.RedrivePolicy)) {
        throw "Queue '$($queueProperty.Name)' is missing identity or DLQ redrive policy."
    }
}

$logGroups = Invoke-AwsJson @('logs', 'describe-log-groups', '--log-group-name-prefix', '/idea2strategy/development/')
$names = @($logGroups.logGroups | ForEach-Object { $_.logGroupName })
foreach ($requiredLog in @('/idea2strategy/development/core', '/idea2strategy/development/trading', '/idea2strategy/development/compute')) {
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
    rds = 'passed'
    valkey = 'passed'
    queues = 'passed'
    cloudwatch = 'passed'
} | ConvertTo-Json -Compress
