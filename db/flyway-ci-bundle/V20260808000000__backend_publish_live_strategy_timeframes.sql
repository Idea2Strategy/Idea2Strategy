-- Publishes the first Basic catalog whose live resolutions match the strategy worker.
-- Display-only 1m/5m/15m bars are intentionally excluded: live strategies evaluate only on
-- finalized 30m, 1h, 4h, and 1d candles.

UPDATE strategy.element_catalog_versions
SET retired_at = '2026-08-07T15:00:00+00'
WHERE id = '0f2a0000-0000-4000-8000-000000000001'
  AND retired_at IS NULL;

INSERT INTO strategy.element_catalog_versions (
    id, language_version, schema_version, catalog_version, data_requirement_version,
    definition_hash, published_at)
VALUES (
    '0f3a0000-0000-4000-8000-000000000001',
    'basic/v1',
    'basic-semantic/v1',
    'basic-elements:2026-08-08-live-bars',
    'alpaca-sip/v1',
    'sha256:30a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301',
    '2026-08-07T15:00:00+00');

INSERT INTO strategy.element_definitions (
    id, element_catalog_version_id, element_code, element_kind,
    parameter_schema, input_port_schema, output_port_schema, execution_contract, definition_hash)
SELECT
    ('0f3c' || substring(id::text from 5))::uuid,
    '0f3a0000-0000-4000-8000-000000000001'::uuid,
    element_code,
    element_kind,
    CASE
      WHEN parameter_schema #> '{properties,resolution}' IS NULL THEN parameter_schema
      ELSE jsonb_set(
        parameter_schema,
        '{properties,resolution}',
        '{"type":"string","enum":["30m","1h","4h","1d"]}'::jsonb)
    END,
    input_port_schema,
    output_port_schema,
    execution_contract,
    'sha256:' || md5(definition_hash || ':live-timeframes')
        || md5('live-timeframes:' || definition_hash)
FROM strategy.element_definitions
WHERE element_catalog_version_id = '0f2a0000-0000-4000-8000-000000000001';
