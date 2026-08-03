-- Registers the one official feature the Basic catalog references (root #193).
--
-- This file is pipeline-owned by its name, which is what `MigrationPolicy` and
-- `DatabaseAccessPolicy.verifyMigrationOwnership` read: a `pipeline` migration may write
-- `market_data`, and a `backend` one may not — which is why this row cannot travel in the backend
-- migration that seeds `strategy.element_definitions`. It lives in the central migration directory
-- because that is where the assembler reads non-backend owners from; `V20260802220100__trading_...`
-- and `V20260802220300__backtest_...` sit here for the same reason.
--
-- The values are not chosen here. They are what `market_pipeline_lib.features.catalog`'s official
-- v1 entry for RSI_14 already declares, and that module says in its own comment why the resolution
-- is one minute rather than one day: the backend's live `strategy-bot.v1` plan asks for
-- `LOAD_FEATURE {"feature": "RSI_14", "resolution": "1m"}`, so a catalog materializing it daily
-- could never serve a bot.
--
-- `feature_code` is the feature's *name*, `RSI_14`, not the calculator code `RSI`.
-- `BasicExecutionPlanCompiler` maps the catalog by `feature_code` and looks up whatever a block's
-- `executionContract.backtest.features` names, so the value has to be the identifier a block can
-- reference — and it has to be unique, which a calculator code is not (`EMA_12` and `EMA_26` share
-- the calculator `EMA`). `calculator_version` carries the calculator identity instead, matching the
-- `rsi:1.0.0` definition version both runtimes implement.
--
-- `required_history_points` is 15: RSI_14 is a bounded fifteen-bar window (fourteen price changes).
-- Fewer completed bars is not a value of 0, 50 or 100 — the warm-up gate refuses to start the bot.

INSERT INTO market_data.feature_definitions (
    id, element_catalog_version_id, feature_code, calculator_version, resolution,
    normalized_parameters, output_value_type, required_history_points, definition_hash, created_at)
VALUES (
    '0f1b0000-0000-4000-8000-000000000001',
    '0f1a0000-0000-4000-8000-000000000001',
    'RSI_14',
    'rsi:1.0.0',
    '1m',
    '{"period": 14, "price_field": "close", "method": "SIMPLE_AVERAGE_BOUNDED_WINDOW", "input_adjustment": "SPLIT_DIVIDEND_ADJUSTED", "calendar_id": "XNYS"}',
    'NUMBER',
    15,
    'sha256:1a7c3e5b9d2f4068a1c3e5b7d9f20416283a5c7e9b1d3f50627496a8c0e2b4d6',
    '2026-08-04T00:00:00+00');
