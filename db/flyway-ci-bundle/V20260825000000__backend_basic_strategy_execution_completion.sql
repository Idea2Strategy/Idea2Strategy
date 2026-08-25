-- Publish the complete Basic execution catalog without mutating the consolidated V1 rows.
-- Existing releases stay pinned to basic-elements:2026-08-08; new drafts select this later catalog.

INSERT INTO strategy.element_catalog_versions (
    id, language_version, schema_version, catalog_version, data_requirement_version,
    definition_hash, published_at, retired_at
) VALUES (
    '0f5a0000-0000-4000-8000-000000000001',
    'basic/v1',
    'basic-semantic/v1',
    'basic-elements:2026-08-25',
    'alpaca-sip/v1',
    'sha256:' || encode(public.digest('basic-elements:2026-08-25', 'sha256'), 'hex'),
    '2026-08-25 00:00:00+00',
    NULL
);

WITH copied AS (
    SELECT
        element_code,
        element_kind,
        CASE element_code
            WHEN 'BASIC_RSI_CROSS' THEN jsonb_set(parameter_schema, '{properties,threshold}',
                '{"type":"string","minLength":1,"x-numericMinimum":"0","x-numericMaximum":"100"}'::jsonb)
            WHEN 'BASIC_HOLDING_PERIOD' THEN jsonb_set(parameter_schema, '{properties,amount}',
                '{"type":"string","minLength":1,"x-integer":true,"x-numericMinimum":"0"}'::jsonb)
            WHEN 'BASIC_POSITION_RETURN' THEN jsonb_set(parameter_schema, '{properties,thresholdPercent}',
                '{"type":"string","minLength":1,"x-numericMinimum":"0","x-numericMaximum":"100"}'::jsonb)
            WHEN 'BASIC_PEAK_RETURN' THEN jsonb_set(parameter_schema, '{properties,thresholdPercent}',
                '{"type":"string","minLength":1,"x-numericMinimum":"0","x-numericMaximum":"100"}'::jsonb)
            WHEN 'BASIC_DRAWDOWN_FROM_PEAK' THEN jsonb_set(parameter_schema, '{properties,thresholdPercent}',
                '{"type":"string","minLength":1,"x-numericMinimum":"0","x-numericMaximum":"100"}'::jsonb)
            WHEN 'BASIC_SCHEDULE' THEN jsonb_set(parameter_schema, '{properties,interval}',
                '{"type":"string","minLength":1,"x-integer":true,"x-numericExclusiveMinimum":"0"}'::jsonb)
            WHEN 'BASIC_EQUAL_ALLOCATION_ORDER' THEN
                jsonb_set(
                    jsonb_set(
                        jsonb_set(
                            jsonb_set(
                                jsonb_set(parameter_schema, '{required}',
                                    (parameter_schema -> 'required') || '"maxPositionPercent"'::jsonb),
                                '{properties,orderPercent}',
                                '{"type":"string","minLength":1,"x-numericExclusiveMinimum":"0","x-numericMaximum":"100"}'::jsonb),
                            '{properties,maxPositionPercent}',
                            '{"type":"string","minLength":1,"x-numericExclusiveMinimum":"0","x-numericMaximum":"100"}'::jsonb,
                            true),
                        '{properties,waitInterval}',
                        '{"type":"string","minLength":1,"x-integer":true,"x-numericExclusiveMinimum":"0"}'::jsonb),
                    '{properties,maxExecutions}',
                    '{"type":"string","minLength":1,"x-integer":true,"x-numericExclusiveMinimum":"0"}'::jsonb)
            ELSE parameter_schema
        END AS parameter_schema,
        input_port_schema,
        output_port_schema,
        CASE WHEN element_code = 'BASIC_EQUAL_ALLOCATION_ORDER' THEN
            jsonb_set(execution_contract, '{runtime,arguments,maxPositionPercent}',
                '"$maxPositionPercent"'::jsonb, true)
        ELSE execution_contract END AS execution_contract
    FROM strategy.element_definitions
    WHERE element_catalog_version_id = '0f4a0000-0000-4000-8000-000000000001'
), versioned AS (
    SELECT
        md5('basic-elements:2026-08-25:' || element_code)::uuid AS id,
        element_code,
        element_kind,
        parameter_schema,
        input_port_schema,
        output_port_schema,
        execution_contract,
        'sha256:' || encode(public.digest(
            element_code || ':' || parameter_schema::text || ':' || execution_contract::text,
            'sha256'), 'hex') AS definition_hash
    FROM copied
)
INSERT INTO strategy.element_definitions (
    id, element_catalog_version_id, element_code, element_kind, parameter_schema,
    input_port_schema, output_port_schema, execution_contract, definition_hash
)
SELECT
    id,
    '0f5a0000-0000-4000-8000-000000000001',
    element_code,
    element_kind,
    parameter_schema,
    input_port_schema,
    output_port_schema,
    execution_contract,
    definition_hash
FROM versioned;
