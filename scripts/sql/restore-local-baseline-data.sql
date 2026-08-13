\set ON_ERROR_STOP on

CREATE EXTENSION IF NOT EXISTS postgres_fdw;
DROP SERVER IF EXISTS idea2strategy_backup_stage CASCADE;
CREATE SERVER idea2strategy_backup_stage
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host '127.0.0.1', port '5432', dbname 'idea2strategy_backup_stage');
CREATE USER MAPPING FOR CURRENT_USER
    SERVER idea2strategy_backup_stage
    OPTIONS (user :'backup_user', password :'backup_password');

DROP SCHEMA IF EXISTS backup_market_data CASCADE;
DROP SCHEMA IF EXISTS backup_storage CASCADE;
CREATE SCHEMA backup_market_data;
CREATE SCHEMA backup_storage;
IMPORT FOREIGN SCHEMA market_data LIMIT TO (
    providers, feeds, instruments, instrument_symbols, trading_sessions,
    pipeline_runs, dataset_manifests, dataset_objects, dataset_lineage
) FROM SERVER idea2strategy_backup_stage INTO backup_market_data;
IMPORT FOREIGN SCHEMA storage LIMIT TO (objects)
    FROM SERVER idea2strategy_backup_stage INTO backup_storage;

BEGIN;
SET CONSTRAINTS ALL DEFERRED;

INSERT INTO market_data.providers (id, code, display_name, rights_version, status, created_at)
SELECT id, code, name, rights_version, status, created_at
FROM backup_market_data.providers
ON CONFLICT (id) DO NOTHING;

INSERT INTO market_data.feeds (
    id, provider_id, code, data_kind, resolution, timezone_name, feed_version, created_at, retired_at
)
SELECT id, provider_id, code, data_kind, resolution, 'America/New_York',
       'legacy-' || lower(resolution), created_at,
       CASE WHEN status = 'ACTIVE' THEN NULL ELSE created_at END
FROM backup_market_data.feeds
ON CONFLICT (id) DO NOTHING;

INSERT INTO market_data.instruments (
    id, asset_type, primary_exchange_mic, currency_code, provider_reference,
    listed_at, delisted_at, created_at
)
SELECT i.id, i.asset_type::text::market_data.asset_type, i.primary_exchange_mic,
       i.currency, symbol.symbol, i.listed_from, i.listed_to, i.created_at
FROM backup_market_data.instruments i
LEFT JOIN LATERAL (
    SELECT s.symbol FROM backup_market_data.instrument_symbols s
    WHERE s.instrument_id = i.id ORDER BY s.effective_from DESC LIMIT 1
) symbol ON true
ON CONFLICT (id) DO NOTHING;

INSERT INTO market_data.instrument_symbols (
    id, instrument_id, exchange_mic, symbol, effective_from, effective_to
)
SELECT id, instrument_id, exchange_mic, symbol,
       effective_from::timestamp AT TIME ZONE 'UTC',
       CASE WHEN effective_to IS NULL THEN NULL ELSE effective_to::timestamp AT TIME ZONE 'UTC' END
FROM backup_market_data.instrument_symbols
ON CONFLICT (id) DO NOTHING;

INSERT INTO market_data.trading_sessions (
    id, exchange_mic, session_date, opens_at, closes_at, session_type, calendar_version
)
SELECT id, exchange_mic, session_date, opens_at, closes_at, session_type, calendar_version
FROM backup_market_data.trading_sessions
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.objects (
    id, status, storage_provider, bucket_name, object_key, provider_version_id,
    content_hash, byte_size, file_format, compression_codec, media_type,
    schema_version, row_count, period_start, period_end, encryption_key_ref,
    retention_policy_version, legal_hold, created_at, verified_at
)
SELECT o.id, 'AVAILABLE'::storage.object_status, 'MINIO', :'local_bucket', o.object_key,
       o.provider_version_id, o.content_sha256, o.byte_size, 'PARQUET', 'SNAPPY',
       o.media_type, o.format_version, legacy_object.row_count,
       legacy_manifest.period_start::timestamp AT TIME ZONE 'UTC',
       legacy_manifest.period_end::timestamp AT TIME ZONE 'UTC',
       o.encryption_profile, 'local-baseline-v1', false, o.created_at, o.verified_at
FROM backup_storage.objects o
LEFT JOIN backup_market_data.dataset_objects legacy_object ON legacy_object.object_id = o.id
LEFT JOIN backup_market_data.dataset_manifests legacy_manifest
       ON legacy_manifest.id = legacy_object.dataset_manifest_id
ON CONFLICT (id) DO NOTHING;

INSERT INTO market_data.pipeline_runs (
    id, pipeline_code, pipeline_version, idempotency_key, status,
    input_hash, output_hash, started_at, completed_at, failure_code
)
SELECT id, pipeline_type, processing_version, idempotency_key, status::text::operations.work_status,
       md5(input_config::text), CASE WHEN summary_result IS NULL THEN NULL ELSE md5(summary_result::text) END,
       started_at, completed_at, failure_code
FROM backup_market_data.pipeline_runs
ON CONFLICT (id) DO NOTHING;

INSERT INTO market_data.dataset_manifests (
    id, feed_id, instrument_id, data_layer, resolution, revision_number, status,
    period_start, period_end, schema_version, dataset_hash, supersedes_manifest_id,
    created_at, available_at, object_count
)
SELECT id, feed_id, instrument_id, data_layer, resolution, revision_number,
       status::text::market_data.dataset_status,
       period_start::timestamp AT TIME ZONE 'UTC', period_end::timestamp AT TIME ZONE 'UTC',
       processing_version, manifest_hash, supersedes_manifest_id, created_at,
       CASE WHEN status::text = 'AVAILABLE' THEN as_of_at ELSE NULL END, 0
FROM backup_market_data.dataset_manifests
ON CONFLICT (id) DO NOTHING;

INSERT INTO market_data.dataset_objects (
    id, dataset_manifest_id, object_id, object_kind, partition_granularity,
    partition_start, partition_end, period_start, period_end, shard_key,
    part_number, row_count, min_instrument_id, max_instrument_id
)
SELECT o.id, o.dataset_manifest_id, o.object_id, o.object_kind,
       CASE
           WHEN m.period_end = m.period_start + 1 THEN 'DAY'
           WHEN m.period_end = m.period_start + 7 THEN 'WEEK'
           WHEN m.period_end = (m.period_start + interval '1 month')::date THEN 'MONTH'
           ELSE 'YEAR'
       END::market_data.partition_granularity,
       m.period_start, m.period_end,
       m.period_start::timestamp AT TIME ZONE 'UTC', m.period_end::timestamp AT TIME ZONE 'UTC',
       COALESCE(substring(o.partition_key from 'shard=([^/]+)'), 'unsharded'),
       COALESCE((substring(o.partition_key from 'shard=([0-9]+)'))::integer, 0),
       o.row_count, NULL, NULL
FROM backup_market_data.dataset_objects o
JOIN backup_market_data.dataset_manifests m ON m.id = o.dataset_manifest_id
ON CONFLICT (id) DO NOTHING;

INSERT INTO market_data.dataset_lineage (derived_manifest_id, source_manifest_id, relation_type)
SELECT dataset_manifest_id, source_manifest_id, relationship_type
FROM backup_market_data.dataset_lineage
ON CONFLICT DO NOTHING;

COMMIT;

DROP SERVER idea2strategy_backup_stage CASCADE;
DROP SCHEMA backup_market_data CASCADE;
DROP SCHEMA backup_storage CASCADE;
