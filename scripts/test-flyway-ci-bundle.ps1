[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$bundle = Join-Path $root 'db/flyway-ci-bundle'
$metadataPath = Join-Path $bundle 'source-revisions.json'
$manifestPath = Join-Path $bundle 'migration-bundle.manifest'
$digestPath = Join-Path $bundle 'migration-bundle.sha256'
$fixture = Join-Path $bundle 'partial_fill_allocation_contract.sql.fixture'
$readContractFixture = Join-Path $bundle 'trading_read_projection_contract.sql.fixture'
$runtimeGrantsFixture = Join-Path $bundle 'runtime_grants_contract.sql.fixture'

foreach ($requiredPath in @($metadataPath, $manifestPath, $digestPath, $fixture, $readContractFixture, $runtimeGrantsFixture)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Pinned Flyway CI artifact is missing: $requiredPath"
    }
}

$metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
if ($metadata.format -cne 'idea2strategy-flyway-ci-bundle-v1') {
    throw 'Unsupported pinned Flyway CI bundle metadata format.'
}

function Get-GitlinkRevision([string]$Path) {
    $entry = (& git -C $root ls-tree HEAD -- $Path) -join "`n"
    if ($LASTEXITCODE -ne 0 -or $entry -notmatch '^160000\s+commit\s+([0-9a-f]{40})\s+') {
        throw "Unable to resolve root gitlink: $Path"
    }
    return $Matches[1]
}

$backendGitlink = Get-GitlinkRevision 'backend'
$tradingGitlink = Get-GitlinkRevision 'trading-engine'
if ($metadata.backend_gitlink -cne $backendGitlink) {
    throw "Pinned bundle backend revision does not match the root gitlink: $($metadata.backend_gitlink) != $backendGitlink"
}
if ($metadata.trading_gitlink -cne $tradingGitlink) {
    throw "Pinned bundle trading revision does not match the root gitlink: $($metadata.trading_gitlink) != $tradingGitlink"
}

$manifestLines = @(Get-Content -LiteralPath $manifestPath)
if ($manifestLines.Count -lt 2 -or $manifestLines[0] -cne 'idea2strategy-flyway-bundle-v1') {
    throw 'Invalid pinned Flyway bundle manifest.'
}

$runtimeGrantEntries = @($manifestLines | Where-Object { $_ -match '^R__database_runtime_grants\.sql\t[0-9a-f]{64}$' })
if ($runtimeGrantEntries.Count -ne 1) {
    throw 'The pinned Flyway manifest must contain exactly one generated runtime grant migration.'
}
$runtimeGrantPath = Join-Path $bundle 'R__database_runtime_grants.sql'
$runtimeGrantSql = Get-Content -LiteralPath $runtimeGrantPath -Raw
foreach ($role in @('backend', 'batch', 'trading', 'backtest', 'pipeline')) {
    $hardenedRole = "ALTER ROLE idea2strategy_$role NOLOGIN NOCREATEDB NOCREATEROLE NOINHERIT;"
    if (-not $runtimeGrantSql.Contains($hardenedRole)) {
        throw "Runtime grant migration is missing the hardened $role group role."
    }
    if (-not $runtimeGrantSql.Contains("application group role idea2strategy_$role has forbidden privileged attributes")) {
        throw "Runtime grant migration is missing the fail-closed privilege check for $role."
    }
}
if ($runtimeGrantSql.Contains('ALTER ROLE idea2strategy_backend NOLOGIN NOSUPERUSER')) {
    throw 'Runtime grant migration must not require PostgreSQL superuser-only ALTER ROLE clauses on RDS.'
}
if (-not $runtimeGrantSql.Contains('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE "identity"."accounts" TO idea2strategy_backend;')) {
    throw 'Runtime grant migration is missing the representative Backend identity ACL.'
}

function Get-Sha256OfText([string]$Text) {
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($Text)
        return ([System.BitConverter]::ToString($sha256.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    } finally {
        $sha256.Dispose()
    }
}

function Get-NormalizedTextSha256([string]$Path) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $normalized = New-Object System.IO.MemoryStream
    for ($index = 0; $index -lt $bytes.Length; $index++) {
        if ($bytes[$index] -eq 13 -and $index + 1 -lt $bytes.Length -and $bytes[$index + 1] -eq 10) {
            $normalized.WriteByte(10)
            $index++
        } else {
            $normalized.WriteByte($bytes[$index])
        }
    }
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($sha256.ComputeHash($normalized.ToArray()))).Replace('-', '').ToLowerInvariant()
    } finally {
        $sha256.Dispose()
        $normalized.Dispose()
    }
}

foreach ($line in $manifestLines[1..($manifestLines.Count - 1)]) {
    if ($line -notmatch '^([^\t]+\.sql)\t([0-9a-f]{64})$') {
        throw "Invalid pinned Flyway manifest entry: $line"
    }
    $migrationPath = Join-Path $bundle $Matches[1]
    if (-not (Test-Path -LiteralPath $migrationPath -PathType Leaf)) {
        throw "Pinned Flyway migration is missing: $($Matches[1])"
    }
    $actualHash = Get-NormalizedTextSha256 $migrationPath
    if ($actualHash -cne $Matches[2]) {
        throw "Pinned Flyway migration hash mismatch: $($Matches[1])"
    }
}

$manifestDigest = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
$recordedDigest = (Get-Content -LiteralPath $digestPath -Raw).Trim()
if ($manifestDigest -cne $recordedDigest -or $recordedDigest -cne $metadata.bundle_sha256) {
    throw 'Pinned Flyway bundle digest does not match its manifest or source metadata.'
}

# The trading engine owns no canonical DDL, so its read projections can only be proven here.
# This digest pins the copy taken from the trading contribution at the recorded gitlink.
$recordedReadContractDigest = $metadata.trading_read_projection_contract_sha256
if ([string]::IsNullOrWhiteSpace($recordedReadContractDigest)) {
    throw 'Pinned bundle metadata does not record the trading read projection contract digest.'
}
$actualReadContractDigest = Get-NormalizedTextSha256 $readContractFixture
if ($actualReadContractDigest -cne $recordedReadContractDigest) {
    throw 'The trading read projection contract fixture does not match its recorded digest.'
}

# The trading engine vendors this bundle as db/canonical-baseline so its own write-path tests can
# stand up the canonical schema. Root CI checks out without submodules, so that copy is not present
# here. It does not need to be: the baseline manifest is a deterministic function of these exact
# migrations, so recomputing it proves whether the pinned copy is still in step with this bundle.
# The trading engine's CanonicalBaselineContractTest guards the other direction, file by file.
$recordedBaselineDigest = $metadata.canonical_baseline_sha256
if ([string]::IsNullOrWhiteSpace($recordedBaselineDigest)) {
    throw 'Pinned bundle metadata does not record the vendored canonical baseline digest.'
}
$baselineManifest = "idea2strategy-canonical-baseline-v1`n"
foreach ($migration in (Get-ChildItem -LiteralPath $bundle -Filter '*.sql' | Sort-Object -Property Name -CaseSensitive)) {
    $baselineManifest += "$($migration.Name)`t$(Get-NormalizedTextSha256 $migration.FullName)`n"
}
$expectedBaselineDigest = Get-Sha256OfText $baselineManifest
if ($expectedBaselineDigest -cne $recordedBaselineDigest) {
    throw ("The vendored canonical baseline is out of step with this bundle: expected " +
        "$expectedBaselineDigest but the metadata records $recordedBaselineDigest. Refresh " +
        'db/canonical-baseline in the trading engine and record its new digest in the same change.')
}

$suffix = [guid]::NewGuid().ToString('N').Substring(0, 12)
$container = "idea2strategy-ci-migration-$suffix"
$database = 'idea2strategy'
$user = 'idea2strategy'
$password = "migration-$suffix"

function Invoke-Flyway([string]$Command, [switch]$Json) {
    $arguments = @(
        'run', '--rm',
        '--network', "container:$container",
        '-v', "${bundle}:/flyway/sql:ro",
        'redgate/flyway:11-alpine',
        "-url=jdbc:postgresql://localhost:5432/$database",
        "-user=$user",
        "-password=$password",
        '-connectRetries=30'
    )
    if ($Json) {
        $arguments += '-outputType=json'
    }
    $arguments += $Command
    $output = & docker @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Flyway $Command failed."
    }
    return $output
}

try {
    $started = docker run -d `
        --name $container `
        --health-cmd "pg_isready -U $user -d $database" `
        --health-interval 2s `
        --health-timeout 2s `
        --health-retries 30 `
        -e "POSTGRES_DB=$database" `
        -e "POSTGRES_USER=$user" `
        -e "POSTGRES_PASSWORD=$password" `
        postgres:16-alpine
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($started)) {
        throw 'Failed to start the temporary PostgreSQL container.'
    }

    $healthy = $false
    for ($attempt = 0; $attempt -lt 45; $attempt++) {
        $health = (docker inspect --format '{{.State.Health.Status}}' $container 2>$null).Trim()
        if ($health -eq 'healthy') {
            $healthy = $true
            break
        }
        if ($health -eq 'unhealthy') {
            throw 'Temporary PostgreSQL became unhealthy.'
        }
        Start-Sleep -Seconds 2
    }
    if (-not $healthy) {
        throw 'Timed out waiting for temporary PostgreSQL.'
    }

    Invoke-Flyway 'migrate' | Out-Host
    Invoke-Flyway 'validate' | Out-Host

    $historyBeforeSecondRun = (docker exec -e "PGPASSWORD=$password" $container `
        psql -U $user -d $database -Atc `
        'SELECT count(*) FROM flyway_schema_history WHERE success;').Trim()
    Invoke-Flyway 'migrate' | Out-Host
    $historyAfterSecondRun = (docker exec -e "PGPASSWORD=$password" $container `
        psql -U $user -d $database -Atc `
        'SELECT count(*) FROM flyway_schema_history WHERE success;').Trim()
    if ($LASTEXITCODE -ne 0 -or $historyAfterSecondRun -ne $historyBeforeSecondRun) {
        throw 'The second Flyway migrate applied an unexpected migration.'
    }

    $infoOutput = (Invoke-Flyway 'info' -Json) -join "`n"
    if ($infoOutput -match '(?i)"state"\s*:\s*"pending"') {
        throw 'Flyway reports a pending migration after the second migrate.'
    }

    $schemaList = "'identity','strategy','bot','storage','market_data','trading','backtest','performance','competition','operations'"
    $tableCount = (docker exec -e "PGPASSWORD=$password" $container `
        psql -U $user -d $database -Atc `
        "SELECT count(*) FROM information_schema.tables WHERE table_schema IN ($schemaList) AND table_type = 'BASE TABLE';").Trim()
    if ($LASTEXITCODE -ne 0 -or $tableCount -ne '177') {
        throw "Expected 177 application tables after Flyway; found '$tableCount'."
    }

    docker cp $fixture "${container}:/tmp/partial_fill_allocation_contract.sql"
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to copy the partial-fill allocation contract fixture into PostgreSQL.'
    }
    docker exec -e "PGPASSWORD=$password" $container `
        psql -v ON_ERROR_STOP=1 -U $user -d $database `
        -f /tmp/partial_fill_allocation_contract.sql | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw 'The partial-fill allocation contract fixture failed.'
    }

    docker cp $readContractFixture "${container}:/tmp/trading_read_projection_contract.sql"
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to copy the trading read projection contract fixture into PostgreSQL.'
    }
    docker exec -e "PGPASSWORD=$password" $container `
        psql -v ON_ERROR_STOP=1 -U $user -d $database `
        -f /tmp/trading_read_projection_contract.sql | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw 'The trading read projection contract fixture failed.'
    }

    docker cp $runtimeGrantsFixture "${container}:/tmp/runtime_grants_contract.sql"
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to copy the runtime grant contract fixture into PostgreSQL.'
    }
    docker exec -e "PGPASSWORD=$password" $container `
        psql -v ON_ERROR_STOP=1 -U $user -d $database `
        -f /tmp/runtime_grants_contract.sql | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw 'The runtime grant contract fixture failed.'
    }

    [pscustomobject]@{
        status = 'passed'
        application_tables = [int]$tableCount
        successful_migrations = [int]$historyAfterSecondRun
        second_run_pending = 0
        partial_fill_allocation_contract = 'passed'
        trading_read_projection_contract = 'passed'
        runtime_grants_contract = 'passed'
        bundle_sha256 = $recordedDigest
        backend_revision = $backendGitlink
        trading_revision = $tradingGitlink
        postgres = '16-alpine'
        flyway = '11-alpine'
    } | ConvertTo-Json -Compress
} finally {
    docker rm -f $container *> $null
}
