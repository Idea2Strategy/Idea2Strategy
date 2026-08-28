[CmdletBinding()]
param(
    [string]$ContainerName = 'idea2strategy-postgres',
    [string]$PostgresUser = 'idea2strategy',
    [string]$PostgresDatabase = 'idea2strategy'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$seed = Join-Path $root 'proposals/development-scoring-template/artifacts/scoring-template-seed.sql'
if (-not (Test-Path -LiteralPath $seed -PathType Leaf)) {
    throw "Reviewed local scoring seed is missing: $seed"
}

$containerSeed = '/tmp/local-scoring-template-seed.sql'
& docker cp $seed "${ContainerName}:${containerSeed}" | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Unable to copy the local scoring-template seed.' }

& docker exec $ContainerName psql -v ON_ERROR_STOP=1 `
    -U $PostgresUser -d $PostgresDatabase -f $containerSeed | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Unable to seed the local scoring-template catalog.' }

$count = (& docker exec $ContainerName psql -X -qAt -v ON_ERROR_STOP=1 `
    -U $PostgresUser -d $PostgresDatabase -c `
    "SELECT count(*) FROM competition.scoring_template_versions WHERE retired_at IS NULL AND version='development-2026-q3-v1';" |
    Select-Object -Last 1).Trim()
if ($LASTEXITCODE -ne 0 -or $count -ne '4') {
    throw "Local scoring-template catalog is incomplete; expected 4 selectable templates and found $count."
}
