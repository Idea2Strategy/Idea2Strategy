[CmdletBinding()]
param(
    [string]$TerraformRoot = "infra/terraform/environments/development",
    [string]$AwsProfile = "idea2strategy-terraform",
    [string]$AwsRegion = "ap-northeast-2",
    [ValidateSet("core", "trading", "backtest-worker")][string]$RuntimeRole = "core",
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
$runtimeLabel = switch -CaseSensitive ($RuntimeRole) {
    "trading" { "Trading" }
    "backtest-worker" { "Backtest worker" }
    default { "Core" }
}
# The backtest worker is deliberately absent here. It runs in a desired-zero Auto Scaling group that
# a queue-depth alarm wakes and that scales itself back to zero when idle, so there is no stable
# instance for Terraform to output. Its instance is resolved from the group instead.
$terraformOutputName = switch -CaseSensitive ($RuntimeRole) {
    "trading" { "trading_instance_id" }
    "backtest-worker" { $null }
    default { "service_instance_id" }
}
$runtimeServices = switch -CaseSensitive ($RuntimeRole) {
    "trading" { @("market-gateway", "trading-worker") }
    "backtest-worker" { @("backtest-worker") }
    default { @("backend-api", "backend-worker", "backtest-api") }
}
$runtimeServiceWords = $runtimeServices -join " "
$hostReadyMarker = "$($RuntimeRole.ToUpperInvariant())_HOST_READY"
$rolloutMarker = "$($RuntimeRole.ToUpperInvariant())_RUNTIME_ROLLED_OUT"

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

function Get-RuntimeInstanceStartAction(
    [ValidateSet("core", "trading", "backtest-worker")][string]$RuntimeRole,
    [string]$InstanceState
) {
    # Only trading is stopped and started on a schedule. Core and the backtest worker are either
    # already running or, for the backtest worker, absent — and an absent instance returns before this
    # is reached, so there is no instance to start here.
    if ($RuntimeRole -cne "trading") { return "wait-running" }
    switch -CaseSensitive ($InstanceState) {
        "pending" { return "wait-running" }
        "running" { return "wait-running" }
        "stopping" { return "wait-stopped-then-start" }
        "stopped" { return "start" }
        default { throw "Trading instance entered an unsupported EC2 state: $InstanceState" }
    }
}

function Resolve-BacktestWorkerInstanceId {
    <#
        Returns the InService instance of the backtest Auto Scaling group, or $null when the group is
        empty.

        An empty group is the ordinary resting state, not a failure. The group is desired-zero and a
        queue-depth alarm scales it to exactly one; when it is idle it scales itself back to zero. A
        group at zero therefore needs no rollout at all, because the next wake-up boots from the
        launch template and resolves image digests from SSM at that moment.

        What this exists to catch is the other case: an instance that stays up across a release. That
        instance keeps whatever digest it resolved when it booted, and nothing else in the release
        touches it. Ours stayed up for more than five hours across two releases, which is how
        backtest-engine d0d6392 reached ECR without ever reaching the worker (root #454).
    #>
    $asgName = (Invoke-AwsJson @(
            "ssm", "get-parameter",
            "--name", "/idea2strategy/dev/backtest/asg-name"
        )).Parameter.Value
    if ([string]::IsNullOrWhiteSpace($asgName)) {
        throw "Unable to resolve the backtest Auto Scaling group name from SSM."
    }
    $group = (Invoke-AwsJson @(
            "autoscaling", "describe-auto-scaling-groups",
            "--auto-scaling-group-names", $asgName
        )).AutoScalingGroups
    if (@($group).Count -ne 1) {
        throw "Unable to resolve exactly one backtest Auto Scaling group named $asgName."
    }
    $inService = @($group[0].Instances | Where-Object { [string]$_.LifecycleState -ceq "InService" })
    if ($inService.Count -eq 0) {
        return $null
    }
    if ($inService.Count -gt 1) {
        # max_size is 1. More than one InService instance means the group is mid-change, and rolling
        # out to an arbitrary one of them would leave the other on a stale digest.
        throw "The backtest Auto Scaling group reports $($inService.Count) InService instances; expected at most one."
    }
    $instanceId = [string]$inService[0].InstanceId
    if ($instanceId -notmatch '^i-[0-9a-f]+$') {
        throw "The backtest Auto Scaling group returned a malformed instance id: $instanceId"
    }
    return $instanceId
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
            "--instance-ids", $runtimeInstanceId,
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
                "--instance-id", $runtimeInstanceId
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
    if ($RuntimeRole -ceq "backtest-worker") {
        $runtimeInstanceId = Resolve-BacktestWorkerInstanceId
    } else {
        $runtimeInstanceId = (& $terraform.Source "-chdir=$terraformDirectory" output -raw $terraformOutputName).Trim()
        if ($LASTEXITCODE -ne 0 -or $runtimeInstanceId -notmatch '^i-[0-9a-f]+$') {
            throw "Unable to resolve the exact $runtimeLabel instance from applied Terraform state."
        }
    }
} finally {
    if ($null -eq $previousAwsProfile) {
        Remove-Item Env:AWS_PROFILE -ErrorAction SilentlyContinue
    } else {
        $env:AWS_PROFILE = $previousAwsProfile
    }
}

if ($RuntimeRole -ceq "backtest-worker" -and $null -eq $runtimeInstanceId) {
    # Nothing to roll out, and that is a pass rather than a skip we are glossing over: the group is at
    # its resting capacity of zero, so the next queue-depth alarm boots an instance that resolves the
    # current digests from SSM at boot. Emitting the marker keeps this indistinguishable from a
    # successful rollout to callers while still saying plainly that no instance was touched.
    [pscustomobject]@{
        status        = "no-running-instance"
        runtime_role  = $RuntimeRole
        rolled_out_to = $null
        detail        = "The backtest Auto Scaling group has no InService instance. A desired-zero " +
        "group needs no rollout; the next wake-up boots from the launch template and resolves the " +
        "current image digests from SSM."
    } | ConvertTo-Json -Compress
    exit 0
}

if ($RuntimeRole -ceq "trading") {
    $description = Invoke-AwsJson @("ec2", "describe-instances", "--instance-ids", $runtimeInstanceId)
    $instances = @($description.Reservations | ForEach-Object { $_.Instances })
    if ($instances.Count -ne 1 -or [string]$instances[0].InstanceId -cne $runtimeInstanceId) {
        throw "Unable to resolve the exact Trading instance state before rollout."
    }
    $startAction = Get-RuntimeInstanceStartAction `
        -RuntimeRole $RuntimeRole `
        -InstanceState ([string]$instances[0].State.Name)
    if ($startAction -ceq "wait-stopped-then-start") {
        & $aws.Source ec2 wait instance-stopped --instance-ids $runtimeInstanceId @commonAwsArguments
        if ($LASTEXITCODE -ne 0) { throw "Trading instance did not finish its scheduled initialization shutdown." }
        $startAction = "start"
    }
    if ($startAction -ceq "start") {
        $started = Invoke-AwsJson @("ec2", "start-instances", "--instance-ids", $runtimeInstanceId)
        if (@($started.StartingInstances).Count -ne 1 -or
            [string]$started.StartingInstances[0].InstanceId -cne $runtimeInstanceId) {
            throw "AWS did not confirm the exact Trading instance start request."
        }
    }
}

& $aws.Source ec2 wait instance-running --instance-ids $runtimeInstanceId @commonAwsArguments
if ($LASTEXITCODE -ne 0) { throw "$runtimeLabel instance did not reach EC2 running state within the AWS waiter timeout." }

$ssmDeadline = [DateTimeOffset]::UtcNow.AddSeconds($ReadinessTimeoutSeconds)
$ssmOnline = $false
while ([DateTimeOffset]::UtcNow -lt $ssmDeadline) {
    $information = Invoke-AwsJson @(
        "ssm", "describe-instance-information",
        "--filters", "Key=InstanceIds,Values=$runtimeInstanceId"
    )
    if (@($information.InstanceInformationList).Count -eq 1 -and
        [string]$information.InstanceInformationList[0].PingStatus -ceq "Online") {
        $ssmOnline = $true
        break
    }
    Start-Sleep -Seconds 5
}
if (-not $ssmOnline) { throw "$runtimeLabel instance did not become SSM Online within the readiness timeout." }

$cloudInitTimeout = [Math]::Max(60, $ReadinessTimeoutSeconds - 60)
$coreOriginReadiness = if ($RuntimeRole -ceq "core") {
@'
test -s /etc/nginx/conf.d/idea2strategy-origin.conf
test "$(systemctl show -p Result --value idea2strategy-origin-cert.service)" = success
systemctl is-enabled --quiet idea2strategy-origin-cert.timer
systemctl is-active --quiet nginx
nginx -t
ss -H -ltn sport = :443 | grep -q LISTEN
'@
} else {
    ""
}
$readinessScript = @'
set -euo pipefail
timeout __CLOUD_INIT_TIMEOUT__ cloud-init status --wait
test -f /opt/idea2strategy/bootstrap-complete
test -s /opt/idea2strategy/compose.yaml
test -x /usr/local/sbin/idea2strategy-runtime-start
systemctl is-enabled --quiet idea2strategy-runtime.service
systemctl is-active --quiet idea2strategy-runtime.service
__CORE_ORIGIN_READINESS__
cd /opt/idea2strategy
docker compose --project-name idea2strategy config --quiet
echo CORE_HOST_READY
'@.Replace('__CLOUD_INIT_TIMEOUT__', [string]$cloudInitTimeout).Replace('__CORE_ORIGIN_READINESS__', $coreOriginReadiness).Replace('CORE_HOST_READY', $hostReadyMarker)

$readinessCommandId = Invoke-SsmShellCommand `
    -Script $readinessScript `
    -Comment "Verify $runtimeLabel cloud-init and runtime readiness" `
    -SuccessMarker $hostReadyMarker `
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
  for service in __RUNTIME_SERVICES__; do
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
  for service in __RUNTIME_SERVICES__; do
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
'@.Replace('__AWS_REGION__', $AwsRegion).Replace('__RUNTIME_SERVICES__', $runtimeServiceWords).Replace('CORE_RUNTIME_ROLLED_OUT', $rolloutMarker).Replace('__RUNTIME_ROLE__', $RuntimeRole.ToUpperInvariant())

if ($RuntimeRole -ceq 'trading') {
    $tradingEvidence = @'
set -euo pipefail
cd /opt/idea2strategy
test "$(jq 'length' /var/lib/idea2strategy/market-gateway/instruments.json)" -ge 500
jq -e '.provider == "alpaca" and .feed == "sip" and ((.expiresAt | fromdateiso8601) > (now + 7200))' /var/lib/idea2strategy/market-gateway/alpaca-sip-rights.json >/dev/null
grep -Fxq 'MARKET_GATEWAY_ALPACA_FEED=sip' /etc/idea2strategy/runtime-secret.env
grep -Fxq 'MARKET_GATEWAY_MINIMUM_INSTRUMENT_COUNT=500' /etc/idea2strategy/runtime-secret.env
for service in market-gateway trading-worker; do
  container="$(docker compose --project-name idea2strategy ps -q "$service")"
  test -n "$container"
  test "$(docker inspect --format '{{.RestartCount}}' "$container")" = 0
done
echo TRADING_RUNTIME_EVIDENCE_VERIFIED
'@
    $remoteScript = $remoteScript.Replace("echo $rolloutMarker", "$tradingEvidence`necho $rolloutMarker")
}

$rolloutCommandId = Invoke-SsmShellCommand `
    -Script $remoteScript `
    -Comment "Roll out exact Idea2Strategy $runtimeLabel image digests" `
    -SuccessMarker $rolloutMarker `
    -TimeoutSeconds $RolloutTimeoutSeconds

[pscustomobject]@{
    status = "passed"
    runtime_role = $RuntimeRole
    instance_id = $runtimeInstanceId
    readiness_command_id = $readinessCommandId
    command_id = $rolloutCommandId
    cloud_init_ready = $true
    ssm_online = $true
    exact_image_rollout = $true
} | ConvertTo-Json -Compress
