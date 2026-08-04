[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function Require-Text([string]$Path, [string[]]$Patterns) {
    $absolute = Join-Path $root $Path
    if (-not (Test-Path -LiteralPath $absolute -PathType Leaf)) {
        throw "Deploy-ready contract is missing: $Path"
    }
    $content = Get-Content -LiteralPath $absolute -Raw
    foreach ($pattern in $Patterns) {
        if ($content -notmatch $pattern) {
            throw "Deploy-ready contract boundary is missing from ${Path}: $pattern"
        }
    }
}

Require-Text "contracts/data/backtest-execution.v1.md" @(
    'BASIC', 'CUSTOM', 'COMPETITION', '2/1/1', 'idempotency',
    'claimExpiresAt', 'heartbeat', 'cancellation', 'manifest'
)
Require-Text "contracts/data/market-data-publication.v1.md" @(
    'content-addressed', 'AVAILABLE', 'watermark', 'corporate action',
    'idempotency', 'PostgreSQL', 'S3'
)
Require-Text "contracts/business/virtual-trading-scope.v1.md" @(
    'Alpaca SIP', 'virtual', 'live broker', 'fails? closed', 'reconcile',
    'ROOM_EVALUATION_ACCOUNT_OPEN_REQUESTED', 'room-evaluation-account-opened\.v1',
    'room-evaluation-account-open-rejected\.v1', 'PENDING_LEDGER',
    'producerIdempotencyKey', 'payloadHash', 'botEventSequence', 'CASH', 'CAPITAL',
    'Out-of-order facts', 'bot-wide ledger entries cannot outlive'
)
Require-Text "contracts/registry.yaml" @(
    'contract\.backtest\.execution\.v1',
    'contract\.market-data\.publication\.v1',
    'contract\.trading\.virtual-execution\.v1'
)
Require-Text "specs/product/capabilities/capability.backtest.automatic.md" @(
    'user-selected period', 'official BACKTEST competition'
)
Require-Text "specs/product/journeys/journey.backtest.review.md" @(
    'automatic', 'user-selected period', 'competition'
)
Require-Text "db/schema.dbml" @(
    'start_event_sequence bigint\r?\n',
    'initial_state_hash varchar\(128\)\r?\n',
    '\(start_event_sequence IS NULL AND initial_state_hash IS NULL\) OR \(start_event_sequence IS NOT NULL AND initial_state_hash IS NOT NULL\)',
    'start_event_sequence IS NULL OR start_event_sequence > 0'
)

Write-Output "Deploy-ready protected contract boundary checks passed."
