INSERT INTO competition.scoring_template_versions (
  id, template_code, version, rules_document, rules_hash, published_at, retired_at
) SELECT
  'cb2cd7ad-093d-4f1f-b76c-2762437ea101',
  'SINGLE_TOTAL_RETURN_V1',
  'development-2026-q3-v1',
  '{"kind":"SINGLE","calculationRulesVersion":"official-room-scoring.v1","components":[{"metric":"TOTAL_RETURN","direction":"HIGHER_IS_BETTER","coefficient":1.0}],"adjustments":[]}'::jsonb,
  '3c81fb2f387fa790e126e1aa40b18d389c44bcf9f7ef2cefdd6911fd2e1eec71',
  '2026-07-01T04:00:00Z',
  NULL
WHERE NOT EXISTS (
  SELECT 1 FROM competition.scoring_template_versions
  WHERE id = 'cb2cd7ad-093d-4f1f-b76c-2762437ea101'
);

INSERT INTO competition.scoring_template_versions (
  id, template_code, version, rules_document, rules_hash, published_at, retired_at
) SELECT
  'cb2cd7ad-093d-4f1f-b76c-2762437ea102',
  'SINGLE_SHARPE_V1',
  'development-2026-q3-v1',
  '{"kind":"SINGLE","calculationRulesVersion":"official-room-scoring.v1","components":[{"metric":"SHARPE_RATIO","direction":"HIGHER_IS_BETTER","coefficient":1.0}],"adjustments":[]}'::jsonb,
  'dedc3baef45654bf4f760755d53fcd8d3fdd9d0be24d87e1027c266fa27fe96d',
  '2026-07-01T04:00:00Z',
  NULL
WHERE NOT EXISTS (
  SELECT 1 FROM competition.scoring_template_versions
  WHERE id = 'cb2cd7ad-093d-4f1f-b76c-2762437ea102'
);

INSERT INTO competition.scoring_template_versions (
  id, template_code, version, rules_document, rules_hash, published_at, retired_at
) SELECT
  'cb2cd7ad-093d-4f1f-b76c-2762437ea103',
  'SINGLE_MAX_DRAWDOWN_V1',
  'development-2026-q3-v1',
  '{"kind":"SINGLE","calculationRulesVersion":"official-room-scoring.v1","components":[{"metric":"MAX_DRAWDOWN","direction":"LOWER_IS_BETTER","coefficient":1.0}],"adjustments":[]}'::jsonb,
  'ecf3788076330d98aa00f466d06b5c5eb6652eebc1b15e9fe0056f48ce2f9f59',
  '2026-07-01T04:00:00Z',
  NULL
WHERE NOT EXISTS (
  SELECT 1 FROM competition.scoring_template_versions
  WHERE id = 'cb2cd7ad-093d-4f1f-b76c-2762437ea103'
);

INSERT INTO competition.scoring_template_versions (
  id, template_code, version, rules_document, rules_hash, published_at, retired_at
) SELECT
  'cb2cd7ad-093d-4f1f-b76c-2762437ea104',
  'COMPOSITE_BALANCED_V1',
  'development-2026-q3-v1',
  '{"kind":"COMPOSITE","calculationRulesVersion":"official-room-scoring.v1","components":[{"metric":"TOTAL_RETURN","direction":"HIGHER_IS_BETTER","coefficient":0.50},{"metric":"SHARPE_RATIO","direction":"HIGHER_IS_BETTER","coefficient":0.30},{"metric":"MAX_DRAWDOWN","direction":"LOWER_IS_BETTER","coefficient":0.20}],"adjustments":[]}'::jsonb,
  '6d8e9a1c6c2a37a6ed397fdbfdedb417b53d537faa7ad972b3fdf7ff61afc3d9',
  '2026-07-01T04:00:00Z',
  NULL
WHERE NOT EXISTS (
  SELECT 1 FROM competition.scoring_template_versions
  WHERE id = 'cb2cd7ad-093d-4f1f-b76c-2762437ea104'
);

INSERT INTO competition.scoring_template_versions (
  id, template_code, version, rules_document, rules_hash, published_at, retired_at
)
SELECT expected.id, expected.template_code, expected.version, expected.rules_document,
       expected.rules_hash, expected.published_at, expected.retired_at
FROM (VALUES
  ('cb2cd7ad-093d-4f1f-b76c-2762437ea101'::uuid, 'SINGLE_TOTAL_RETURN_V1', 'development-2026-q3-v1', '{"kind":"SINGLE","calculationRulesVersion":"official-room-scoring.v1","components":[{"metric":"TOTAL_RETURN","direction":"HIGHER_IS_BETTER","coefficient":1.0}],"adjustments":[]}'::jsonb, '3c81fb2f387fa790e126e1aa40b18d389c44bcf9f7ef2cefdd6911fd2e1eec71', '2026-07-01T04:00:00Z'::timestamptz, NULL::timestamptz),
  ('cb2cd7ad-093d-4f1f-b76c-2762437ea102'::uuid, 'SINGLE_SHARPE_V1', 'development-2026-q3-v1', '{"kind":"SINGLE","calculationRulesVersion":"official-room-scoring.v1","components":[{"metric":"SHARPE_RATIO","direction":"HIGHER_IS_BETTER","coefficient":1.0}],"adjustments":[]}'::jsonb, 'dedc3baef45654bf4f760755d53fcd8d3fdd9d0be24d87e1027c266fa27fe96d', '2026-07-01T04:00:00Z'::timestamptz, NULL::timestamptz),
  ('cb2cd7ad-093d-4f1f-b76c-2762437ea103'::uuid, 'SINGLE_MAX_DRAWDOWN_V1', 'development-2026-q3-v1', '{"kind":"SINGLE","calculationRulesVersion":"official-room-scoring.v1","components":[{"metric":"MAX_DRAWDOWN","direction":"LOWER_IS_BETTER","coefficient":1.0}],"adjustments":[]}'::jsonb, 'ecf3788076330d98aa00f466d06b5c5eb6652eebc1b15e9fe0056f48ce2f9f59', '2026-07-01T04:00:00Z'::timestamptz, NULL::timestamptz),
  ('cb2cd7ad-093d-4f1f-b76c-2762437ea104'::uuid, 'COMPOSITE_BALANCED_V1', 'development-2026-q3-v1', '{"kind":"COMPOSITE","calculationRulesVersion":"official-room-scoring.v1","components":[{"metric":"TOTAL_RETURN","direction":"HIGHER_IS_BETTER","coefficient":0.50},{"metric":"SHARPE_RATIO","direction":"HIGHER_IS_BETTER","coefficient":0.30},{"metric":"MAX_DRAWDOWN","direction":"LOWER_IS_BETTER","coefficient":0.20}],"adjustments":[]}'::jsonb, '6d8e9a1c6c2a37a6ed397fdbfdedb417b53d537faa7ad972b3fdf7ff61afc3d9', '2026-07-01T04:00:00Z'::timestamptz, NULL::timestamptz)
) AS expected(id, template_code, version, rules_document, rules_hash, published_at, retired_at)
JOIN competition.scoring_template_versions actual ON actual.id = expected.id
WHERE actual.template_code <> expected.template_code
   OR actual.version <> expected.version
   OR actual.rules_document <> expected.rules_document
   OR actual.rules_hash <> expected.rules_hash
   OR actual.published_at <> expected.published_at
   OR actual.retired_at IS DISTINCT FROM expected.retired_at;
