-- Forward-only adoption of contract.market-data.publication.v1 revision 2.
-- Existing rows are accepted only when every protected identity field matches.
DO $migration$
DECLARE
    rsi_parameters jsonb := '{"period":14,"price_field":"close","method":"SIMPLE_AVERAGE_BOUNDED_WINDOW","input_adjustment":"SPLIT_DIVIDEND_ADJUSTED","calendar_id":"XNYS"}'::jsonb;
BEGIN
    IF EXISTS (SELECT 1 FROM market_data.feature_definitions WHERE id = '0f1b0000-0000-4000-8000-000000000001') THEN
        IF NOT EXISTS (
            SELECT 1 FROM market_data.feature_definitions
            WHERE id = '0f1b0000-0000-4000-8000-000000000001'
              AND element_catalog_version_id = '0f1a0000-0000-4000-8000-000000000001'
              AND feature_code = 'RSI_14' AND calculator_version = 'rsi:1.0.0'
              AND resolution = '1m' AND normalized_parameters = rsi_parameters
              AND output_value_type = 'NUMBER' AND required_history_points = 15
              AND definition_hash = 'sha256:1a7c3e5b9d2f4068a1c3e5b7d9f20416283a5c7e9b1d3f50627496a8c0e2b4d6'
        ) THEN
            RAISE EXCEPTION 'official RSI_14 definition identity drift';
        END IF;
    ELSE
        INSERT INTO market_data.feature_definitions (
            id, element_catalog_version_id, feature_code, calculator_version, resolution,
            normalized_parameters, output_value_type, required_history_points, definition_hash, created_at
        ) VALUES (
            '0f1b0000-0000-4000-8000-000000000001', '0f1a0000-0000-4000-8000-000000000001',
            'RSI_14', 'rsi:1.0.0', '1m', rsi_parameters, 'NUMBER', 15,
            'sha256:1a7c3e5b9d2f4068a1c3e5b7d9f20416283a5c7e9b1d3f50627496a8c0e2b4d6',
            TIMESTAMPTZ '2026-08-04 00:00:00+00'
        );
    END IF;

    IF EXISTS (SELECT 1 FROM market_data.providers WHERE id = 'b9146ed9-dbb0-5323-93e3-8518f3851236') THEN
        IF NOT EXISTS (
            SELECT 1 FROM market_data.providers
            WHERE id = 'b9146ed9-dbb0-5323-93e3-8518f3851236'
              AND code = 'IDEA2STRATEGY_INTERNAL'
              AND display_name = 'Idea2Strategy Derived Data'
              AND rights_version = 'internal-derived-v1' AND status = 'ACTIVE'
        ) THEN
            RAISE EXCEPTION 'IDEA2STRATEGY_INTERNAL provider identity drift';
        END IF;
    ELSE
        INSERT INTO market_data.providers (id, code, display_name, rights_version, status, created_at)
        VALUES ('b9146ed9-dbb0-5323-93e3-8518f3851236', 'IDEA2STRATEGY_INTERNAL',
                'Idea2Strategy Derived Data', 'internal-derived-v1', 'ACTIVE',
                TIMESTAMPTZ '2026-08-06 12:00:00+00');
    END IF;

    IF EXISTS (SELECT 1 FROM market_data.feeds WHERE id = '063f8f27-5c6a-5348-b2bb-abc3c634149c') THEN
        IF NOT EXISTS (
            SELECT 1 FROM market_data.feeds
            WHERE id = '063f8f27-5c6a-5348-b2bb-abc3c634149c'
              AND provider_id = 'b9146ed9-dbb0-5323-93e3-8518f3851236'
              AND code = 'FEATURE_RSI_14_1M_RSI_1_0_0' AND data_kind = 'FEATURE_SERIES'
              AND resolution = '1m' AND timezone_name = 'UTC'
              AND feed_version = 'rsi-1.0.0+feature-series.parquet.v1' AND retired_at IS NULL
        ) THEN
            RAISE EXCEPTION 'official RSI_14 feature feed identity drift';
        END IF;
    ELSE
        INSERT INTO market_data.feeds (
            id, provider_id, code, data_kind, resolution, timezone_name, feed_version, created_at, retired_at
        ) VALUES (
            '063f8f27-5c6a-5348-b2bb-abc3c634149c', 'b9146ed9-dbb0-5323-93e3-8518f3851236',
            'FEATURE_RSI_14_1M_RSI_1_0_0', 'FEATURE_SERIES', '1m', 'UTC',
            'rsi-1.0.0+feature-series.parquet.v1', TIMESTAMPTZ '2026-08-06 12:00:00+00', NULL
        );
    END IF;
END
$migration$;
