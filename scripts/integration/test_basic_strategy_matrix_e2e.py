"""Generated complex-shape contract matrix complementing the three-lane runtime proof."""

from __future__ import annotations

from collections import Counter

import basic_strategy_cases as matrix
import pytest
from backtest_engine.elements import (
    ElementCompatibilityError,
    PlanStep,
    element_catalog,
)

EXPECTED_CONDITION_CODES = frozenset(
    {
        "BASIC_PRICE_COMPARE",
        "BASIC_PRICE_CHANGE_PERCENT",
        "BASIC_VOLUME_COMPARE",
        "BASIC_STREAK",
        "BASIC_SMA_CROSS",
        "BASIC_RSI_CROSS",
        "BASIC_MACD_CROSS",
        "BASIC_BOLLINGER_REVERSAL",
        "BASIC_POSITION_RETURN",
        "BASIC_HOLDING_PERIOD",
        "BASIC_PEAK_RETURN",
        "BASIC_DRAWDOWN_FROM_PEAK",
    }
)
EXPECTED_ELEMENT_CODES = EXPECTED_CONDITION_CODES | {
    "BASIC_SCHEDULE",
    "BASIC_EQUAL_ALLOCATION_ORDER",
}
EXPECTED_NUMERIC_PARAMETERS = frozenset(
    {
        ("PRICE_CHANGE_PERCENT", "thresholdPercent"),
        ("RSI_CROSS", "threshold"),
        ("POSITION_RETURN", "thresholdPercent"),
        ("HOLDING_PERIOD", "amount"),
        ("PEAK_RETURN", "thresholdPercent"),
        ("DRAWDOWN_FROM_PEAK", "thresholdPercent"),
        ("SCHEDULE", "interval"),
        ("EMIT_ORDER_CANDIDATE", "orderPercent"),
        ("EMIT_ORDER_CANDIDATE", "maxPositionPercent"),
        ("EMIT_ORDER_CANDIDATE", "waitInterval"),
        ("EMIT_ORDER_CANDIDATE", "maxExecutions"),
    }
)
EXPECTED_ENUM_PARAMETERS = frozenset(
    {
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
    }
)
EXPECTED_SEEDS = (17, 101, 313, 2027, 4099, 7919, 65537, 104729, 8675309, 20260831)


def test_generated_matrix_has_hand_checked_size_and_complete_catalog_coverage() -> None:
    cases = matrix.generated_cases()
    covered = frozenset(code for case in cases for code in case.element_codes)

    assert len(cases) == 19
    matrix.assert_complete_coverage(cases)
    assert covered == EXPECTED_ELEMENT_CODES
    assert matrix.required_element_codes() == EXPECTED_ELEMENT_CODES
    assert matrix.condition_element_codes() == EXPECTED_CONDITION_CODES
    assert {case.partition_count for case in cases} == {1, 2, 3, 4}
    assert {case.instrument_count for case in cases} == {1, 2, 3, 4, 5}


def test_pairwise_resolution_and_side_coverage_is_complete_and_deterministic() -> None:
    cases = matrix.generated_cases()
    pairwise = tuple(case for case in cases if case.name.startswith("pairwise-"))
    pairs = {(case.resolution, side) for case in pairwise for side in case.sides}

    assert len(pairwise) == 13
    assert pairs == {
        ("30m", "BUY"),
        ("30m", "SELL"),
        ("1h", "BUY"),
        ("1h", "SELL"),
        ("4h", "BUY"),
        ("4h", "SELL"),
        ("1d", "BUY"),
        ("1d", "SELL"),
    }
    assert matrix.generated_cases() == cases


def test_curated_cases_cover_all_six_special_shapes_without_losing_duplicates() -> None:
    by_name = {case.name: case for case in matrix.generated_cases()}

    assert set(by_name) >= {
        "maximum-four-partition-five-instrument-two-side",
        "contradictory-price-boundaries",
        "duplicate-price-condition",
        "no-signal",
        "missing-required-history",
        "simultaneous-buy-sell",
    }
    maximum = by_name["maximum-four-partition-five-instrument-two-side"]
    assert (maximum.partition_count, maximum.instrument_count) == (4, 5)
    assert frozenset(maximum.element_codes) == EXPECTED_ELEMENT_CODES
    assert maximum.sides == ("BUY", "SELL")
    assert by_name["contradictory-price-boundaries"].expected_warning_codes == (
        "CONTRADICTORY_CONDITION",
    )
    duplicate = by_name["duplicate-price-condition"]
    assert duplicate.element_codes.count("BASIC_PRICE_COMPARE") == 2
    assert duplicate.expected_warning_codes == ("DUPLICATE_CONDITION",)
    assert by_name["no-signal"].expected_signal_count == 0
    assert by_name["no-signal"].available is True
    assert by_name["missing-required-history"].available is False
    assert by_name["missing-required-history"].expected_signal_count == 0
    simultaneous = by_name["simultaneous-buy-sell"]
    assert simultaneous.sides == ("BUY", "SELL")
    assert simultaneous.expected_signal_count == 2


def test_numeric_oracle_covers_every_published_boundary_independently() -> None:
    factory = getattr(matrix, "numeric_validation_cases", None)
    assert callable(factory), "numeric validation oracle is missing"
    cases = factory()

    assert len(cases) == 89
    assert {
        (case.operation, case.parameter) for case in cases
    } == EXPECTED_NUMERIC_PARAMETERS
    assert Counter(case.category for case in cases) == {
        "minimum": 11,
        "maximum": 6,
        "inside": 11,
        "outside": 6,
        "zero": 11,
        "negative": 11,
        "decimal": 11,
        "empty": 11,
        "malformed": 11,
    }

    catalog = element_catalog("basic-elements:2026-08-25")
    for case in cases:
        step = PlanStep(sequence=1, operation=case.operation, arguments=case.arguments)
        if case.accepted:
            catalog.validate_step(step)
        else:
            with pytest.raises(ElementCompatibilityError, match=case.parameter):
                catalog.validate_step(step)


def test_unknown_enum_oracle_rejects_every_published_enumerated_parameter() -> None:
    factory = getattr(matrix, "unknown_enum_cases", None)
    assert callable(factory), "unknown-enum oracle is missing"
    cases = factory()

    assert len(cases) == 43
    assert {
        (case.operation, case.parameter) for case in cases
    } == EXPECTED_ENUM_PARAMETERS

    catalog = element_catalog("basic-elements:2026-08-25")
    for case in cases:
        with pytest.raises(ElementCompatibilityError, match=case.parameter):
            catalog.validate_step(
                PlanStep(sequence=1, operation=case.operation, arguments=case.arguments)
            )


@pytest.mark.parametrize("seed", EXPECTED_SEEDS, ids=lambda seed: f"seed-{seed}")
def test_every_generated_element_uses_arguments_the_v2_runtime_really_accepts_in_shuffled_order(
    seed: int,
) -> None:
    shuffle = getattr(matrix, "shuffled_cases", None)
    assert callable(shuffle), "fixed-seed shuffle is missing"
    assert matrix.SHUFFLE_SEEDS == EXPECTED_SEEDS

    shuffled = shuffle(seed)
    assert shuffled == shuffle(seed)
    assert Counter(case.name for case in shuffled) == Counter(
        case.name for case in matrix.generated_cases()
    )
    assert tuple(case.name for case in shuffled) != tuple(
        case.name for case in matrix.generated_cases()
    )

    document = matrix.corpus()
    fixture_by_code = {case["elementCode"]: case for case in document["cases"]}
    catalog = element_catalog(str(document["catalogVersion"]))
    for generated in shuffled:
        for element_code in generated.element_codes:
            fixture = fixture_by_code[element_code]
            arguments = dict(fixture["arguments"])
            sides = (
                generated.sides
                if fixture["operation"] == "EMIT_ORDER_CANDIDATE"
                else (generated.sides[0],)
            )
            for side in sides:
                if fixture["operation"] == "EMIT_ORDER_CANDIDATE":
                    arguments.update(
                        allocation="EQUAL",
                        orderType="MARKET",
                        timeInForce="DAY",
                        side=side,
                    )
                try:
                    catalog.validate_step(
                        PlanStep(
                            sequence=1,
                            operation=fixture["operation"],
                            arguments=arguments,
                        )
                    )
                except ElementCompatibilityError as failure:
                    pytest.fail(
                        f"seed={seed} case={generated.name} element={element_code} side={side}: {failure}"
                    )
