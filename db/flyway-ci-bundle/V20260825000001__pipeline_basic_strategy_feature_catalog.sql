-- Copy the immutable feature definitions for the new Basic catalog under pipeline ownership.
INSERT INTO market_data.feature_definitions (
    id, element_catalog_version_id, feature_code, calculator_version, resolution,
    normalized_parameters, output_value_type, required_history_points, definition_hash, created_at
)
SELECT
    md5('basic-elements:2026-08-25:feature:' || feature_code || ':' || resolution)::uuid,
    '0f5a0000-0000-4000-8000-000000000001',
    feature_code,
    calculator_version,
    resolution,
    normalized_parameters,
    output_value_type,
    required_history_points,
    'sha256:' || encode(public.digest(
        'basic-elements:2026-08-25:feature:' || feature_code || ':' || resolution || ':'
            || normalized_parameters::text,
        'sha256'), 'hex'),
    '2026-08-25 00:00:01+00'
FROM market_data.feature_definitions
WHERE element_catalog_version_id = '0f4a0000-0000-4000-8000-000000000001';
