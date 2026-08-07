-- Publishes the complete Basic editor catalog. The previous catalog remains immutable and is
-- retired at the instant this replacement becomes available, so every released bot continues to
-- pin the element meanings it was compiled with.

UPDATE strategy.element_catalog_versions
SET retired_at = '2026-08-07T13:00:00+00'
WHERE id = '0f1a0000-0000-4000-8000-000000000001'
  AND retired_at IS NULL;

INSERT INTO strategy.element_catalog_versions (
    id, language_version, schema_version, catalog_version, data_requirement_version,
    definition_hash, published_at)
VALUES (
    '0f2a0000-0000-4000-8000-000000000001',
    'basic/v1',
    'basic-semantic/v1',
    'basic-elements:2026-08-07',
    'alpaca-sip/v1',
    'sha256:92a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301',
    '2026-08-07T13:00:00+00');

WITH definitions(
    id, element_code, element_kind, parameter_schema, containers, operation, arguments,
    input_ports, output_ports, terminal, definition_hash
) AS (VALUES
    (
      '0f2c0000-0000-4000-8000-000000000001'::uuid,
      'BASIC_PRICE_COMPARE', 'CONDITION',
      '{"type":"object","properties":{"resolution":{"type":"string"},"operator":{"type":"string","enum":["LT","LTE","GT","GTE","EQ","NEQ"]},"reference":{"type":"string","enum":["PREVIOUS_CLOSE","SESSION_OPEN","AVERAGE_ENTRY_PRICE","SMA_5","SMA_20","SMA_60","HIGH_5","HIGH_20","HIGH_60","LOW_5","LOW_20","LOW_60"]}},"required":["resolution","operator","reference"]}'::jsonb,
      '["BUY","SELL"]'::jsonb, 'PRICE_COMPARE',
      '{"resolution":"$resolution","operator":"$operator","reference":"$reference"}'::jsonb,
      '{"passed":{"type":"boolean"}}'::jsonb, '{"passed":{"type":"boolean"}}'::jsonb,
      false, 'sha256:01a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'
    ),
    (
      '0f2c0000-0000-4000-8000-000000000002'::uuid,
      'BASIC_PRICE_CHANGE_PERCENT', 'CONDITION',
      '{"type":"object","properties":{"resolution":{"type":"string"},"base":{"type":"string","enum":["PREVIOUS_CLOSE","SESSION_OPEN","AVERAGE_ENTRY_PRICE"]},"direction":{"type":"string","enum":["UP","DOWN"]},"thresholdPercent":{"type":"string","minLength":1}},"required":["resolution","base","direction","thresholdPercent"]}'::jsonb,
      '["BUY","SELL"]'::jsonb, 'PRICE_CHANGE_PERCENT',
      '{"resolution":"$resolution","base":"$base","direction":"$direction","thresholdPercent":"$thresholdPercent"}'::jsonb,
      '{"passed":{"type":"boolean"}}'::jsonb, '{"passed":{"type":"boolean"}}'::jsonb,
      false, 'sha256:02a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'
    ),
    (
      '0f2c0000-0000-4000-8000-000000000003'::uuid,
      'BASIC_VOLUME_COMPARE', 'CONDITION',
      '{"type":"object","properties":{"resolution":{"type":"string"},"operator":{"type":"string","enum":["LT","LTE","GT","GTE","EQ","NEQ"]},"reference":{"type":"string","enum":["PREVIOUS_VOLUME","AVERAGE_VOLUME"]},"period":{"type":"string","enum":["1","5","20","60"]},"multiplier":{"type":"string","enum":["1","2","3"]}},"required":["resolution","operator","reference","period","multiplier"]}'::jsonb,
      '["BUY","SELL"]'::jsonb, 'VOLUME_COMPARE',
      '{"resolution":"$resolution","operator":"$operator","reference":"$reference","period":"$period","multiplier":"$multiplier"}'::jsonb,
      '{"passed":{"type":"boolean"}}'::jsonb, '{"passed":{"type":"boolean"}}'::jsonb,
      false, 'sha256:03a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'
    ),
    (
      '0f2c0000-0000-4000-8000-000000000004'::uuid,
      'BASIC_STREAK', 'CONDITION',
      '{"type":"object","properties":{"resolution":{"type":"string"},"direction":{"type":"string","enum":["UP","DOWN"]},"bars":{"type":"string","enum":["2","3","5","10","20","30"]}},"required":["resolution","direction","bars"]}'::jsonb,
      '["BUY","SELL"]'::jsonb, 'STREAK',
      '{"resolution":"$resolution","direction":"$direction","bars":"$bars"}'::jsonb,
      '{"passed":{"type":"boolean"}}'::jsonb, '{"passed":{"type":"boolean"}}'::jsonb,
      false, 'sha256:04a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'
    ),
    (
      '0f2c0000-0000-4000-8000-000000000005'::uuid,
      'BASIC_SMA_CROSS', 'CONDITION',
      '{"type":"object","properties":{"resolution":{"type":"string"},"direction":{"type":"string","enum":["UP","DOWN"]},"shortPeriod":{"type":"string","enum":["5","20","60"]},"longPeriod":{"type":"string","enum":["20","60","120"]}},"required":["resolution","direction","shortPeriod","longPeriod"]}'::jsonb,
      '["BUY","SELL"]'::jsonb, 'SMA_CROSS',
      '{"resolution":"$resolution","direction":"$direction","shortPeriod":"$shortPeriod","longPeriod":"$longPeriod"}'::jsonb,
      '{"passed":{"type":"boolean"}}'::jsonb, '{"passed":{"type":"boolean"}}'::jsonb,
      false, 'sha256:05a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'
    ),
    (
      '0f2c0000-0000-4000-8000-000000000006'::uuid,
      'BASIC_RSI_CROSS', 'CONDITION',
      '{"type":"object","properties":{"resolution":{"type":"string"},"direction":{"type":"string","enum":["UP","DOWN"]},"period":{"type":"string","enum":["14"]},"threshold":{"type":"string","minLength":1}},"required":["resolution","direction","period","threshold"]}'::jsonb,
      '["BUY","SELL"]'::jsonb, 'RSI_CROSS',
      '{"resolution":"$resolution","direction":"$direction","period":"$period","threshold":"$threshold"}'::jsonb,
      '{"passed":{"type":"boolean"}}'::jsonb, '{"passed":{"type":"boolean"}}'::jsonb,
      false, 'sha256:06a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'
    ),
    (
      '0f2c0000-0000-4000-8000-000000000007'::uuid,
      'BASIC_MACD_CROSS', 'CONDITION',
      '{"type":"object","properties":{"resolution":{"type":"string"},"direction":{"type":"string","enum":["UP","DOWN"]},"fastPeriod":{"type":"string","enum":["12"]},"slowPeriod":{"type":"string","enum":["26"]},"signalPeriod":{"type":"string","enum":["9"]}},"required":["resolution","direction","fastPeriod","slowPeriod","signalPeriod"]}'::jsonb,
      '["BUY","SELL"]'::jsonb, 'MACD_CROSS',
      '{"resolution":"$resolution","direction":"$direction","fastPeriod":"$fastPeriod","slowPeriod":"$slowPeriod","signalPeriod":"$signalPeriod"}'::jsonb,
      '{"passed":{"type":"boolean"}}'::jsonb, '{"passed":{"type":"boolean"}}'::jsonb,
      false, 'sha256:07a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'
    ),
    (
      '0f2c0000-0000-4000-8000-000000000008'::uuid,
      'BASIC_BOLLINGER_REVERSAL', 'CONDITION',
      '{"type":"object","properties":{"resolution":{"type":"string"},"direction":{"type":"string","enum":["UP","DOWN"]},"period":{"type":"string","enum":["20"]},"deviations":{"type":"string","enum":["2"]}},"required":["resolution","direction","period","deviations"]}'::jsonb,
      '["BUY","SELL"]'::jsonb, 'BOLLINGER_REVERSAL',
      '{"resolution":"$resolution","direction":"$direction","period":"$period","deviations":"$deviations"}'::jsonb,
      '{"passed":{"type":"boolean"}}'::jsonb, '{"passed":{"type":"boolean"}}'::jsonb,
      false, 'sha256:08a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'
    ),
    (
      '0f2c0000-0000-4000-8000-000000000009'::uuid,
      'BASIC_POSITION_RETURN', 'CONDITION',
      '{"type":"object","properties":{"direction":{"type":"string","enum":["PROFIT","LOSS"]},"thresholdPercent":{"type":"string","minLength":1}},"required":["direction","thresholdPercent"]}'::jsonb,
      '["SELL"]'::jsonb, 'POSITION_RETURN',
      '{"direction":"$direction","thresholdPercent":"$thresholdPercent"}'::jsonb,
      '{"passed":{"type":"boolean"}}'::jsonb, '{"passed":{"type":"boolean"}}'::jsonb,
      false, 'sha256:09a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'
    ),
    (
      '0f2c0000-0000-4000-8000-000000000010'::uuid,
      'BASIC_HOLDING_PERIOD', 'CONDITION',
      '{"type":"object","properties":{"unit":{"type":"string","enum":["SESSION_CLOSE","BAR","TRADING_DAY"]},"amount":{"type":"string","enum":["0","1","5","20"]},"resolution":{"type":"string"}},"required":["unit","amount","resolution"]}'::jsonb,
      '["SELL"]'::jsonb, 'HOLDING_PERIOD',
      '{"unit":"$unit","amount":"$amount","resolution":"$resolution"}'::jsonb,
      '{"passed":{"type":"boolean"}}'::jsonb, '{"passed":{"type":"boolean"}}'::jsonb,
      false, 'sha256:10a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'
    ),
    (
      '0f2c0000-0000-4000-8000-000000000011'::uuid,
      'BASIC_PEAK_RETURN', 'CONDITION',
      '{"type":"object","properties":{"operator":{"type":"string","enum":["LT","LTE","GT","GTE","EQ","NEQ"]},"thresholdPercent":{"type":"string","minLength":1}},"required":["operator","thresholdPercent"]}'::jsonb,
      '["SELL"]'::jsonb, 'PEAK_RETURN',
      '{"operator":"$operator","thresholdPercent":"$thresholdPercent"}'::jsonb,
      '{"passed":{"type":"boolean"}}'::jsonb, '{"passed":{"type":"boolean"}}'::jsonb,
      false, 'sha256:11a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'
    ),
    (
      '0f2c0000-0000-4000-8000-000000000012'::uuid,
      'BASIC_DRAWDOWN_FROM_PEAK', 'CONDITION',
      '{"type":"object","properties":{"operator":{"type":"string","enum":["LT","LTE","GT","GTE","EQ","NEQ"]},"thresholdPercent":{"type":"string","minLength":1}},"required":["operator","thresholdPercent"]}'::jsonb,
      '["SELL"]'::jsonb, 'DRAWDOWN_FROM_PEAK',
      '{"operator":"$operator","thresholdPercent":"$thresholdPercent"}'::jsonb,
      '{"passed":{"type":"boolean"}}'::jsonb, '{"passed":{"type":"boolean"}}'::jsonb,
      false, 'sha256:12a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'
    ),
    (
      '0f2c0000-0000-4000-8000-000000000013'::uuid,
      'BASIC_SCHEDULE', 'TRIGGER',
      '{"type":"object","properties":{"cycle":{"type":"string","enum":["EVERY_TRADING_DAY","WEEK_FIRST_TRADING_DAY","MONTH_FIRST_TRADING_DAY","MONTH_LAST_TRADING_DAY","EVERY_N_TRADING_DAYS"]},"interval":{"type":"string","minLength":1},"resolution":{"type":"string"}},"required":["cycle","interval","resolution"]}'::jsonb,
      '["BUY"]'::jsonb, 'SCHEDULE',
      '{"cycle":"$cycle","interval":"$interval","resolution":"$resolution"}'::jsonb,
      '{"passed":{"type":"boolean"}}'::jsonb, '{"passed":{"type":"boolean"}}'::jsonb,
      false, 'sha256:13a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'
    ),
    (
      '0f2c0000-0000-4000-8000-000000000014'::uuid,
      'BASIC_EQUAL_ALLOCATION_ORDER', 'ACTION',
      '{"type":"object","properties":{"orderPercent":{"type":"string","minLength":1},"executionMode":{"type":"string"},"waitMode":{"type":"string"},"waitInterval":{"type":"string","minLength":1},"maxExecutions":{"type":"string","minLength":1}},"required":["orderPercent","executionMode","waitMode","waitInterval","maxExecutions"]}'::jsonb,
      '["BUY","SELL"]'::jsonb, 'EMIT_ORDER_CANDIDATE',
      '{"allocation":"EQUAL","orderType":"MARKET","timeInForce":"DAY","side":"$container","orderPercent":"$orderPercent","executionMode":"$executionMode","waitMode":"$waitMode","waitInterval":"$waitInterval","maxExecutions":"$maxExecutions"}'::jsonb,
      '{"passed":{"type":"boolean"}}'::jsonb, '{}'::jsonb,
      true, 'sha256:14a8aa1db1ec89acd824d270df6df53f652f58ad75a7688f59efb20bf86b4301'
    )
)
INSERT INTO strategy.element_definitions (
    id, element_catalog_version_id, element_code, element_kind,
    parameter_schema, input_port_schema, output_port_schema, execution_contract, definition_hash)
SELECT
    id,
    '0f2a0000-0000-4000-8000-000000000001'::uuid,
    element_code,
    element_kind,
    parameter_schema,
    input_ports,
    output_ports,
    jsonb_build_object(
      'deterministic', true,
      'terminal', terminal,
      'containers', containers,
      'runtime', jsonb_build_object('operation', operation, 'arguments', arguments),
      'backtest', jsonb_build_object(
        'supported', true,
        'feeds', CASE WHEN terminal THEN '[]'::jsonb ELSE '[{"feed":"ADJUSTED_BAR","resolution":"1m"}]'::jsonb END,
        'features', '[]'::jsonb),
      'reviewTemplates', jsonb_build_object('ko-KR', element_code)),
    definition_hash
FROM definitions;
