-- Proposed production replacement for the legacy RSI_14@1m output.
-- New strategy releases select exactly one of 30m, 1h, 4h, or 1d and pin the
-- definition and deterministic output feed at that same resolution.
DO $migration$
DECLARE
    expected record;
    rsi_parameters jsonb := '{"period":14,"price_field":"close","method":"SIMPLE_AVERAGE_BOUNDED_WINDOW","input_adjustment":"SPLIT_DIVIDEND_ADJUSTED","calendar_id":"XNYS"}'::jsonb;
BEGIN
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
                TIMESTAMPTZ '2026-08-08 12:01:00+00');
    END IF;

    FOR expected IN
        SELECT * FROM (VALUES
            ('30m', '4b1c6801-0259-5176-a857-0e5ea923d898'::uuid, '363f534dc77c6af0ebfe58f35be4fd2aa208906b1eaa36b550b17e9acb8692e4', '57794d8c-2254-53e4-966e-44f97edd9e6a'::uuid, 'FEATURE_RSI_14_30M_RSI_1_0_0'),
            ('1h',  '2e18c093-5d4e-5d9a-bd22-b7e5679f1a3e'::uuid, '9b8512c0502ca80e1804711ac624eb4a3b4e294a875dac2364e3510e284cc8b9', '28012549-4f45-56d3-8bb6-329e4c7a9d77'::uuid, 'FEATURE_RSI_14_1H_RSI_1_0_0'),
            ('4h',  '1b2785bd-20f0-50a2-ae96-6a1f7bad74b9'::uuid, 'da3aff028a1fdef861abb1d68852e2ba3a91ed3917f7c7196e2d43ef48176b2c', 'e1d7d508-aaf1-5ae9-8098-c4af870f6fa4'::uuid, 'FEATURE_RSI_14_4H_RSI_1_0_0'),
            ('1d',  'eddfb2d4-8586-5260-8fc9-9c8125990270'::uuid, '0cf646eb9cacf5826d26f7dcb982bf7cec9213cc438b99716ac47883aa04ba04', '6d2647f8-5caf-55ee-8821-869dc693f68a'::uuid, 'FEATURE_RSI_14_1D_RSI_1_0_0')
        ) AS definitions(resolution, definition_id, definition_hash, feed_id, feed_code)
    LOOP
        IF EXISTS (SELECT 1 FROM market_data.feature_definitions WHERE id = expected.definition_id) THEN
            IF NOT EXISTS (
                SELECT 1 FROM market_data.feature_definitions
                WHERE id = expected.definition_id
                  AND element_catalog_version_id = '0f4a0000-0000-4000-8000-000000000001'
                  AND feature_code = 'RSI_14' AND calculator_version = 'rsi:1.0.0'
                  AND resolution = expected.resolution AND normalized_parameters = rsi_parameters
                  AND output_value_type = 'NUMBER' AND required_history_points = 15
                  AND definition_hash = expected.definition_hash
            ) THEN
                RAISE EXCEPTION 'production RSI_14 definition identity drift at %', expected.resolution;
            END IF;
        ELSE
            INSERT INTO market_data.feature_definitions (
                id, element_catalog_version_id, feature_code, calculator_version, resolution,
                normalized_parameters, output_value_type, required_history_points, definition_hash, created_at
            ) VALUES (
                expected.definition_id, '0f4a0000-0000-4000-8000-000000000001',
                'RSI_14', 'rsi:1.0.0', expected.resolution, rsi_parameters, 'NUMBER', 15,
                expected.definition_hash, TIMESTAMPTZ '2026-08-08 12:01:00+00'
            );
        END IF;

        IF EXISTS (SELECT 1 FROM market_data.feeds WHERE id = expected.feed_id) THEN
            IF NOT EXISTS (
                SELECT 1 FROM market_data.feeds
                WHERE id = expected.feed_id
                  AND provider_id = 'b9146ed9-dbb0-5323-93e3-8518f3851236'
                  AND code = expected.feed_code AND data_kind = 'FEATURE_SERIES'
                  AND resolution = expected.resolution AND timezone_name = 'UTC'
                  AND feed_version = 'rsi-1.0.0+feature-series.parquet.v1'
                  AND retired_at IS NULL
            ) THEN
                RAISE EXCEPTION 'production RSI_14 feed identity drift at %', expected.resolution;
            END IF;
        ELSE
            INSERT INTO market_data.feeds (
                id, provider_id, code, data_kind, resolution, timezone_name,
                feed_version, created_at, retired_at
            ) VALUES (
                expected.feed_id, 'b9146ed9-dbb0-5323-93e3-8518f3851236',
                expected.feed_code, 'FEATURE_SERIES', expected.resolution, 'UTC',
                'rsi-1.0.0+feature-series.parquet.v1',
                TIMESTAMPTZ '2026-08-08 12:01:00+00', NULL
            );
        END IF;
    END LOOP;
END
$migration$;
