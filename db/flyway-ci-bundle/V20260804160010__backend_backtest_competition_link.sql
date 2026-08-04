ALTER TABLE competition.backtest_period_runs
    DROP CONSTRAINT backtest_period_runs_pkey,
    ADD CONSTRAINT backtest_period_runs_pkey
        PRIMARY KEY (participation_id, evaluation_period_id, run_id),
    ADD CONSTRAINT backtest_period_runs_participation_period_unique
        UNIQUE (participation_id, evaluation_period_id);
