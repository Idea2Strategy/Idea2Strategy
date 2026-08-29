WITH attempt_completion AS (
    SELECT run_id, max(completed_at) AS completed_at
      FROM backtest.run_attempts
     WHERE completed_at IS NOT NULL
     GROUP BY run_id
)
UPDATE backtest.runs run
   SET completed_at = GREATEST(
           COALESCE(attempt_completion.completed_at, run.started_at, run.queued_at),
           COALESCE(run.started_at, run.queued_at)
       ),
       cancelled_at = CASE
           WHEN run.cancelled_at IS NULL THEN NULL
           ELSE GREATEST(
               run.cancelled_at,
               COALESCE(run.started_at, run.queued_at)
           )
       END
  FROM attempt_completion
 WHERE attempt_completion.run_id = run.id
   AND run.completed_at IS NOT NULL
   AND run.completed_at < COALESCE(run.started_at, run.queued_at);

UPDATE backtest.run_attempts
   SET completed_at = GREATEST(
           completed_at,
           started_at,
           COALESCE(last_heartbeat_at, started_at)
       )
 WHERE completed_at IS NOT NULL
   AND completed_at < started_at;

ALTER TABLE backtest.runs
    ADD CONSTRAINT backtest_run_terminal_timestamp_ordered
        CHECK (
            completed_at IS NULL
            OR completed_at >= COALESCE(started_at, queued_at)
        );

ALTER TABLE backtest.run_attempts
    ADD CONSTRAINT backtest_attempt_terminal_timestamp_ordered
        CHECK (completed_at IS NULL OR completed_at >= started_at);

COMMENT ON CONSTRAINT backtest_run_terminal_timestamp_ordered ON backtest.runs IS
    'A terminal run timestamp cannot predate the durable queue/start timestamp; legacy local-clock rows were repaired from their final attempt.';
