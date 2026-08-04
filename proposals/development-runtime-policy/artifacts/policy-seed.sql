INSERT INTO trading.fee_policy_versions (
  id,
  policy_code,
  version,
  fee_rate_bps,
  calculation_rules_version,
  rules_hash,
  effective_from,
  effective_to,
  published_at
) VALUES (
  '6f2eae59-bc3d-4fc2-9330-a544d4c7e101',
  'official-virtual-trading-fee',
  'development-2026-q3-v1',
  20,
  'accounting:1.0.0',
  'c65484d8d981c6631a0d03772c7e1d772f9b176ba6922f8fadbfd5dfde7370eb',
  '2026-07-01T04:00:00Z',
  NULL,
  '2026-07-01T04:00:00Z'
);

INSERT INTO trading.buying_power_buffer_policy_versions (
  id,
  policy_code,
  version,
  buffer_bps,
  rounding_rules_version,
  rules_hash,
  effective_from,
  effective_to,
  published_at
) VALUES (
  'a27b9962-56cc-41f8-b98c-9311833ff201',
  'official-buying-power-buffer',
  'development-2026-q3-v1',
  1,
  'precision:1.0.0',
  '7930efefde46d2a870627189ad9ae1535f2ef1218fe46b295c7b04a2118e058b',
  '2026-07-01T04:00:00Z',
  NULL,
  '2026-07-01T04:00:00Z'
);

INSERT INTO backtest.execution_policy_versions (
  version,
  policy_artifact_hash,
  policy_document,
  locked_at,
  retired_at
) VALUES (
  'development-official-backtest-2026-q3-v1',
  'c65484d8d981c6631a0d03772c7e1d772f9b176ba6922f8fadbfd5dfde7370eb',
  '{"version":"development-official-backtest-2026-q3-v1","releaseQuarter":"2026-Q3","periodStart":"2016-07-01T04:00:00Z","periodEnd":"2026-07-01T04:00:00Z","feeRate":"0.002","slippageRateBps":5,"timezone":"America/New_York","sessionCalendar":"XNYS","timestampUnit":"us","priceArrowType":"double","volumeArrowType":"int64","marketDataSchemaVersion":"market-bars-v2","calculationModelVersion":"backtest-calculation-v1","marketRulesVersion":"market:1.0.0","accountingRulesVersion":"accounting:1.0.0","precisionRulesVersion":"precision:1.0.0","feePolicyId":"6f2eae59-bc3d-4fc2-9330-a544d4c7e101","buyingPowerBufferPolicyId":"a27b9962-56cc-41f8-b98c-9311833ff201","goodTillCancelledHorizonSeconds":7776000,"maxOrderHorizonSeconds":7776000}'::jsonb,
  '2026-07-01T04:00:00Z',
  NULL
);
