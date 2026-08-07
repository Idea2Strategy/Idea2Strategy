-- Replaces the live-timeframe catalog with the production backtest resolution contract.
-- Earlier catalogs remain immutable so already released strategies keep their meaning.

UPDATE strategy.element_catalog_versions
SET retired_at = '2026-08-07T16:00:00+00'
WHERE id = '0f3a0000-0000-4000-8000-000000000001'
  AND retired_at IS NULL;

INSERT INTO strategy.element_catalog_versions (
    id, language_version, schema_version, catalog_version, data_requirement_version,
    definition_hash, published_at)
VALUES (
    '0f4a0000-0000-4000-8000-000000000001',
    'basic/v1',
    'basic-semantic/v1',
    'basic-elements:2026-08-08',
    'alpaca-sip/v1',
    'sha256:932b05ff472bb14f011d288900804142e385520f8c9c448b9bf4da8ea6f755da',
    '2026-08-07T16:00:00+00');

WITH replacement_ids(element_code, id, definition_hash) AS (VALUES
    ('BASIC_PRICE_COMPARE',          '0f4c0000-0000-4000-8000-000000000001'::uuid, 'sha256:51a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'),
    ('BASIC_PRICE_CHANGE_PERCENT',   '0f4c0000-0000-4000-8000-000000000002'::uuid, 'sha256:52a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'),
    ('BASIC_VOLUME_COMPARE',         '0f4c0000-0000-4000-8000-000000000003'::uuid, 'sha256:53a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'),
    ('BASIC_STREAK',                 '0f4c0000-0000-4000-8000-000000000004'::uuid, 'sha256:54a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'),
    ('BASIC_SMA_CROSS',              '0f4c0000-0000-4000-8000-000000000005'::uuid, 'sha256:55a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'),
    ('BASIC_RSI_CROSS',              '0f4c0000-0000-4000-8000-000000000006'::uuid, 'sha256:56a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'),
    ('BASIC_MACD_CROSS',             '0f4c0000-0000-4000-8000-000000000007'::uuid, 'sha256:57a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'),
    ('BASIC_BOLLINGER_REVERSAL',     '0f4c0000-0000-4000-8000-000000000008'::uuid, 'sha256:58a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'),
    ('BASIC_POSITION_RETURN',        '0f4c0000-0000-4000-8000-000000000009'::uuid, 'sha256:59a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'),
    ('BASIC_HOLDING_PERIOD',         '0f4c0000-0000-4000-8000-000000000010'::uuid, 'sha256:60a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'),
    ('BASIC_PEAK_RETURN',            '0f4c0000-0000-4000-8000-000000000011'::uuid, 'sha256:61a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'),
    ('BASIC_DRAWDOWN_FROM_PEAK',     '0f4c0000-0000-4000-8000-000000000012'::uuid, 'sha256:62a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'),
    ('BASIC_SCHEDULE',               '0f4c0000-0000-4000-8000-000000000013'::uuid, 'sha256:63a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'),
    ('BASIC_EQUAL_ALLOCATION_ORDER', '0f4c0000-0000-4000-8000-000000000014'::uuid, 'sha256:64a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301')
)
INSERT INTO strategy.element_definitions (
    id, element_catalog_version_id, element_code, element_kind,
    parameter_schema, input_port_schema, output_port_schema, execution_contract, definition_hash)
SELECT
    replacement.id,
    '0f4a0000-0000-4000-8000-000000000001'::uuid,
    previous.element_code,
    previous.element_kind,
    CASE
      WHEN previous.parameter_schema #> '{properties,resolution}' IS NULL
        THEN previous.parameter_schema
      ELSE jsonb_set(
        previous.parameter_schema,
        '{properties,resolution,enum}',
        '["30m","1h","4h","1d"]'::jsonb,
        true)
    END,
    previous.input_port_schema,
    previous.output_port_schema,
    jsonb_set(
      previous.execution_contract,
      '{backtest,feeds}',
      CASE
        WHEN previous.execution_contract #>> '{runtime,operation}' IN (
          'EMIT_ORDER_CANDIDATE', 'POSITION_RETURN', 'PEAK_RETURN', 'DRAWDOWN_FROM_PEAK')
          THEN '[]'::jsonb
        ELSE '[{"feed":"ADJUSTED_BAR","resolution":"$resolution"}]'::jsonb
      END),
    replacement.definition_hash
FROM strategy.element_definitions previous
JOIN replacement_ids replacement USING (element_code)
WHERE previous.element_catalog_version_id = '0f3a0000-0000-4000-8000-000000000001'::uuid;

UPDATE strategy.element_definitions
SET parameter_schema = jsonb_set(
      jsonb_set(
        parameter_schema,
        '{properties,executionMode,enum}',
        '["1회만","주기마다","대기 후 재진입","대기 후 재실행"]'::jsonb,
        true),
      '{properties,waitMode,enum}',
      '["조건 재충족","N봉 이후","N거래일 이후"]'::jsonb,
      true)
WHERE element_catalog_version_id = '0f4a0000-0000-4000-8000-000000000001'::uuid
  AND element_code = 'BASIC_EQUAL_ALLOCATION_ORDER';
