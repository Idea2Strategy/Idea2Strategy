[CmdletBinding()]
param(
    [string]$TerraformRoot = "infra/terraform/environments/development",
    [string]$AwsProfile = "idea2strategy-terraform",
    [string]$AwsRegion = "ap-northeast-2",
    [ValidateSet("core", "trading")][string]$RuntimeRole = "core",
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
$runtimeLabel = if ($RuntimeRole -ceq "trading") { "Trading" } else { "Core" }
$terraformOutputName = if ($RuntimeRole -ceq "trading") { "trading_instance_id" } else { "service_instance_id" }
$runtimeServices = if ($RuntimeRole -ceq "trading") {
    @("market-gateway", "trading-worker")
} else {
    @("backend-api", "backend-worker", "backtest-api")
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
    [ValidateSet("core", "trading")][string]$RuntimeRole,
    [string]$InstanceState
) {
    if ($RuntimeRole -cne "trading") { return "wait-running" }
    switch -CaseSensitive ($InstanceState) {
        "pending" { return "wait-running" }
        "running" { return "wait-running" }
        "stopping" { return "wait-stopped-then-start" }
        "stopped" { return "start" }
        default { throw "Trading instance entered an unsupported EC2 state: $InstanceState" }
    }
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
    $runtimeInstanceId = (& $terraform.Source "-chdir=$terraformDirectory" output -raw $terraformOutputName).Trim()
    if ($LASTEXITCODE -ne 0 -or $runtimeInstanceId -notmatch '^i-[0-9a-f]+$') {
        throw "Unable to resolve the exact $runtimeLabel instance from applied Terraform state."
    }
} finally {
    if ($null -eq $previousAwsProfile) {
        Remove-Item Env:AWS_PROFILE -ErrorAction SilentlyContinue
    } else {
        $env:AWS_PROFILE = $previousAwsProfile
    }
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
