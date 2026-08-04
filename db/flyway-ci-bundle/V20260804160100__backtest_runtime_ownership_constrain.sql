UPDATE backtest.runs run
   SET lane = mapping.lane,
       message_id = mapping.message_id,
       canonical_payload_hash = mapping.canonical_payload_hash,
       aggregate_sequence = mapping.aggregate_sequence,
       execution_policy_version = mapping.execution_policy_version,
       idempotency_scope = mapping.idempotency_scope
  FROM backtest.legacy_execution_policy_mappings mapping
 WHERE mapping.run_id = run.id;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM backtest.runs
         WHERE lane IS NULL
            OR message_id IS NULL
            OR canonical_payload_hash IS NULL
            OR aggregate_sequence IS NULL
            OR execution_policy_version IS NULL
            OR idempotency_scope IS NULL
    ) THEN
        RAISE EXCEPTION 'BACKTEST_EXECUTION_POLICY_MAPPING_REQUIRED'
            USING ERRCODE = '23514',
                  HINT = 'Migrate to V20260804160000, insert a reviewed mapping with a pinned policy artifact for every legacy run, then resume Flyway.';
    END IF;
END
$$;

UPDATE backtest.run_attempts
   SET terminal_reason_code = CASE status::text
       WHEN 'SUCCEEDED' THEN 'SUCCEEDED'
       WHEN 'FAILED' THEN COALESCE(failure_code, 'FAILED')
       WHEN 'CANCELLED' THEN 'CANCELLED'
       WHEN 'SKIPPED' THEN 'SKIPPED'
       ELSE terminal_reason_code
   END
 WHERE status IN ('SUCCEEDED', 'FAILED', 'CANCELLED', 'SKIPPED')
   AND terminal_reason_code IS NULL;

ALTER TABLE backtest.runs
    ALTER COLUMN lane SET NOT NULL,
    ALTER COLUMN message_id SET NOT NULL,
    ALTER COLUMN canonical_payload_hash SET NOT NULL,
    ALTER COLUMN aggregate_sequence SET NOT NULL,
    ALTER COLUMN execution_policy_version SET NOT NULL,
    ALTER COLUMN idempotency_scope SET NOT NULL,
    ADD CONSTRAINT backtest_aggregate_sequence_positive CHECK (aggregate_sequence >= 1),
    ADD CONSTRAINT backtest_cancellation_state_consistent CHECK (
        (cancellation_requested_at IS NULL AND cancellation_reason_code IS NULL AND cancelled_at IS NULL)
        OR
        (cancellation_requested_at IS NOT NULL AND cancellation_reason_code IS NOT NULL
            AND (cancelled_at IS NULL OR cancelled_at >= cancellation_requested_at))
    ),
    ADD CONSTRAINT backtest_cancelled_run_has_time CHECK (
        status <> 'CANCELLED' OR cancelled_at IS NOT NULL
    ),
    ADD CONSTRAINT backtest_success_not_cancelled CHECK (
        status <> 'COMPLETED' OR (cancelled_at IS NULL AND cancellation_requested_at IS NULL)
    ),
    ADD CONSTRAINT backtest_run_execution_policy_fk
        FOREIGN KEY (execution_policy_version)
        REFERENCES backtest.execution_policy_versions(version);

ALTER TABLE backtest.run_attempts
    ADD CONSTRAINT backtest_terminal_attempt_has_completion CHECK (
        status NOT IN ('SUCCEEDED', 'FAILED', 'CANCELLED', 'SKIPPED')
        OR (completed_at IS NOT NULL AND terminal_reason_code IS NOT NULL)
    );

ALTER TABLE backtest.runs DROP CONSTRAINT IF EXISTS runs_idempotency_key_key;
DROP INDEX IF EXISTS backtest.runs_idempotency_key_idx;

CREATE UNIQUE INDEX uq_backtest_run_message_id ON backtest.runs(message_id);
CREATE UNIQUE INDEX uq_backtest_run_idempotency
    ON backtest.runs(lane, idempotency_scope, idempotency_key);
CREATE INDEX ix_backtest_run_execution_policy
    ON backtest.runs(execution_policy_version, queued_at);
