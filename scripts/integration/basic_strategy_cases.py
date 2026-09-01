"""Independent, deterministic Basic strategy semantic and validation oracles."""

from __future__ import annotations

import json
import random
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CORPUS = ROOT / "contracts/fixtures/basic-strategy/v1/basic-element-conformance.v1.json"
RESOLUTIONS = ("30m", "1h", "4h", "1d")
SIDES = ("BUY", "SELL")
SHUFFLE_SEEDS = (17, 101, 313, 2027, 4099, 7919, 65537, 104729, 8675309, 20260831)


@dataclass(frozen=True, slots=True)
class BasicStrategyCase:
    name: str
    element_codes: tuple[str, ...]
    resolution: str
    sides: tuple[str, ...]
    instrument_count: int = 1
    partition_count: int = 1
    expected_warning_codes: tuple[str, ...] = ()
    available: bool = True
    expected_signal_count: int = 1


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


def generated_cases() -> tuple[BasicStrategyCase, ...]:
    fixture_cases = _fixture_cases()
    conditions_and_schedule = [
        case for case in fixture_cases if case["operation"] != "EMIT_ORDER_CANDIDATE"
    ]
    terminal_code = "BASIC_EQUAL_ALLOCATION_ORDER"
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
        result.append(
            BasicStrategyCase(
                name=f"pairwise-{str(condition['elementCode']).lower()}",
                element_codes=(str(condition["elementCode"]), terminal_code),
                resolution=resolution,
                sides=sides,
                instrument_count=1 + index % 5,
                partition_count=1 + index % 4,
            )
        )

    all_codes = tuple(str(case["elementCode"]) for case in fixture_cases)
    result.extend(
        (
            BasicStrategyCase(
                name="maximum-four-partition-five-instrument-two-side",
                element_codes=all_codes,
                resolution="30m",
                sides=SIDES,
                instrument_count=5,
                partition_count=4,
                expected_signal_count=2,
            ),
            BasicStrategyCase(
                name="contradictory-price-boundaries",
                element_codes=(
                    "BASIC_DRAWDOWN_FROM_PEAK",
                    "BASIC_DRAWDOWN_FROM_PEAK",
                    terminal_code,
                ),
                resolution="1h",
                sides=("SELL",),
                expected_warning_codes=("CONTRADICTORY_CONDITION",),
                expected_signal_count=0,
            ),
            BasicStrategyCase(
                name="duplicate-price-condition",
                element_codes=(
                    "BASIC_PRICE_COMPARE",
                    "BASIC_PRICE_COMPARE",
                    terminal_code,
                ),
                resolution="30m",
                sides=("BUY",),
                expected_warning_codes=("DUPLICATE_CONDITION",),
            ),
            BasicStrategyCase(
                name="no-signal",
                element_codes=("BASIC_PRICE_CHANGE_PERCENT", terminal_code),
                resolution="1h",
                sides=("BUY",),
                expected_signal_count=0,
            ),
            BasicStrategyCase(
                name="missing-required-history",
                element_codes=("BASIC_MACD_CROSS", terminal_code),
                resolution="4h",
                sides=("BUY",),
                available=False,
                expected_signal_count=0,
            ),
            BasicStrategyCase(
                name="simultaneous-buy-sell",
                element_codes=("BASIC_PRICE_COMPARE", terminal_code),
                resolution="1d",
                sides=SIDES,
                expected_signal_count=2,
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


def assert_complete_coverage(cases: tuple[BasicStrategyCase, ...]) -> None:
    covered = frozenset(code for case in cases for code in case.element_codes)
    missing = sorted(required_element_codes() - covered)
    if missing:
        raise AssertionError(f"CATALOG_CASES_MISSING: {','.join(missing)}")
