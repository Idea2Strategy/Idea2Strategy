CREATE TYPE operations.batch_job_version_status AS ENUM ('DRAFT', 'ACTIVE', 'RETIRED');
CREATE TYPE operations.batch_run_status AS ENUM ('RUNNING', 'SUCCEEDED', 'PARTIAL_FAILED', 'FAILED', 'CANCELLED');
CREATE TYPE operations.batch_item_status AS ENUM ('PENDING', 'CLAIMED', 'SUCCEEDED', 'QUARANTINED', 'SKIPPED');
CREATE TYPE operations.batch_attempt_outcome AS ENUM ('SUCCEEDED', 'RETRY_SCHEDULED', 'QUARANTINED', 'LEASE_EXPIRED', 'SKIPPED');

CREATE TABLE operations.batch_job_versions (
    job_code varchar(80) NOT NULL,
    job_version varchar(40) NOT NULL,
    status operations.batch_job_version_status NOT NULL,
    category_set_document jsonb NOT NULL,
    content_hash varchar(128) NOT NULL UNIQUE,
    published_at timestamptz,
    retired_at timestamptz,
    CONSTRAINT batch_job_versions_pk PRIMARY KEY (job_code, job_version),
    CONSTRAINT batch_job_version_categories_array CHECK (jsonb_typeof(category_set_document) = 'array'),
    CONSTRAINT batch_job_version_lifecycle_consistent CHECK (
        (status = 'DRAFT' AND published_at IS NULL AND retired_at IS NULL)
        OR (status = 'ACTIVE' AND published_at IS NOT NULL AND retired_at IS NULL)
        OR (status = 'RETIRED' AND published_at IS NOT NULL AND retired_at IS NOT NULL AND retired_at >= published_at))
);
CREATE UNIQUE INDEX batch_job_one_active_version
    ON operations.batch_job_versions (job_code) WHERE status = 'ACTIVE';

CREATE TABLE operations.batch_runs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    job_code varchar(80) NOT NULL,
    job_version varchar(40) NOT NULL,
    runtime_policy_version varchar(80) NOT NULL,
    trigger_id varchar(160) NOT NULL UNIQUE,
    window_start timestamptz NOT NULL,
    window_end timestamptz NOT NULL,
    status operations.batch_run_status NOT NULL DEFAULT 'RUNNING',
    started_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    completed_at timestamptz,
    discovered_count bigint NOT NULL DEFAULT 0,
    succeeded_count bigint NOT NULL DEFAULT 0,
    quarantined_count bigint NOT NULL DEFAULT 0,
    CONSTRAINT batch_run_job_version_fk FOREIGN KEY (job_code, job_version)
        REFERENCES operations.batch_job_versions(job_code, job_version),
    CONSTRAINT batch_run_window_positive CHECK (window_end > window_start),
    CONSTRAINT batch_run_counts_nonnegative CHECK (
        discovered_count >= 0 AND succeeded_count >= 0 AND quarantined_count >= 0),
    CONSTRAINT batch_run_completion_consistent CHECK (
        (status = 'RUNNING' AND completed_at IS NULL)
        OR (status <> 'RUNNING' AND completed_at IS NOT NULL AND completed_at >= started_at))
);
CREATE INDEX batch_runs_job_started_idx ON operations.batch_runs (job_code, job_version, started_at);
CREATE INDEX batch_runs_status_started_idx ON operations.batch_runs (status, started_at);

CREATE TABLE operations.batch_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    discovered_by_run_id uuid NOT NULL REFERENCES operations.batch_runs(id),
    category_code varchar(80) NOT NULL,
    source_key varchar(200) NOT NULL,
    source_version varchar(160) NOT NULL,
    due_at timestamptz NOT NULL,
    replay_sequence integer NOT NULL DEFAULT 0,
    original_item_id uuid REFERENCES operations.batch_items(id),
    replayed_from_item_id uuid UNIQUE REFERENCES operations.batch_items(id),
    replay_audit_event_id uuid UNIQUE REFERENCES operations.audit_events(id),
    status operations.batch_item_status NOT NULL DEFAULT 'PENDING',
    claim_token uuid UNIQUE,
    claimed_by varchar(160),
    claimed_at timestamptz,
    claim_expires_at timestamptz,
    attempt_count integer NOT NULL DEFAULT 0,
    next_attempt_at timestamptz NOT NULL,
    correlation_id uuid NOT NULL,
    first_discovered_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    completed_at timestamptz,
    domain_result_code varchar(80),
    terminal_failure_code varchar(80),
    CONSTRAINT batch_item_stable_identity_unique UNIQUE
        (category_code, source_key, source_version, due_at, replay_sequence),
    CONSTRAINT batch_item_replay_sequence_nonnegative CHECK (replay_sequence >= 0),
    CONSTRAINT batch_item_replay_lineage_consistent CHECK (
        (replay_sequence = 0 AND original_item_id IS NULL AND replayed_from_item_id IS NULL AND replay_audit_event_id IS NULL)
        OR (replay_sequence > 0 AND original_item_id IS NOT NULL AND replayed_from_item_id IS NOT NULL AND replay_audit_event_id IS NOT NULL)),
    CONSTRAINT batch_item_attempt_count_nonnegative CHECK (attempt_count >= 0),
    CONSTRAINT batch_item_claim_consistent CHECK (
        (status = 'CLAIMED' AND claim_token IS NOT NULL AND claimed_by IS NOT NULL
            AND claimed_at IS NOT NULL AND claim_expires_at > claimed_at)
        OR (status <> 'CLAIMED' AND claim_token IS NULL AND claimed_by IS NULL
            AND claimed_at IS NULL AND claim_expires_at IS NULL)),
    CONSTRAINT batch_item_completion_consistent CHECK (
        (status IN ('SUCCEEDED', 'QUARANTINED', 'SKIPPED') AND completed_at IS NOT NULL)
        OR (status IN ('PENDING', 'CLAIMED') AND completed_at IS NULL)),
    CONSTRAINT batch_item_quarantine_consistent CHECK (
        (status = 'QUARANTINED' AND terminal_failure_code IS NOT NULL)
        OR (status <> 'QUARANTINED' AND terminal_failure_code IS NULL))
);
CREATE INDEX batch_items_claimable_idx
    ON operations.batch_items (status, next_attempt_at, due_at, id);
CREATE UNIQUE INDEX batch_item_replay_generation_unique
    ON operations.batch_items (original_item_id, replay_sequence) WHERE original_item_id IS NOT NULL;

CREATE TABLE operations.batch_item_attempts (
    batch_item_id uuid NOT NULL REFERENCES operations.batch_items(id),
    attempt_number integer NOT NULL,
    claim_token uuid NOT NULL UNIQUE,
    worker_id varchar(160) NOT NULL,
    runtime_policy_version varchar(80) NOT NULL,
    correlation_id uuid NOT NULL,
    claimed_at timestamptz NOT NULL,
    claim_expires_at timestamptz NOT NULL,
    completed_at timestamptz,
    outcome operations.batch_attempt_outcome,
    domain_result_code varchar(80),
    failure_code varchar(80),
    next_attempt_at timestamptz,
    CONSTRAINT batch_item_attempts_pk PRIMARY KEY (batch_item_id, attempt_number),
    CONSTRAINT batch_attempt_number_positive CHECK (attempt_number > 0),
    CONSTRAINT batch_attempt_lease_positive CHECK (claim_expires_at > claimed_at),
    CONSTRAINT batch_attempt_completion_consistent CHECK (
        (completed_at IS NULL AND outcome IS NULL AND domain_result_code IS NULL
            AND failure_code IS NULL AND next_attempt_at IS NULL)
        OR (completed_at IS NOT NULL AND outcome IS NOT NULL)),
    CONSTRAINT batch_attempt_retry_consistent CHECK (
        (outcome = 'RETRY_SCHEDULED' AND failure_code IS NOT NULL AND next_attempt_at IS NOT NULL)
        OR (outcome <> 'RETRY_SCHEDULED' AND next_attempt_at IS NULL) OR outcome IS NULL),
    CONSTRAINT batch_attempt_failure_consistent CHECK (
        (outcome IN ('QUARANTINED', 'LEASE_EXPIRED') AND failure_code IS NOT NULL)
        OR outcome NOT IN ('QUARANTINED', 'LEASE_EXPIRED') OR outcome IS NULL)
);
CREATE INDEX batch_item_attempts_outcome_idx
    ON operations.batch_item_attempts (outcome, completed_at);

CREATE TABLE operations.batch_run_checkpoints (
    job_code varchar(80) NOT NULL,
    job_version varchar(40) NOT NULL,
    category_code varchar(80) NOT NULL,
    shard_key varchar(160) NOT NULL,
    cursor_due_at timestamptz,
    cursor_source_key varchar(200),
    last_run_id uuid NOT NULL REFERENCES operations.batch_runs(id),
    scanned_count bigint NOT NULL DEFAULT 0,
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CONSTRAINT batch_run_checkpoints_pk PRIMARY KEY (job_code, job_version, category_code, shard_key),
    CONSTRAINT batch_checkpoint_job_version_fk FOREIGN KEY (job_code, job_version)
        REFERENCES operations.batch_job_versions(job_code, job_version),
    CONSTRAINT batch_checkpoint_cursor_pair CHECK (
        (cursor_due_at IS NULL AND cursor_source_key IS NULL)
        OR (cursor_due_at IS NOT NULL AND cursor_source_key IS NOT NULL)),
    CONSTRAINT batch_checkpoint_scanned_count_nonnegative CHECK (scanned_count >= 0)
);

COMMENT ON TABLE operations.batch_items IS
    'Durable non-sensitive batch work identity and current lease head; domain receipts remain authoritative.';
COMMENT ON TABLE operations.batch_run_checkpoints IS
    'Discovery optimization only; consumers must overlap-rescan and cannot treat a checkpoint as completion evidence.';
