"""Independent, deterministic Basic strategy semantic and validation oracles."""

from __future__ import annotations

import json
import random
import uuid
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CORPUS = ROOT / "contracts/fixtures/basic-strategy/v1/basic-element-conformance.v1.json"
RESOLUTIONS = ("30m", "1h", "4h", "1d")
SIDES = ("BUY", "SELL")
SHUFFLE_SEEDS = (17, 101, 313, 2027, 4099, 7919, 65537, 104729, 8675309, 20260831)
_PARTITION_NAMESPACE = uuid.UUID("b184eb88-40fa-4a0c-86de-c4518c559fee")


@dataclass(frozen=True, slots=True)
class BasicStrategyStep:
    """One concrete block occurrence, including its editor and runtime values."""

    element_code: str
    operation: str
    parameters: Mapping[str, str]
    arguments: Mapping[str, str]
    containers: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class BasicStrategyCase:
    name: str
    steps: tuple[BasicStrategyStep, ...]
    resolution: str
    sides: tuple[str, ...]
    instrument_count: int = 1
    partition_count: int = 1
    input_scenario: str = "true"

    @property
    def element_codes(self) -> tuple[str, ...]:
        return tuple(step.element_code for step in self.steps)


@dataclass(frozen=True, slots=True)
class ArgumentValidationCase:
    name: str
    operation: str
    parameter: str
    category: str
    arguments: dict[str, str]
    accepted: bool


@dataclass(frozen=True, slots=True)
class _NumericParameter:
    operation: str
    parameter: str
    inside: str
    exclusive_minimum: bool = False
    maximum: str | None = None
    integer: bool = False


# Hand-transcribed from the published basic/v1 contract. This is deliberately not
# constructed from ElementCatalog: the matrix must catch, rather than copy, runtime drift.
_NUMERIC_PARAMETERS = (
    _NumericParameter("PRICE_CHANGE_PERCENT", "thresholdPercent", "3.5"),
    _NumericParameter("RSI_CROSS", "threshold", "50", maximum="100"),
    _NumericParameter("POSITION_RETURN", "thresholdPercent", "5", maximum="100"),
    _NumericParameter("HOLDING_PERIOD", "amount", "5", integer=True),
    _NumericParameter("PEAK_RETURN", "thresholdPercent", "15", maximum="100"),
    _NumericParameter("DRAWDOWN_FROM_PEAK", "thresholdPercent", "7", maximum="100"),
    _NumericParameter(
        "SCHEDULE", "interval", "5", exclusive_minimum=True, integer=True
    ),
    _NumericParameter(
        "EMIT_ORDER_CANDIDATE",
        "orderPercent",
        "25",
        exclusive_minimum=True,
        maximum="100",
    ),
    _NumericParameter(
        "EMIT_ORDER_CANDIDATE",
        "maxPositionPercent",
        "40",
        exclusive_minimum=True,
        maximum="100",
    ),
    _NumericParameter(
        "EMIT_ORDER_CANDIDATE",
        "waitInterval",
        "2",
        exclusive_minimum=True,
        integer=True,
    ),
    _NumericParameter(
        "EMIT_ORDER_CANDIDATE",
        "maxExecutions",
        "2",
        exclusive_minimum=True,
        integer=True,
    ),
)

# Every enumerated argument in the published runtime contract. Values intentionally
# stay out of this table: each case starts with the canonical fixture's known-valid
# arguments and changes exactly one field to an unknown literal.
_ENUM_PARAMETERS = (
    ("PRICE_COMPARE", "resolution"),
    ("PRICE_COMPARE", "operator"),
    ("PRICE_COMPARE", "reference"),
    ("PRICE_CHANGE_PERCENT", "resolution"),
    ("PRICE_CHANGE_PERCENT", "base"),
    ("PRICE_CHANGE_PERCENT", "direction"),
    ("VOLUME_COMPARE", "resolution"),
    ("VOLUME_COMPARE", "operator"),
    ("VOLUME_COMPARE", "reference"),
    ("VOLUME_COMPARE", "period"),
    ("VOLUME_COMPARE", "multiplier"),
    ("STREAK", "resolution"),
    ("STREAK", "direction"),
    ("STREAK", "bars"),
    ("SMA_CROSS", "resolution"),
    ("SMA_CROSS", "direction"),
    ("SMA_CROSS", "shortPeriod"),
    ("SMA_CROSS", "longPeriod"),
    ("RSI_CROSS", "resolution"),
    ("RSI_CROSS", "direction"),
    ("RSI_CROSS", "period"),
    ("MACD_CROSS", "resolution"),
    ("MACD_CROSS", "direction"),
    ("MACD_CROSS", "fastPeriod"),
    ("MACD_CROSS", "slowPeriod"),
    ("MACD_CROSS", "signalPeriod"),
    ("BOLLINGER_REVERSAL", "resolution"),
    ("BOLLINGER_REVERSAL", "direction"),
    ("BOLLINGER_REVERSAL", "period"),
    ("BOLLINGER_REVERSAL", "deviations"),
    ("POSITION_RETURN", "direction"),
    ("HOLDING_PERIOD", "unit"),
    ("HOLDING_PERIOD", "resolution"),
    ("PEAK_RETURN", "operator"),
    ("DRAWDOWN_FROM_PEAK", "operator"),
    ("SCHEDULE", "cycle"),
    ("SCHEDULE", "resolution"),
    ("EMIT_ORDER_CANDIDATE", "allocation"),
    ("EMIT_ORDER_CANDIDATE", "orderType"),
    ("EMIT_ORDER_CANDIDATE", "timeInForce"),
    ("EMIT_ORDER_CANDIDATE", "side"),
    ("EMIT_ORDER_CANDIDATE", "executionMode"),
    ("EMIT_ORDER_CANDIDATE", "waitMode"),
)


def corpus() -> dict[str, object]:
    return json.loads(CORPUS.read_text(encoding="utf-8"))


def _fixture_cases() -> tuple[dict[str, object], ...]:
    return tuple(corpus()["cases"])


def required_element_codes() -> frozenset[str]:
    return frozenset(str(case["elementCode"]) for case in _fixture_cases())


def condition_element_codes() -> frozenset[str]:
    return frozenset(
        str(case["elementCode"])
        for case in _fixture_cases()
        if case["operation"] not in {"SCHEDULE", "EMIT_ORDER_CANDIDATE"}
    )


def _complete_arguments_by_operation() -> dict[str, dict[str, str]]:
    by_operation = {
        str(case["operation"]): {
            str(name): str(value) for name, value in case["arguments"].items()
        }
        for case in _fixture_cases()
    }
    by_operation["EMIT_ORDER_CANDIDATE"].update(
        allocation="EQUAL", orderType="MARKET", timeInForce="DAY", side="BUY"
    )
    return by_operation


def _step(fixture: Mapping[str, object], resolution: str) -> BasicStrategyStep:
    parameters = {
        str(key): str(value) for key, value in fixture["validParameters"].items()
    }
    arguments = {str(key): str(value) for key, value in fixture["arguments"].items()}
    if "resolution" in parameters:
        parameters["resolution"] = resolution
    if "resolution" in arguments:
        arguments["resolution"] = resolution
    if fixture["operation"] == "EMIT_ORDER_CANDIDATE":
        arguments.update(allocation="EQUAL", orderType="MARKET", timeInForce="DAY")
    return BasicStrategyStep(
        element_code=str(fixture["elementCode"]),
        operation=str(fixture["operation"]),
        parameters=parameters,
        arguments=arguments,
        containers=tuple(str(value) for value in fixture["containers"]),
    )


def _with_arguments(step: BasicStrategyStep, **values: str) -> BasicStrategyStep:
    parameters = dict(step.parameters)
    arguments = dict(step.arguments)
    parameters.update(values)
    arguments.update(values)
    return BasicStrategyStep(
        step.element_code, step.operation, parameters, arguments, step.containers
    )


def generated_cases() -> tuple[BasicStrategyCase, ...]:
    fixture_cases = _fixture_cases()
    fixture_by_code = {str(case["elementCode"]): case for case in fixture_cases}
    conditions_and_schedule = [
        case for case in fixture_cases if case["operation"] != "EMIT_ORDER_CANDIDATE"
    ]
    terminal = fixture_by_code["BASIC_EQUAL_ALLOCATION_ORDER"]
    clock = fixture_by_code["BASIC_PRICE_COMPARE"]
    result: list[BasicStrategyCase] = []
    dual_container_index = 0
    for index, condition in enumerate(conditions_and_schedule):
        containers = tuple(str(value) for value in condition["containers"])
        if len(containers) == 2:
            resolution = RESOLUTIONS[(dual_container_index // 2) % len(RESOLUTIONS)]
            sides = (SIDES[dual_container_index % 2],)
            dual_container_index += 1
        else:
            resolution = str(
                condition["validParameters"].get(
                    "resolution", RESOLUTIONS[index % len(RESOLUTIONS)]
                )
            )
            sides = (containers[0],)
        condition_step = _step(condition, resolution)
        steps = [condition_step]
        if condition["operation"] in {
            "POSITION_RETURN",
            "HOLDING_PERIOD",
            "PEAK_RETURN",
            "DRAWDOWN_FROM_PEAK",
            "SCHEDULE",
        }:
            steps.insert(0, _step(clock, resolution))
        steps.append(_step(terminal, resolution))
        result.append(
            BasicStrategyCase(
                name=f"pairwise-{str(condition['elementCode']).lower()}",
                steps=tuple(steps),
                resolution=resolution,
                sides=sides,
                instrument_count=1 + index % 5,
                partition_count=1 + index % 4,
            )
        )

    all_steps = tuple(_step(case, "30m") for case in fixture_cases)
    price = _step(clock, "30m")
    drawdown = _step(fixture_by_code["BASIC_DRAWDOWN_FROM_PEAK"], "1h")
    result.extend(
        (
            BasicStrategyCase(
                name="maximum-four-partition-five-instrument-two-side",
                steps=all_steps,
                resolution="30m",
                sides=SIDES,
                instrument_count=5,
                partition_count=4,
            ),
            BasicStrategyCase(
                name="contradictory-price-boundaries",
                steps=(
                    _step(clock, "30m"),
                    _with_arguments(drawdown, operator="GTE", thresholdPercent="10"),
                    _with_arguments(drawdown, operator="LT", thresholdPercent="5"),
                    _step(terminal, "30m"),
                ),
                resolution="30m",
                sides=("SELL",),
            ),
            BasicStrategyCase(
                name="duplicate-price-condition",
                steps=(
                    price,
                    _step(clock, "30m"),
                    _step(terminal, "30m"),
                ),
                resolution="30m",
                sides=("BUY",),
            ),
            BasicStrategyCase(
                name="no-signal",
                steps=(
                    _with_arguments(_step(clock, "30m"), operator="LT"),
                    _step(terminal, "30m"),
                ),
                resolution="30m",
                sides=("BUY",),
                input_scenario="false",
            ),
            BasicStrategyCase(
                name="missing-required-history",
                steps=(
                    _step(fixture_by_code["BASIC_MACD_CROSS"], "4h"),
                    _step(terminal, "4h"),
                ),
                resolution="4h",
                sides=("BUY",),
                input_scenario="missing",
            ),
            BasicStrategyCase(
                name="simultaneous-buy-sell",
                steps=(_step(clock, "30m"), _step(terminal, "30m")),
                resolution="30m",
                sides=SIDES,
            ),
        )
    )
    return tuple(result)


def numeric_validation_cases() -> tuple[ArgumentValidationCase, ...]:
    valid_by_operation = _complete_arguments_by_operation()
    result: list[ArgumentValidationCase] = []
    for spec in _NUMERIC_PARAMETERS:
        values = [
            ("minimum", "0", not spec.exclusive_minimum),
            ("inside", spec.inside, True),
            ("zero", "0", not spec.exclusive_minimum),
            ("negative", "-1", False),
            ("decimal", "1.5", not spec.integer),
            ("empty", "", False),
            ("malformed", "not-a-number", False),
        ]
        if spec.maximum is not None:
            values[1:1] = [
                ("maximum", spec.maximum, True),
                ("outside", "100.00000001", False),
            ]
        for category, value, accepted in values:
            arguments = valid_by_operation[spec.operation].copy()
            arguments[spec.parameter] = value
            result.append(
                ArgumentValidationCase(
                    name=f"{spec.operation.lower()}-{spec.parameter}-{category}",
                    operation=spec.operation,
                    parameter=spec.parameter,
                    category=category,
                    arguments=arguments,
                    accepted=accepted,
                )
            )
    return tuple(result)


def unknown_enum_cases() -> tuple[ArgumentValidationCase, ...]:
    valid_by_operation = _complete_arguments_by_operation()
    result = []
    for operation, parameter in _ENUM_PARAMETERS:
        arguments = valid_by_operation[operation].copy()
        arguments[parameter] = "__UNKNOWN__"
        result.append(
            ArgumentValidationCase(
                name=f"{operation.lower()}-{parameter}-unknown-enum",
                operation=operation,
                parameter=parameter,
                category="unknown-enum",
                arguments=arguments,
                accepted=False,
            )
        )
    return tuple(result)


def shuffled_cases(seed: int) -> tuple[BasicStrategyCase, ...]:
    cases = generated_cases()
    return tuple(random.Random(seed).sample(cases, len(cases)))


_INSTRUMENT_IDS = (
    "03e7e685-d6da-4f1f-9279-91477884aab9",
    *(f"00000000-0000-4000-8000-{number:012d}" for number in range(302, 306)),
)


def _steps_for_side(
    case: BasicStrategyCase, side: str
) -> tuple[BasicStrategyStep, ...]:
    return tuple(step for step in case.steps if side in step.containers)


def _chains_for_side(
    case: BasicStrategyCase, side: str
) -> tuple[tuple[BasicStrategyStep, ...], ...]:
    steps = _steps_for_side(case, side)
    terminal = next(step for step in steps if step.operation == "EMIT_ORDER_CANDIDATE")
    conditions = tuple(
        step for step in steps if step.operation != "EMIT_ORDER_CANDIDATE"
    )
    if case.name == "maximum-four-partition-five-instrument-two-side":
        width, remainder = divmod(len(conditions), case.partition_count)
        chains = []
        offset = 0
        for partition_index in range(case.partition_count):
            size = width + int(partition_index < remainder)
            chunk = conditions[offset : offset + size]
            offset += size
            chains.append((*chunk, terminal))
        return tuple(chains)
    clock = next(
        (step for step in conditions if step.operation == "PRICE_COMPARE"), None
    )
    chains = []
    for offset in range(0, len(conditions), 5):
        chunk = conditions[offset : offset + 5]
        if not any("resolution" in step.arguments for step in chunk):
            if clock is None:
                raise AssertionError(
                    f"{case.name}/{side} has no resolution-bearing clock"
                )
            chunk = (clock, *chunk)
        chains.append((*chunk, terminal))
    return tuple(chains)


def semantic_document(case: BasicStrategyCase) -> dict[str, object]:
    """Materialize the editor document accepted at the backend compiler boundary."""
    groups = []
    instruments = list(_INSTRUMENT_IDS[: case.instrument_count])
    for side in case.sides:
        for chain_index, steps in enumerate(_chains_for_side(case, side), start=1):
            blocks = [
                {
                    "id": f"{side.lower()}-{chain_index}-block-{index}",
                    "elementCode": step.element_code,
                    "parameters": dict(step.parameters),
                }
                for index, step in enumerate(steps, start=1)
            ]
            groups.append(
                {
                    "id": f"{side.lower()}-flow-{chain_index}",
                    "allocationGroupId": side.lower(),
                    "container": side,
                    "evaluationMode": "INDEPENDENT",
                    "allocationMode": "EQUAL",
                    "instrumentIds": instruments,
                    "blocks": blocks,
                    "connections": [
                        {
                            "fromBlockId": blocks[index]["id"],
                            "outputPort": "passed",
                            "toBlockId": blocks[index + 1]["id"],
                            "inputPort": "passed",
                        }
                        for index in range(len(blocks) - 1)
                    ],
                }
            )
    return {
        "catalogId": "0f5a0000-0000-4000-8000-000000000001",
        "groups": groups,
    }


def semantic_partitions(case: BasicStrategyCase) -> tuple[dict[str, object], ...]:
    """Partition-specific semantic documents sent to the production backend exporter."""
    source = semantic_document(case)
    result = []
    for partition_index in range(1, case.partition_count + 1):
        if case.name == "maximum-four-partition-five-instrument-two-side":
            groups = [
                group
                for group in source["groups"]
                if str(group["id"]).endswith(f"-flow-{partition_index}")
            ]
        else:
            groups = list(source["groups"])
        materialized_groups = []
        for group in groups:
            materialized = dict(group)
            materialized["id"] = f"partition-{partition_index}-{group['id']}"
            materialized_groups.append(materialized)
        result.append(
            {
                "key": str(
                    uuid.uuid5(
                        _PARTITION_NAMESPACE,
                        f"{case.name}:partition:{partition_index}",
                    )
                ),
                "budgetCapBps": 10000,
                "semanticDocument": {
                    "catalogId": source["catalogId"],
                    "groups": materialized_groups,
                },
            }
        )
    return tuple(result)


def backend_compiled_plan(case: BasicStrategyCase) -> dict[str, object]:
    from backend_plan_export import compiled_plans

    return compiled_plans()[case.name]


def assert_loaded_partition_identities(
    document: Mapping[str, object], plan: object, expected: tuple[str, ...]
) -> None:
    """Compare backend bytes and runtime-loaded flows with a caller-owned literal oracle."""
    snapshot = document["executionSnapshot"]
    assert isinstance(snapshot, Mapping)
    partitions = snapshot["partitions"]
    assert isinstance(partitions, list)
    raw = tuple(str(partition["key"]) for partition in partitions)
    loaded = tuple(dict.fromkeys(flow.partition_key for flow in plan.flows))
    assert raw == expected, f"compiled partition identities {raw!r} != {expected!r}"
    assert loaded == expected, f"loaded partition identities {loaded!r} != {expected!r}"


def assert_complete_coverage(cases: tuple[BasicStrategyCase, ...]) -> None:
    covered = frozenset(code for case in cases for code in case.element_codes)
    missing = sorted(required_element_codes() - covered)
    if missing:
        raise AssertionError(f"CATALOG_CASES_MISSING: {','.join(missing)}")
