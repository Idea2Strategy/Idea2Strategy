"""Generated complex-shape contract matrix complementing the three-lane runtime proof."""

from __future__ import annotations

from collections import Counter
from dataclasses import replace
from datetime import timedelta

import basic_strategy_cases as matrix
import pytest
from backtest_engine.basic_runtime import (
    BasicDecisionStatus,
    BasicPlanRuntime,
    derive_data_requirements,
)
from backtest_engine.data_availability import (
    AvailabilityStatus,
    DataAvailabilityAssessor,
)
from backtest_engine.elements import (
    ElementCompatibilityError,
    ElementEvaluation,
    InstrumentInput,
    PinnedFeatureValue,
    PlanStep,
    element_catalog,
)
from backtest_engine.orchestrator import ReplayStatus
from test_basic_element_conformance import _evaluation

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
    contradiction = by_name["contradictory-price-boundaries"]
    drawdowns = [
        step for step in contradiction.steps if step.operation == "DRAWDOWN_FROM_PEAK"
    ]
    assert [step.arguments for step in drawdowns] == [
        {"operator": "GTE", "thresholdPercent": "10"},
        {"operator": "LT", "thresholdPercent": "5"},
    ]
    duplicate = by_name["duplicate-price-condition"]
    assert duplicate.element_codes.count("BASIC_PRICE_COMPARE") == 2
    assert duplicate.steps[0].arguments == duplicate.steps[1].arguments
    assert by_name["no-signal"].input_scenario == "false"
    assert by_name["missing-required-history"].input_scenario == "missing"
    simultaneous = by_name["simultaneous-buy-sell"]
    assert simultaneous.sides == ("BUY", "SELL")


def test_numeric_oracle_covers_every_published_boundary_independently() -> None:
    factory = getattr(matrix, "numeric_validation_cases", None)
    assert callable(factory), "numeric validation oracle is missing"
    cases = factory()

    assert len(cases) == 89
    assert (
        len(
            {
                (case.operation, case.parameter, case.arguments[case.parameter])
                for case in cases
            }
        )
        == 78
    )
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


def _evaluation_for(
    step: PlanStep, instrument_id: str, passed: bool
) -> ElementEvaluation:
    """Retarget one stored conformance input; never invent or aggregate OHLCV."""
    pinned = _evaluation(step.operation, passed)
    resolution = step.arguments.get("resolution")
    values: dict[str, str] = {}
    for key, value in pinned.inputs.values.items():
        prefix, separator, suffix = key.rpartition(".")
        if resolution and separator and suffix in matrix.RESOLUTIONS:
            key = f"{prefix}.{resolution}"
        values[key] = value
    periods = {
        "30m": timedelta(minutes=30),
        "1h": timedelta(hours=1),
        "4h": timedelta(hours=4),
        "1d": timedelta(days=1),
    }
    feature_series = tuple(
        replace(
            series,
            instrument_id=instrument_id,
            resolution=resolution or series.resolution,
            values=tuple(
                PinnedFeatureValue(
                    pinned.as_of
                    - periods[resolution or series.resolution]
                    * (len(series.values) - index),
                    value.value,
                )
                for index, value in enumerate(series.values)
            ),
        )
        for series in pinned.inputs.feature_series
    )
    return ElementEvaluation(
        instrument_id=instrument_id,
        as_of=pinned.as_of,
        inputs=InstrumentInput(
            instrument_id=instrument_id,
            series=(),
            feature_series=feature_series,
            require_pinned_features=bool(feature_series),
            values=values,
        ),
    )


def _actual_case_outcome(
    case: matrix.BasicStrategyCase,
) -> tuple[int, ReplayStatus, AvailabilityStatus]:
    document = matrix.compiled_plan_document(case)
    runtime = BasicPlanRuntime()
    plan = runtime.load(document)
    if case.input_scenario == "missing":
        execution = runtime.execute(
            plan, {}, as_of=_evaluation("MACD_CROSS", True).as_of
        )
        assert {decision.status for decision in execution.decisions} == {
            BasicDecisionStatus.INPUT_MISSING
        }
        requirements = derive_data_requirements(
            plan,
            evaluation_from=_evaluation("MACD_CROSS", True).as_of,
            evaluation_through=_evaluation("MACD_CROSS", True).as_of
            + timedelta(hours=1),
        )
        availability = DataAvailabilityAssessor().assess(requirements, []).status
        return 0, ReplayStatus.UNAVAILABLE, availability

    if case.input_scenario == "false":
        inputs = {
            instrument_id: _evaluation_for(
                flow.condition_steps[0], instrument_id, False
            ).inputs
            for flow in plan.flows
            for instrument_id in flow.instrument_ids
        }
        execution = runtime.execute(
            plan, inputs, as_of=_evaluation("PRICE_CHANGE_PERCENT", False).as_of
        )
        assert {decision.status for decision in execution.decisions} == {
            BasicDecisionStatus.CONDITION_NOT_MET
        }
        return 0, ReplayStatus.COMPLETED, AvailabilityStatus.AVAILABLE

    signals = 0
    for flow in plan.flows:
        for instrument_id in flow.instrument_ids:
            passed = True
            for step in flow.condition_steps:
                outcome = plan.catalog.evaluate(
                    step,
                    _evaluation_for(step, instrument_id, case.input_scenario == "true"),
                )
                if not outcome.is_passed:
                    passed = False
                    break
            signals += int(passed)
    return signals, ReplayStatus.COMPLETED, AvailabilityStatus.AVAILABLE


def test_materialized_documents_consume_resolution_side_partition_and_instruments() -> (
    None
):
    expected_shapes = {
        "pairwise-basic_price_compare": ("30m", ("BUY",), 1, 1),
        "maximum-four-partition-five-instrument-two-side": (
            "30m",
            ("BUY", "SELL"),
            4,
            5,
        ),
        "simultaneous-buy-sell": ("1d", ("BUY", "SELL"), 1, 1),
    }
    by_name = {case.name: case for case in matrix.generated_cases()}

    for name, (resolution, sides, partitions, instruments) in expected_shapes.items():
        case = by_name[name]
        semantic = matrix.semantic_document(case)
        compiled = matrix.compiled_plan_document(case)
        plan = BasicPlanRuntime().load(compiled)

        assert {group["container"] for group in semantic["groups"]} == set(sides)
        assert all(
            len(
                [
                    block
                    for block in group["blocks"]
                    if block["elementCode"] != "BASIC_EQUAL_ALLOCATION_ORDER"
                ]
            )
            <= 5
            for group in semantic["groups"]
        )
        assert len(compiled["executionSnapshot"]["partitions"]) == partitions
        assert {flow.side for flow in plan.flows} == set(sides)
        assert len(plan.instrument_ids) == instruments
        assert {flow.reference_series for flow in plan.flows} == {
            ("ADJUSTED_BAR", resolution)
        }


def test_special_outcomes_are_observed_from_loaded_plan_and_pinned_owner_inputs() -> (
    None
):
    by_name = {case.name: case for case in matrix.generated_cases()}
    expected = {
        "no-signal": (0, ReplayStatus.COMPLETED, AvailabilityStatus.AVAILABLE),
        "missing-required-history": (
            0,
            ReplayStatus.UNAVAILABLE,
            AvailabilityStatus.UNAVAILABLE,
        ),
        "simultaneous-buy-sell": (
            2,
            ReplayStatus.COMPLETED,
            AvailabilityStatus.AVAILABLE,
        ),
        "contradictory-price-boundaries": (
            0,
            ReplayStatus.COMPLETED,
            AvailabilityStatus.AVAILABLE,
        ),
    }

    assert {name: _actual_case_outcome(by_name[name]) for name in expected} == expected


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

    for generated in shuffled:
        try:
            semantic = matrix.semantic_document(generated)
            assert semantic["groups"]
            BasicPlanRuntime().load(matrix.compiled_plan_document(generated))
            _actual_case_outcome(generated)
        except Exception as failure:  # noqa: BLE001 - seed/case identity must wrap every owner failure
            pytest.fail(
                f"seed={seed} case={generated.name}: {type(failure).__name__}: {failure}"
            )
