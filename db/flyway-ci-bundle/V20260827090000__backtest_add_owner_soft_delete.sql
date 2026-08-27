ALTER TABLE backtest.runs
    ADD COLUMN deletion_requested_at timestamptz,
    ADD COLUMN deleted_at timestamptz;

ALTER TABLE backtest.runs
    ADD CONSTRAINT backtest_deletion_state_consistent
        CHECK (
            deleted_at IS NULL
            OR (deletion_requested_at IS NOT NULL AND deleted_at >= deletion_requested_at)
        ),
    ADD CONSTRAINT backtest_deleted_run_is_terminal
        CHECK (
            deleted_at IS NULL
            OR status IN ('COMPLETED', 'FAILED', 'UNAVAILABLE', 'CANCELLED')
        );

CREATE INDEX runs_owner_account_id_deleted_at_queued_at_idx
    ON backtest.runs (owner_account_id, deleted_at, queued_at DESC);

COMMENT ON COLUMN backtest.runs.deletion_requested_at IS
    'Owner-requested removal time. Running work remains durable until cooperative cancellation reaches a terminal state.';

COMMENT ON COLUMN backtest.runs.deleted_at IS
    'Soft-delete completion time. Deleted runs are hidden from owner APIs but retained as immutable execution evidence.';
