-- The official Basic element catalog, version basic-elements:2026-08-04.
--
-- Root #193: strategy.element_definitions and element_catalog_versions were created by the
-- baseline and never populated, so B02/B03 answered empty to every user and no strategy could be
-- assembled, validated or compiled. This seeds the first official catalog version.
--
-- Scope is deliberately the smallest catalog the runtimes can actually execute today, which is
-- what makes it safe rather than aspirational:
--
--   * one feature, RSI_14. Both runtimes implement exactly this one under definition version
--     rsi:1.0.0 — Python in backtest_engine.elements.features, Java in OfficialFeatureCatalog —
--     and D92 requires them to agree, so a block naming any other feature could not be executed
--     reproducibly.
--   * three operations, LOAD_FEATURE / COMPARE / EMIT_ORDER_CANDIDATE, which are the operations
--     BasicPlanInterpreter and D's element catalog both implement.
--   * one resolution, 1m, the periodicity B's published plan uses and the one the realtime feed
--     delivers.
--
-- Everything here is declarative catalog data. A later catalog version adds elements by inserting
-- a new element_catalog_versions row with its own definitions; published rows are never edited,
-- because a released strategy pins its catalog version and its meaning must not move underneath it.

INSERT INTO strategy.element_catalog_versions (
    id, language_version, schema_version, catalog_version, data_requirement_version,
    definition_hash, published_at)
VALUES (
    '0f1a0000-0000-4000-8000-000000000001',
    'basic/v1',
    'basic-semantic/v1',
    'basic-elements:2026-08-04',
    'alpaca-sip/v1',
    'sha256:9d5f4b1c7e2a8f6039c4b5d8e1a7f20395c8d4b6e2a9f7013c5b8d4e6a2f9017',
    '2026-08-04T00:00:00+00');


-- BASIC_RSI_READ — LOAD_FEATURE.
--
-- Reads the instrument's RSI_14 at the plan's resolution and leaves it as the operand the next
-- block compares. It opens a chain, so it declares no input port.
INSERT INTO strategy.element_definitions (
    id, element_catalog_version_id, element_code, element_kind,
    parameter_schema, input_port_schema, output_port_schema, execution_contract, definition_hash)
VALUES (
    '0f1c0000-0000-4000-8000-000000000001',
    '0f1a0000-0000-4000-8000-000000000001',
    'BASIC_RSI_READ',
    'INDICATOR',
    '{"type":"object","properties":{"resolution":{"type":"string"}},"required":["resolution"]}',
    '{}',
    '{"value":{"type":"number"}}',
    '{"deterministic": true,
      "containers": ["BUY", "SELL"],
      "runtime": {"operation": "LOAD_FEATURE",
                  "arguments": {"feature": "RSI_14", "resolution": "$resolution"}},
      "backtest": {"supported": true,
                   "feeds": [{"feed": "ADJUSTED_BAR", "resolution": "1m"}],
                   "features": ["RSI_14"]},
      "reviewTemplates": {"ko-KR": "{resolution} 봉의 RSI(14)를 확인한다"}}',
    'sha256:2b8d4f60a3c5e7b9d1f30528496a8c0e2b4d6f81032547698ba1c3e5d7f90a24');

-- BASIC_VALUE_COMPARE — COMPARE.
--
-- Compares the operand the preceding block produced against an exact decimal threshold. The
-- threshold is a string in the parameter schema on purpose: a JSON number would arrive as a double
-- and the boundary between "below 30" and "at 30" has to be exact.
INSERT INTO strategy.element_definitions (
    id, element_catalog_version_id, element_code, element_kind,
    parameter_schema, input_port_schema, output_port_schema, execution_contract, definition_hash)
VALUES (
    '0f1c0000-0000-4000-8000-000000000002',
    '0f1a0000-0000-4000-8000-000000000001',
    'BASIC_VALUE_COMPARE',
    'CONDITION',
    '{"type":"object",
      "properties":{"operator":{"type":"string"},"threshold":{"type":"string"}},
      "required":["operator","threshold"]}',
    '{"value":{"type":"number"}}',
    '{"passed":{"type":"boolean"}}',
    '{"deterministic": true,
      "containers": ["BUY", "SELL"],
      "runtime": {"operation": "COMPARE",
                  "arguments": {"operator": "$operator", "threshold": "$threshold"}},
      "backtest": {"supported": true, "feeds": [], "features": []},
      "reviewTemplates": {"ko-KR": "값이 {threshold} {operator} 조건을 만족하면"}}',
    'sha256:3c9e5071b4d6f8a0e2043619507b9d1f3052849617a3c5e7b9d1f3052849617b');

-- BASIC_EQUAL_ALLOCATION_ORDER — EMIT_ORDER_CANDIDATE, terminal.
--
-- Emits the flow's order candidate for every instrument that survived the chain. Allocation is
-- EQUAL and the order is MARKET DAY: those are the only combinations the current release scope
-- supports, and F08A allows a fractional or notional order only for a market DAY long. The side is
-- not a parameter — it comes from the container the block sits in, so a buy block cannot be dropped
-- into a sell flow and silently invert.
INSERT INTO strategy.element_definitions (
    id, element_catalog_version_id, element_code, element_kind,
    parameter_schema, input_port_schema, output_port_schema, execution_contract, definition_hash)
VALUES (
    '0f1c0000-0000-4000-8000-000000000003',
    '0f1a0000-0000-4000-8000-000000000001',
    'BASIC_EQUAL_ALLOCATION_ORDER',
    'ACTION',
    '{"type":"object","properties":{},"required":[]}',
    '{"passed":{"type":"boolean"}}',
    '{}',
    '{"deterministic": true,
      "terminal": true,
      "containers": ["BUY", "SELL"],
      "runtime": {"operation": "EMIT_ORDER_CANDIDATE",
                  "arguments": {"allocation": "EQUAL", "orderType": "MARKET",
                                "timeInForce": "DAY", "side": "$container"}},
      "backtest": {"supported": true, "feeds": [], "features": []},
      "reviewTemplates": {"ko-KR": "보유 예산을 균등 배분해 시장가로 주문한다"}}',
    'sha256:4d0f6182c5e70921f31547208619ae2c4d6f8103254769b8a1c3e5d7f90a2436');
