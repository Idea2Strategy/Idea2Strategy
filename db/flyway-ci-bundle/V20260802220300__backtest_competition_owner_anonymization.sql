ALTER TABLE backtest.runs
    ALTER COLUMN owner_account_id DROP NOT NULL,
    ADD COLUMN owner_anonymized_at timestamptz,
    ADD CONSTRAINT backtest_run_owner_state CHECK (
        (owner_account_id IS NOT NULL AND owner_anonymized_at IS NULL)
        OR (owner_account_id IS NULL AND owner_anonymized_at IS NOT NULL)
    );

CREATE FUNCTION backtest.anonymize_official_competition_run_owners(
    target_account_id uuid,
    anonymized_at timestamptz
)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    affected integer;
BEGIN
    UPDATE backtest.runs run
    SET owner_account_id = NULL,
        owner_anonymized_at = anonymized_at
    WHERE run.owner_account_id = target_account_id
      AND EXISTS (
          SELECT 1
          FROM competition.backtest_period_runs period_run
          JOIN competition.participations participation
            ON participation.id = period_run.participation_id
          WHERE period_run.run_id = run.id
            AND participation.owner_account_id = target_account_id
      );
    GET DIAGNOSTICS affected = ROW_COUNT;
    RETURN affected;
END;
$$;

COMMENT ON FUNCTION backtest.anonymize_official_competition_run_owners(uuid, timestamptz) IS
    'Backtest-owned, narrowly scoped command invoked inside the backend retention transaction for official competition evidence only.';
