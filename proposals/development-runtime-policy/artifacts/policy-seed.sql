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
) SELECT
  '6f2eae59-bc3d-4fc2-9330-a544d4c7e101',
  'official-virtual-trading-fee',
  'development-2026-q3-v1',
  20,
  'accounting:1.0.0',
  'c65484d8d981c6631a0d03772c7e1d772f9b176ba6922f8fadbfd5dfde7370eb',
  '2026-07-01T04:00:00Z',
  NULL,
  '2026-07-01T04:00:00Z'
WHERE NOT EXISTS (
  SELECT 1 FROM trading.fee_policy_versions
  WHERE id = '6f2eae59-bc3d-4fc2-9330-a544d4c7e101'
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
) SELECT
  'a27b9962-56cc-41f8-b98c-9311833ff201',
  'official-buying-power-buffer',
  'development-2026-q3-v1',
  1,
  'precision:1.0.0',
  '7930efefde46d2a870627189ad9ae1535f2ef1218fe46b295c7b04a2118e058b',
  '2026-07-01T04:00:00Z',
  NULL,
  '2026-07-01T04:00:00Z'
WHERE NOT EXISTS (
  SELECT 1 FROM trading.buying_power_buffer_policy_versions
  WHERE id = 'a27b9962-56cc-41f8-b98c-9311833ff201'
);

INSERT INTO backtest.execution_policy_versions (
  version,
  policy_artifact_hash,
  policy_document,
  locked_at,
  retired_at
) SELECT
  'development-official-backtest-2026-q3-v1',
  'c65484d8d981c6631a0d03772c7e1d772f9b176ba6922f8fadbfd5dfde7370eb',
  '{"version":"development-official-backtest-2026-q3-v1","releaseQuarter":"2026-Q3","periodStart":"2016-07-01T04:00:00Z","periodEnd":"2026-07-01T04:00:00Z","feeRate":"0.002","slippageRateBps":5,"timezone":"America/New_York","sessionCalendar":"XNYS","timestampUnit":"us","priceArrowType":"double","volumeArrowType":"int64","marketDataSchemaVersion":"market-bars-v2","calculationModelVersion":"backtest-calculation-v1","marketRulesVersion":"market:1.0.0","accountingRulesVersion":"accounting:1.0.0","precisionRulesVersion":"precision:1.0.0","feePolicyId":"6f2eae59-bc3d-4fc2-9330-a544d4c7e101","buyingPowerBufferPolicyId":"a27b9962-56cc-41f8-b98c-9311833ff201","goodTillCancelledHorizonSeconds":7776000,"maxOrderHorizonSeconds":7776000}'::jsonb,
  '2026-07-01T04:00:00Z',
  NULL
WHERE NOT EXISTS (
  SELECT 1 FROM backtest.execution_policy_versions
  WHERE version = 'development-official-backtest-2026-q3-v1'
);

-- The 2026-Q3 verification policy. v1 declared a ten-year window and market-bars-v2, and Development
-- holds neither: its adjusted 30m manifests are market-bars/1 and the pinned XNYS calendar covers
-- 2024-2026 only. Every official run therefore failed before simulation — CalendarCoverageError from
-- the policy's 2016 periodStart, then a schema mismatch behind it (root #471, backtest-engine #82).
--
-- v2 states what Development can actually replay: the verified adjusted January 2024 manifest
-- 7f7113c9-3b02-4098-97ec-0baa07e2b3b0, dataset hash
-- 08a848a5f9aa1aac80e215c2d86bcf6d5f96c354400c7c16394dae9ffa9939af, at that manifest's own schema.
-- The period is local calendar-day midnight in America/New_York, which is what the consumer's
-- ExecutionPolicy requires and why the instants are 05:00Z rather than 00:00Z in January.
--
-- releaseQuarter stays 2026-Q3 because the catalog selects by release quarter, not by data window, and
-- a strategy released this quarter must resolve to a published policy. The window narrowing is not a
-- quiet reduction: it is a new immutable version, and v1's row is retired rather than edited so the
-- runs already recorded against it stay explainable.
--
-- The ten-year policy returns as its own version once the data pipeline publishes a ten-year
-- market-bars-v2 composite and the calendar covers it.
INSERT INTO backtest.execution_policy_versions (
  version,
  policy_artifact_hash,
  policy_document,
  locked_at,
  retired_at
) SELECT
  'development-official-backtest-2026-q3-v2',
  '2fc989fe28df1f69dacb3c9af73908fa8d54b2b8d7d69a2e8a9683c529028953',
  '{"version":"development-official-backtest-2026-q3-v2","releaseQuarter":"2026-Q3","periodStart":"2024-01-01T05:00:00Z","periodEnd":"2024-02-01T05:00:00Z","feeRate":"0.002","slippageRateBps":5,"timezone":"America/New_York","sessionCalendar":"XNYS","timestampUnit":"us","priceArrowType":"double","volumeArrowType":"int64","marketDataSchemaVersion":"market-bars/1","calculationModelVersion":"backtest-calculation-v1","marketRulesVersion":"market:1.0.0","accountingRulesVersion":"accounting:1.0.0","precisionRulesVersion":"precision:1.0.0","feePolicyId":"6f2eae59-bc3d-4fc2-9330-a544d4c7e101","buyingPowerBufferPolicyId":"a27b9962-56cc-41f8-b98c-9311833ff201","goodTillCancelledHorizonSeconds":7776000,"maxOrderHorizonSeconds":7776000}'::jsonb,
  '2026-08-09T00:00:00Z',
  NULL
WHERE NOT EXISTS (
  SELECT 1 FROM backtest.execution_policy_versions
  WHERE version = 'development-official-backtest-2026-q3-v2'
);

-- v1 keeps its row and its artifact hash so the runs recorded against it remain auditable, and stops
-- being selectable from the release instant v2 was locked.
UPDATE backtest.execution_policy_versions
   SET retired_at = '2026-08-09T00:00:00Z'
 WHERE version = 'development-official-backtest-2026-q3-v1'
   AND retired_at IS NULL;
