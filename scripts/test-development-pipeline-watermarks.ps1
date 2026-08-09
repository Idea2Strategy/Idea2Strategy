$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$pipelinePath = Join-Path $repoRoot 'infra/terraform/environments/development/pipeline.tf'
$variablesPath = Join-Path $repoRoot 'infra/terraform/environments/development/variables.tf'

$pipeline = Get-Content -LiteralPath $pipelinePath -Raw
$variables = Get-Content -LiteralPath $variablesPath -Raw

if ($pipeline -notmatch 'command\s*=\s*\["--sync-market-history"\]') {
    throw 'The scheduled ECS target must publish history, project its cache, and advance watermarks.'
}
if ($pipeline -notmatch 'PIPELINE_WORKER_DATABASE_URL') {
    throw 'The pipeline task must receive its database URL from Secrets Manager.'
}
if ($pipeline -notmatch 'PIPELINE_WORKER_MARKET_HISTORY_REDIS_URI') {
    throw 'The pipeline task must receive the shared TLS market-history cache URI.'
}
if ($pipeline -notmatch 'PIPELINE_WORKER_MARKET_HISTORY_LIMIT"?,\s*value\s*=\s*"400"') {
    throw 'The market-history cache must retain 400 bars per instrument and timeframe.'
}
if ($variables -notmatch 'default\s*=\s*"cron\(30 23 \? \* MON-FRI \*\)"') {
    throw 'The development watermark schedule must run after each US trading session.'
}

Write-Output 'Development pipeline watermark wiring checks passed.'
