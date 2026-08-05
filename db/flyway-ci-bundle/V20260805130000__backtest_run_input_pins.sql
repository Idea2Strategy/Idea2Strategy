CREATE TABLE backtest.run_input_pins (
    run_id uuid PRIMARY KEY
        REFERENCES backtest.runs(id),
    input_bundle_id uuid NOT NULL UNIQUE
        REFERENCES backtest.input_bundles(id),
    input_bundle_fingerprint varchar(128) NOT NULL,
    input_contract_version varchar(80) NOT NULL,
    compiled_plan_checksum varchar(128) NOT NULL,
    strategy_snapshot_hash varchar(128) NOT NULL,
    execution_policy_version varchar(80) NOT NULL
        REFERENCES backtest.execution_policy_versions(version),
    pinned_at timestamptz NOT NULL,
    CONSTRAINT backtest_run_input_bundle_fingerprint_sha256
        CHECK (input_bundle_fingerprint ~ '^sha256:[0-9a-f]{64}$'),
    CONSTRAINT backtest_run_input_plan_checksum_sha256
        CHECK (compiled_plan_checksum ~ '^sha256:[0-9a-f]{64}$'),
    CONSTRAINT backtest_run_input_snapshot_hash_sha256
        CHECK (strategy_snapshot_hash ~ '^sha256:[0-9a-f]{64}$')
);

COMMENT ON TABLE backtest.run_input_pins IS
    'Producer-owned immutable join from an official run to its complete dataset/feature input bundle and execution semantics.';
