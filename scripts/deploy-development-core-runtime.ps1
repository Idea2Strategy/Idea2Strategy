[CmdletBinding()]
param(
    [string]$TerraformRoot = "infra/terraform/environments/development",
    [string]$AwsProfile = "idea2strategy-terraform",
    [string]$AwsRegion = "ap-northeast-2",
    [ValidateRange(60, 1800)][int]$ReadinessTimeoutSeconds = 900,
    [ValidateRange(60, 1800)][int]$RolloutTimeoutSeconds = 900
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$terraformDirectory = Join-Path $root $TerraformRoot
$terraform = Get-Command terraform -ErrorAction SilentlyContinue
$aws = Get-Command aws -ErrorAction SilentlyContinue
if ($null -eq $terraform) { throw "Terraform 1.15.x is required." }
if ($null -eq $aws) { throw "AWS CLI v2 is required." }

$commonAwsArguments = @("--region", $AwsRegion, "--output", "json")
if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) { $commonAwsArguments += @("--profile", $AwsProfile) }

function Invoke-AwsJson([string[]]$Arguments) {
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $output = & $aws.Source @Arguments @commonAwsArguments 2>$null
        $exitCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($exitCode -ne 0) { throw "AWS command failed without exposing remote output: $($Arguments[0]) $($Arguments[1])" }
    return (($output -join "`n") | ConvertFrom-Json)
}

function Invoke-SsmShellCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Script,
        [Parameter(Mandatory = $true)][string]$Comment,
        [Parameter(Mandatory = $true)][string]$SuccessMarker,
        [Parameter(Mandatory = $true)][int]$TimeoutSeconds
    )

    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Script))
    $parameters = @{ commands = @("printf '%s' '$encoded' | base64 -d | bash") } | ConvertTo-Json -Compress
    $parametersPath = [IO.Path]::GetTempFileName()
    try {
        [IO.File]::WriteAllText($parametersPath, $parameters, [Text.UTF8Encoding]::new($false))
        $sent = Invoke-AwsJson @(
            "ssm", "send-command",
            "--instance-ids", $serviceInstanceId,
            "--document-name", "AWS-RunShellScript",
            "--comment", $Comment,
            "--parameters", "file://$parametersPath",
            "--timeout-seconds", [string]$TimeoutSeconds
        )
        $commandId = [string]$sent.Command.CommandId
        if ($commandId -notmatch '^[0-9a-f-]{36}$') { throw "SSM did not return an exact command ID." }
    }
    finally {
        Remove-Item -LiteralPath $parametersPath -Force -ErrorAction SilentlyContinue
    }

    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds + 60)
    $invocation = $null
    while ([DateTimeOffset]::UtcNow -lt $deadline) {
        Start-Sleep -Seconds 5
        try {
            $invocation = Invoke-AwsJson @(
                "ssm", "get-command-invocation",
                "--command-id", $commandId,
                "--instance-id", $serviceInstanceId
            )
        }
        catch {
            continue
        }
        if ([string]$invocation.Status -in @("Success", "Failed", "Cancelled", "TimedOut")) { break }
    }
    if ($null -eq $invocation -or [string]$invocation.Status -cne "Success" -or
        -not ([string]$invocation.StandardOutputContent).Contains($SuccessMarker)) {
        throw "SSM command '$Comment' failed or exceeded its bounded timeout."
    }
    return $commandId
}

$previousAwsProfile = [Environment]::GetEnvironmentVariable('AWS_PROFILE', 'Process')
try {
    if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) {
        $env:AWS_PROFILE = $AwsProfile
    } else {
        Remove-Item Env:AWS_PROFILE -ErrorAction SilentlyContinue
    }
    $serviceInstanceId = (& $terraform.Source "-chdir=$terraformDirectory" output -raw service_instance_id).Trim()
    if ($LASTEXITCODE -ne 0 -or $serviceInstanceId -notmatch '^i-[0-9a-f]+$') {
        throw "Unable to resolve the exact Core instance from applied Terraform state."
    }
} finally {
    if ($null -eq $previousAwsProfile) {
        Remove-Item Env:AWS_PROFILE -ErrorAction SilentlyContinue
    } else {
        $env:AWS_PROFILE = $previousAwsProfile
    }
}

& $aws.Source ec2 wait instance-running --instance-ids $serviceInstanceId @commonAwsArguments
if ($LASTEXITCODE -ne 0) { throw "Core instance did not reach EC2 running state within the AWS waiter timeout." }

$ssmDeadline = [DateTimeOffset]::UtcNow.AddSeconds($ReadinessTimeoutSeconds)
$ssmOnline = $false
while ([DateTimeOffset]::UtcNow -lt $ssmDeadline) {
    $information = Invoke-AwsJson @(
        "ssm", "describe-instance-information",
        "--filters", "Key=InstanceIds,Values=$serviceInstanceId"
    )
    if (@($information.InstanceInformationList).Count -eq 1 -and
        [string]$information.InstanceInformationList[0].PingStatus -ceq "Online") {
        $ssmOnline = $true
        break
    }
    Start-Sleep -Seconds 5
}
if (-not $ssmOnline) { throw "Core instance did not become SSM Online within the readiness timeout." }

$cloudInitTimeout = [Math]::Max(60, $ReadinessTimeoutSeconds - 60)
$readinessScript = @'
set -euo pipefail
timeout __CLOUD_INIT_TIMEOUT__ cloud-init status --wait
test -f /opt/idea2strategy/bootstrap-complete
test -s /opt/idea2strategy/compose.yaml
test -x /usr/local/sbin/idea2strategy-runtime-start
systemctl is-enabled --quiet idea2strategy-runtime.service
systemctl is-active --quiet idea2strategy-runtime.service
cd /opt/idea2strategy
docker compose --project-name idea2strategy config --quiet
echo CORE_HOST_READY
'@.Replace('__CLOUD_INIT_TIMEOUT__', [string]$cloudInitTimeout)

$readinessCommandId = Invoke-SsmShellCommand `
    -Script $readinessScript `
    -Comment "Verify Core cloud-init and runtime readiness" `
    -SuccessMarker "CORE_HOST_READY" `
    -TimeoutSeconds $ReadinessTimeoutSeconds

$remoteScript = @'
set -euo pipefail
umask 077
cd /opt/idea2strategy
rollback_compose="$(mktemp /opt/idea2strategy/.compose.rollback.XXXXXX)"
install -m 0600 compose.yaml "$rollback_compose"

container_ready() {
  local container="$1" running status restarting health
  running="$(docker inspect --format '{{.State.Running}}' "$container")"
  status="$(docker inspect --format '{{.State.Status}}' "$container")"
  restarting="$(docker inspect --format '{{.State.Restarting}}' "$container")"
  health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}missing{{end}}' "$container")"
  test "$running" = true
  test "$status" = running
  test "$restarting" = false
  { test "$health" = missing || test "$health" = healthy; }
}

runtime_ready() {
  local service container expected configured
  for service in backend-api backend-worker backtest-api; do
    expected="$(aws ssm get-parameter --region '__AWS_REGION__' --name "/idea2strategy/dev/deployment/images/$service" --query Parameter.Value --output text)"
    case "$expected" in (*@sha256:*) ;; (*) return 1 ;; esac
    container="$(docker compose --project-name idea2strategy ps -q "$service")"
    test -n "$container"
    configured="$(docker inspect --format '{{.Config.Image}}' "$container")"
    test "$configured" = "$expected"
    container_ready "$container"
  done
}

rollback() {
  install -m 0600 "$rollback_compose" compose.yaml
  docker compose --project-name idea2strategy config --quiet
  docker compose --project-name idea2strategy pull
  docker compose --project-name idea2strategy up --detach --remove-orphans --wait
  sleep 20
  for service in backend-api backend-worker backtest-api; do
    container="$(docker compose --project-name idea2strategy ps -q "$service")"
    test -n "$container"
    container_ready "$container"
  done
  echo CORE_RUNTIME_ROLLBACK_SUCCEEDED
}

if ! /usr/local/sbin/idea2strategy-runtime-start; then
  rollback
  rm -f "$rollback_compose"
  exit 1
fi
if ! runtime_ready; then
  rollback
  rm -f "$rollback_compose"
  exit 1
fi
sleep 20
if ! runtime_ready; then
  rollback
  rm -f "$rollback_compose"
  exit 1
fi
rm -f "$rollback_compose"
echo CORE_RUNTIME_ROLLED_OUT
'@.Replace('__AWS_REGION__', $AwsRegion)

$rolloutCommandId = Invoke-SsmShellCommand `
    -Script $remoteScript `
    -Comment "Roll out exact Idea2Strategy Core image digests" `
    -SuccessMarker "CORE_RUNTIME_ROLLED_OUT" `
    -TimeoutSeconds $RolloutTimeoutSeconds

[pscustomobject]@{
    status = "passed"
    instance_id = $serviceInstanceId
    readiness_command_id = $readinessCommandId
    command_id = $rolloutCommandId
    cloud_init_ready = $true
    ssm_online = $true
    exact_image_rollout = $true
} | ConvertTo-Json -Compress
