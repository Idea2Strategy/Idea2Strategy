[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceBundle,

    [Parameter(Mandatory = $true)]
    [string]$Output,

    [switch]$VerifyOnly,

    [switch]$KeepTemporary
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
function Resolve-AbsolutePath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Path))
}

$sourceBundlePath = Resolve-AbsolutePath $SourceBundle
$outputPath = Resolve-AbsolutePath $Output
$requiredBaseline = Join-Path $sourceBundlePath 'V1__initial_schema.sql'

if (-not (Test-Path -LiteralPath $sourceBundlePath -PathType Container)) {
    throw "Source Flyway bundle directory is missing: $sourceBundlePath"
}
if (-not (Test-Path -LiteralPath $requiredBaseline -PathType Leaf)) {
    throw "Source Flyway bundle is missing V1__initial_schema.sql: $requiredBaseline"
}
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    throw 'Docker is required to generate the V1 baseline.'
}

$runId = [Guid]::NewGuid().ToString('N').Substring(0, 12)
$network = "i2s-v1-$runId"
$sourceContainer = "i2s-v1-source-$runId"
$targetContainer = "i2s-v1-target-$runId"
$database = 'idea2strategy_v1'
$password = [Convert]::ToBase64String(([Guid]::NewGuid().ToByteArray())).Replace('=', 'A')
$temporaryRoot = Join-Path $root ".local/tmp/v1-rebaseline-$runId"
$generatedBaseline = Join-Path $temporaryRoot 'V1__initial_schema.sql'
$sourceSchema = Join-Path $temporaryRoot 'source-schema.part'
$sourceData = Join-Path $temporaryRoot 'source-data.part'
$sourceFull = Join-Path $temporaryRoot 'source-full.part'
$targetSchema = Join-Path $temporaryRoot 'target-schema.part'
$targetData = Join-Path $temporaryRoot 'target-data.part'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Invoke-Docker([string[]]$Arguments) {
    & docker @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Docker command failed with exit code $LASTEXITCODE."
    }
}

function Invoke-DockerText([string[]]$Arguments) {
    $lines = @(& docker @Arguments)
    if ($LASTEXITCODE -ne 0) {
        throw "Docker command failed with exit code $LASTEXITCODE."
    }
    return (($lines -join "`n") + "`n")
}

function Write-NormalizedDump([string]$Path, [string]$Content) {
    $normalizedLines = foreach ($line in ($Content -replace "`r`n", "`n" -split "`n")) {
        if ($line -match '^\\(un)?restrict\s+') {
            continue
        }
        if ($line -match '^-- Dumped (from database version|by pg_dump version)') {
            continue
        }
        $line
    }
    $normalized = (($normalizedLines -join "`n").TrimEnd() + "`n")
    [System.IO.File]::WriteAllText($Path, $normalized, $utf8)
}

function Start-Postgres([string]$Name) {
    Invoke-Docker @(
        'run', '-d', '--name', $Name, '--network', $network,
        '-e', "POSTGRES_PASSWORD=$password",
        '-e', "POSTGRES_DB=$database",
        '-v', "${temporaryRoot}:/work",
        'postgres:16-alpine'
    ) | Out-Null

    $deadline = (Get-Date).AddMinutes(2)
    do {
        & docker exec $Name pg_isready -U postgres -d $database *> $null
        if ($LASTEXITCODE -eq 0) {
            return
        }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)

    throw "PostgreSQL container did not become ready: $Name"
}

function Invoke-Flyway([string]$Container, [string]$MigrationDirectory) {
    Invoke-Docker @(
        'run', '--rm', '--network', $network,
        '-v', "${MigrationDirectory}:/flyway/sql:ro",
        'redgate/flyway:11-alpine',
        "-url=jdbc:postgresql://${Container}:5432/$database",
        '-user=postgres', "-password=$password",
        '-connectRetries=30', 'migrate'
    )
}

function Export-Database(
    [string]$Container,
    [string]$Prefix,
    [string]$SchemaPath,
    [string]$DataPath,
    [string]$FullPath
) {
    $base = "pg_dump -U postgres -d $database --no-owner --no-privileges " +
        '--exclude-table=public.flyway_schema_history'
    Invoke-Docker @(
        'exec', '-e', "PGPASSWORD=$password", $Container,
        'sh', '-c', "$base --schema-only > /work/$Prefix-schema.raw"
    ) | Out-Null
    Invoke-Docker @(
        'exec', '-e', "PGPASSWORD=$password", $Container,
        'sh', '-c', "$base --data-only > /work/$Prefix-data.raw"
    ) | Out-Null
    if (-not [string]::IsNullOrWhiteSpace($FullPath)) {
        Invoke-Docker @(
            'exec', '-e', "PGPASSWORD=$password", $Container,
            'sh', '-c', "$base > /work/$Prefix-full.raw"
        ) | Out-Null
    }

    Write-NormalizedDump $SchemaPath ([System.IO.File]::ReadAllText(
        (Join-Path $temporaryRoot "$Prefix-schema.raw"), [System.Text.Encoding]::UTF8))
    Write-NormalizedDump $DataPath ([System.IO.File]::ReadAllText(
        (Join-Path $temporaryRoot "$Prefix-data.raw"), [System.Text.Encoding]::UTF8))
    if (-not [string]::IsNullOrWhiteSpace($FullPath)) {
        Write-NormalizedDump $FullPath ([System.IO.File]::ReadAllText(
            (Join-Path $temporaryRoot "$Prefix-full.raw"), [System.Text.Encoding]::UTF8))
    }
}

function Get-FileDigest([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-TextDigest([string]$Content) {
    $bytes = $utf8.GetBytes(($Content -replace "`r`n", "`n"))
    $hash = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($hash.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    } finally {
        $hash.Dispose()
    }
}

function Invoke-PostgresText([string]$Container, [string]$Sql) {
    return Invoke-DockerText @(
        'exec', '-e', "PGPASSWORD=$password", $Container,
        'psql', '-U', 'postgres', '-d', $database,
        '-X', '-A', '-t', '-F', '|', '-v', 'ON_ERROR_STOP=1', '-c', $Sql
    )
}

function Get-SchemaFingerprint([string]$Container) {
    $sql = @'
WITH application_schemas(schema_name) AS (
    VALUES ('identity'),('strategy'),('market_data'),('storage'),('backtest'),
           ('bot'),('trading'),('competition'),('performance'),('operations')
), facts AS (
    SELECT 'column' AS kind,
           concat_ws('|', c.table_schema, c.table_name, c.column_name,
                     c.data_type, c.udt_schema, c.udt_name, c.is_nullable,
                     coalesce(c.column_default, '')) AS fact
    FROM information_schema.columns c JOIN application_schemas s ON s.schema_name = c.table_schema
    UNION ALL
    SELECT 'relation', concat_ws('|', n.nspname, cl.relname, cl.relkind)
    FROM pg_class cl JOIN pg_namespace n ON n.oid = cl.relnamespace
    JOIN application_schemas s ON s.schema_name = n.nspname
    WHERE cl.relkind IN ('r','p','v','m','S')
    UNION ALL
    SELECT 'enum', concat_ws('|', n.nspname, t.typname,
                             row_number() OVER (PARTITION BY t.oid ORDER BY e.enumsortorder), e.enumlabel)
    FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
    JOIN pg_enum e ON e.enumtypid = t.oid JOIN application_schemas s ON s.schema_name = n.nspname
    UNION ALL
    SELECT 'constraint', concat_ws('|', n.nspname, cl.relname, con.conname, con.contype,
                                   ARRAY(SELECT a.attname FROM unnest(con.conkey) WITH ORDINALITY key(attnum, ord)
                                         JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = key.attnum
                                         ORDER BY key.ord)::text,
                                   coalesce(con.confrelid::regclass::text, ''),
                                   ARRAY(SELECT a.attname FROM unnest(con.confkey) WITH ORDINALITY key(attnum, ord)
                                         JOIN pg_attribute a ON a.attrelid = con.confrelid AND a.attnum = key.attnum
                                         ORDER BY key.ord)::text)
    FROM pg_constraint con JOIN pg_class cl ON cl.oid = con.conrelid
    JOIN pg_namespace n ON n.oid = cl.relnamespace JOIN application_schemas s ON s.schema_name = n.nspname
    UNION ALL
    SELECT 'index', concat_ws('|', n.nspname, cl.relname, idx.relname, i.indisunique, i.indisprimary,
                              ARRAY(SELECT pg_get_indexdef(i.indexrelid, key_position, true)
                                    FROM generate_series(1, i.indnkeyatts) key_position)::text,
                              pg_get_expr(i.indpred, i.indrelid))
    FROM pg_index i JOIN pg_class cl ON cl.oid = i.indrelid JOIN pg_class idx ON idx.oid = i.indexrelid
    JOIN pg_namespace n ON n.oid = cl.relnamespace JOIN application_schemas s ON s.schema_name = n.nspname
    UNION ALL
    SELECT 'trigger', concat_ws('|', n.nspname, cl.relname, tg.tgname, pg_get_triggerdef(tg.oid, true))
    FROM pg_trigger tg JOIN pg_class cl ON cl.oid = tg.tgrelid JOIN pg_namespace n ON n.oid = cl.relnamespace
    JOIN application_schemas s ON s.schema_name = n.nspname WHERE NOT tg.tgisinternal
    UNION ALL
    SELECT 'function', concat_ws('|', n.nspname, p.proname, pg_get_function_identity_arguments(p.oid),
                                 pg_get_function_result(p.oid), p.prokind)
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    JOIN application_schemas s ON s.schema_name = n.nspname
)
SELECT kind || '|' || fact FROM facts ORDER BY kind, fact;
'@
    $facts = Invoke-PostgresText $Container $sql
    $label = if ($Container -eq $sourceContainer) { 'source' } else { 'target' }
    [System.IO.File]::WriteAllText(
        (Join-Path $temporaryRoot "$label-schema-facts.txt"), $facts, $utf8)
    return Get-TextDigest $facts
}

function Get-SeedDataFingerprint([string]$Container) {
    $sql = @'
CREATE TEMP TABLE seed_fingerprints (
    table_name text PRIMARY KEY,
    row_count bigint NOT NULL,
    content_hash text NOT NULL
);
DO $fingerprint$
DECLARE
    item record;
    counted bigint;
    hashed text;
BEGIN
    FOR item IN
        SELECT schemaname, tablename
        FROM pg_tables
        WHERE schemaname IN ('identity','strategy','market_data','storage','backtest',
                             'bot','trading','competition','performance','operations')
        ORDER BY schemaname, tablename
    LOOP
        EXECUTE format(
            'SELECT count(*), md5(coalesce(string_agg(row_json, E''\n'' ORDER BY row_json), '''')) '
            'FROM (SELECT row_to_json(value)::text AS row_json FROM %I.%I value) rows',
            item.schemaname, item.tablename
        ) INTO counted, hashed;
        INSERT INTO seed_fingerprints VALUES (
            item.schemaname || '.' || item.tablename, counted, hashed
        );
    END LOOP;
END
$fingerprint$;
SELECT table_name || '|' || row_count || '|' || content_hash
FROM seed_fingerprints ORDER BY table_name;
'@
    $facts = Invoke-PostgresText $Container $sql
    $label = if ($Container -eq $sourceContainer) { 'source' } else { 'target' }
    [System.IO.File]::WriteAllText(
        (Join-Path $temporaryRoot "$label-seed-facts.txt"), $facts, $utf8)
    return Get-TextDigest $facts
}

New-Item -ItemType Directory -Path $temporaryRoot -Force | Out-Null
try {
    Invoke-Docker @('network', 'create', $network) | Out-Null
    Start-Postgres $sourceContainer
    Invoke-Flyway $sourceContainer $sourceBundlePath
    Export-Database $sourceContainer 'source' $sourceSchema $sourceData $sourceFull

    $header = @(
        '-- Idea2Strategy pre-launch V1 baseline.',
        '-- Generated from the last verified historical Flyway bundle.',
        '-- Future schema changes must use new timestamped Flyway migrations.',
        ''
    ) -join "`n"
    $baseline = $header + [System.IO.File]::ReadAllText($sourceFull, [System.Text.Encoding]::UTF8)
    [System.IO.File]::WriteAllText($generatedBaseline, ($baseline -replace "`r`n", "`n"), $utf8)

    Start-Postgres $targetContainer
    Invoke-Flyway $targetContainer $temporaryRoot
    Export-Database $targetContainer 'target' $targetSchema $targetData $null

    $sourceSchemaDigest = Get-SchemaFingerprint $sourceContainer
    $targetSchemaDigest = Get-SchemaFingerprint $targetContainer
    if ($sourceSchemaDigest -cne $targetSchemaDigest) {
        throw "Generated V1 schema differs from the historical bundle: source=$sourceSchemaDigest target=$targetSchemaDigest"
    }
    $sourceDataDigest = Get-SeedDataFingerprint $sourceContainer
    $targetDataDigest = Get-SeedDataFingerprint $targetContainer
    if ($sourceDataDigest -cne $targetDataDigest) {
        throw "Generated V1 seed data differs from the historical bundle: source=$sourceDataDigest target=$targetDataDigest"
    }

    if (-not $VerifyOnly) {
        $outputParent = Split-Path -Parent $outputPath
        if (-not (Test-Path -LiteralPath $outputParent -PathType Container)) {
            New-Item -ItemType Directory -Path $outputParent -Force | Out-Null
        }
        Copy-Item -LiteralPath $generatedBaseline -Destination $outputPath -Force
    }

    [pscustomobject]@{
        status = 'passed'
        output = if ($VerifyOnly) { $null } else { $outputPath }
        schema_sha256 = $sourceSchemaDigest
        seed_data_sha256 = $sourceDataDigest
        baseline_sha256 = Get-FileDigest $generatedBaseline
    } | ConvertTo-Json -Compress
} finally {
    & docker rm -f $sourceContainer $targetContainer *> $null
    & docker network rm $network *> $null
    if (-not $KeepTemporary -and (Test-Path -LiteralPath $temporaryRoot)) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    } elseif ($KeepTemporary) {
        Write-Warning "Preserved V1 generation diagnostics: $temporaryRoot"
    }
}
