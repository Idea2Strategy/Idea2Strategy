$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$pipelinePath = Join-Path $repoRoot 'infra/terraform/environments/development/pipeline.tf'
$variablesPath = Join-Path $repoRoot 'infra/terraform/environments/development/variables.tf'

$pipeline = Get-Content -LiteralPath $pipelinePath -Raw
$variables = Get-Content -LiteralPath $variablesPath -Raw

if ($pipeline -notmatch 'command\s*=\s*\["--publish-manifest-watermarks"\]') {
    throw 'The scheduled ECS target must invoke the manifest-watermark product path.'
}
if ($pipeline -notmatch 'PIPELINE_WORKER_DATABASE_URL') {
    throw 'The pipeline task must receive its database URL from Secrets Manager.'
}
if ($variables -notmatch 'default\s*=\s*"cron\(30 23 \? \* MON-FRI \*\)"') {
    throw 'The development watermark schedule must run after each US trading session.'
}

Write-Output 'Development pipeline watermark wiring checks passed.'
