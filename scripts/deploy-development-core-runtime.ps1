[CmdletBinding()]
param(
    [string]$TerraformRoot = "infra/terraform/environments/development",
    [string]$AwsProfile = "idea2strategy-terraform",
    [string]$AwsRegion = "ap-northeast-2"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$terraformDirectory = Join-Path $root $TerraformRoot
$terraform = Get-Command terraform -ErrorAction SilentlyContinue
$aws = Get-Command aws -ErrorAction SilentlyContinue
if ($null -eq $terraform) { throw "Terraform 1.15.x is required." }
if ($null -eq $aws) { throw "AWS CLI v2 is required." }

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

$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($remoteScript))
$parameters = @{ commands = @("printf '%s' '$encoded' | base64 -d | bash") } | ConvertTo-Json -Compress
$parametersPath = [IO.Path]::GetTempFileName()
try {
    [IO.File]::WriteAllText($parametersPath, $parameters, [Text.UTF8Encoding]::new($false))
    $common = @("--region", $AwsRegion, "--output", "json")
    if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) { $common += @("--profile", $AwsProfile) }
    $sentJson = & $aws.Source ssm send-command --instance-ids $serviceInstanceId --document-name AWS-RunShellScript --comment "Roll out exact Idea2Strategy Core image digests" --parameters "file://$parametersPath" --timeout-seconds 900 @common
    if ($LASTEXITCODE -ne 0) { throw "Unable to start the Core runtime rollout." }
    $commandId = [string](($sentJson -join "`n") | ConvertFrom-Json).Command.CommandId
}
finally {
    Remove-Item -LiteralPath $parametersPath -Force -ErrorAction SilentlyContinue
}

$invocation = $null
for ($attempt = 0; $attempt -lt 120; $attempt++) {
    Start-Sleep -Seconds 5
    $arguments = @("ssm", "get-command-invocation", "--command-id", $commandId, "--instance-id", $serviceInstanceId, "--region", $AwsRegion, "--output", "json")
    if (-not [string]::IsNullOrWhiteSpace($AwsProfile)) { $arguments += @("--profile", $AwsProfile) }
    $output = & $aws.Source @arguments 2>$null
    if ($LASTEXITCODE -ne 0) { continue }
    $invocation = ($output -join "`n") | ConvertFrom-Json
    if ([string]$invocation.Status -in @("Success", "Failed", "Cancelled", "TimedOut")) { break }
}
if ($null -eq $invocation -or [string]$invocation.Status -cne "Success" -or
    -not ([string]$invocation.StandardOutputContent).Contains("CORE_RUNTIME_ROLLED_OUT")) {
    throw "Core runtime rollout failed; the remote command attempted the rollback before returning failure."
}

[pscustomobject]@{
    status = "passed"
    instance_id = $serviceInstanceId
    command_id = $commandId
    exact_image_rollout = $true
} | ConvertTo-Json -Compress
