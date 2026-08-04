ALTER TYPE backtest.run_status ADD VALUE IF NOT EXISTS 'CANCELLED';

DO $$
BEGIN
    CREATE TYPE backtest.run_lane AS ENUM ('BASIC', 'CUSTOM', 'COMPETITION');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;

ALTER TABLE backtest.runs
    ADD COLUMN lane backtest.run_lane,
    ADD COLUMN message_id uuid,
    ADD COLUMN canonical_payload_hash varchar(128),
    ADD COLUMN aggregate_sequence bigint,
    ADD COLUMN execution_policy_version varchar(80),
    ADD COLUMN idempotency_scope varchar(160),
    ADD COLUMN cancellation_requested_at timestamptz,
    ADD COLUMN cancellation_reason_code varchar(80),
    ADD COLUMN cancelled_at timestamptz;

CREATE TABLE backtest.execution_policy_versions (
    version varchar(80) PRIMARY KEY,
    policy_artifact_hash varchar(128) NOT NULL UNIQUE,
    policy_document jsonb NOT NULL,
    locked_at timestamptz NOT NULL,
    retired_at timestamptz,
    CONSTRAINT backtest_execution_policy_retirement_after_lock
        CHECK (retired_at IS NULL OR retired_at >= locked_at)
);

CREATE TABLE backtest.legacy_execution_policy_mappings (
    run_id uuid PRIMARY KEY REFERENCES backtest.runs(id) ON DELETE CASCADE,
    lane backtest.run_lane NOT NULL,
    message_id uuid NOT NULL,
    canonical_payload_hash varchar(128) NOT NULL,
    aggregate_sequence bigint NOT NULL CHECK (aggregate_sequence >= 1),
    execution_policy_version varchar(80) NOT NULL
        REFERENCES backtest.execution_policy_versions(version),
    idempotency_scope varchar(160) NOT NULL,
    pinned_policy_artifact_hash varchar(128) NOT NULL,
    reviewed_by varchar(160) NOT NULL,
    reviewed_at timestamptz NOT NULL
);

ALTER TABLE backtest.run_attempts
    ADD COLUMN claim_token uuid,
    ADD COLUMN worker_id varchar(160),
    ADD COLUMN claimed_at timestamptz,
    ADD COLUMN claim_expires_at timestamptz,
    ADD COLUMN last_heartbeat_at timestamptz,
    ADD COLUMN previous_attempt_id uuid,
    ADD COLUMN terminal_reason_code varchar(80),
    ADD CONSTRAINT backtest_attempt_previous_fk
        FOREIGN KEY (previous_attempt_id) REFERENCES backtest.run_attempts(id),
    ADD CONSTRAINT backtest_attempt_claim_fields_together CHECK (
        (claim_token IS NULL AND worker_id IS NULL AND claimed_at IS NULL
            AND claim_expires_at IS NULL AND last_heartbeat_at IS NULL)
        OR
        (claim_token IS NOT NULL AND worker_id IS NOT NULL AND claimed_at IS NOT NULL
            AND claim_expires_at IS NOT NULL AND last_heartbeat_at IS NOT NULL)
    ),
    ADD CONSTRAINT backtest_running_attempt_claim_expiry_after_activity CHECK (
        status <> 'RUNNING' OR claim_expires_at > GREATEST(claimed_at, last_heartbeat_at)
    ),
    ADD CONSTRAINT backtest_attempt_terminal_reason_only_terminal CHECK (
        terminal_reason_code IS NULL OR status IN ('SUCCEEDED', 'FAILED', 'CANCELLED', 'SKIPPED')
    );

CREATE UNIQUE INDEX uq_backtest_run_attempt_claim_token
    ON backtest.run_attempts(claim_token) WHERE claim_token IS NOT NULL;
CREATE INDEX ix_backtest_run_attempt_expiry
    ON backtest.run_attempts(run_id, claim_expires_at);

CREATE OR REPLACE FUNCTION backtest.validate_attempt_lineage()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.previous_attempt_id IS NOT NULL AND NOT EXISTS (
        SELECT 1
          FROM backtest.run_attempts previous
         WHERE previous.id = NEW.previous_attempt_id
           AND previous.run_id = NEW.run_id
           AND previous.attempt_number < NEW.attempt_number
    ) THEN
        RAISE EXCEPTION 'BACKTEST_ATTEMPT_LINEAGE_INVALID'
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END
$$;

CREATE CONSTRAINT TRIGGER backtest_attempt_lineage_guard
AFTER INSERT OR UPDATE OF run_id, attempt_number, previous_attempt_id
ON backtest.run_attempts
DEFERRABLE INITIALLY IMMEDIATE
FOR EACH ROW EXECUTE FUNCTION backtest.validate_attempt_lineage();
