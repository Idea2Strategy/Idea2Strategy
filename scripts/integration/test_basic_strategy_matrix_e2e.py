"""Generated complex-shape contract matrix complementing the three-lane runtime proof."""

from __future__ import annotations

import uuid
from collections import Counter
from datetime import timedelta
from decimal import Decimal

import basic_strategy_cases as matrix
import pyarrow as pa
import pyarrow.compute as pc
import pyarrow.parquet as pq
import pytest
from backtest_engine.attempt_coordinator import AttemptCoordinator
from backtest_engine.basic_runtime import (
    BasicDecisionStatus,
    BasicPlanReplay,
    BasicPlanRuntime,
    derive_data_requirements,
)
from backtest_engine.calendar import XNYS_CALENDAR
from backtest_engine.data_availability import (
    AvailabilityStatus,
)
from backtest_engine.elements import (
    ElementCompatibilityError,
    PlanStep,
    element_catalog,
)
from backtest_engine.execution_policy import D17_EXECUTION_POLICY_FIXTURE
from backtest_engine.orchestrator import BacktestJob, BacktestOrchestrator, ReplayStatus
from stored_market_snapshot import INSTRUMENT_ID, load_stored_market_snapshot
from test_orchestrator import (
    WALL_T0,
    FixedMonitor,
    RecordingEngine,
    RecordingPublisher,
    WallClock,
    _policy,
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
EXPECTED_SHAPES = {
    "pairwise-basic_price_compare": ("30m", ("BUY",), 1, 1),
    "pairwise-basic_price_change_percent": ("30m", ("SELL",), 2, 2),
    "pairwise-basic_volume_compare": ("1h", ("BUY",), 3, 3),
    "pairwise-basic_streak": ("1h", ("SELL",), 4, 4),
    "pairwise-basic_sma_cross": ("4h", ("BUY",), 1, 5),
    "pairwise-basic_rsi_cross": ("4h", ("SELL",), 2, 1),
    "pairwise-basic_macd_cross": ("1d", ("BUY",), 3, 2),
    "pairwise-basic_bollinger_reversal": ("1d", ("SELL",), 4, 3),
    "pairwise-basic_position_return": ("30m", ("SELL",), 1, 4),
    "pairwise-basic_holding_period": ("1d", ("SELL",), 2, 5),
    "pairwise-basic_peak_return": ("4h", ("SELL",), 3, 1),
    "pairwise-basic_drawdown_from_peak": ("1d", ("SELL",), 4, 2),
    "pairwise-basic_schedule": ("1d", ("BUY",), 1, 3),
    "maximum-four-partition-five-instrument-two-side": ("30m", ("BUY", "SELL"), 4, 5),
    "contradictory-price-boundaries": ("30m", ("SELL",), 1, 1),
    "duplicate-price-condition": ("30m", ("BUY",), 1, 1),
    "no-signal": ("30m", ("BUY",), 1, 1),
    "missing-required-history": ("4h", ("BUY",), 1, 1),
    "simultaneous-buy-sell": ("30m", ("BUY", "SELL"), 1, 1),
}
EXPECTED_EXECUTIONS = {
    "pairwise-basic_price_compare": (1, "COMPLETED", "AVAILABLE", (("CANDIDATE", 1),)),
    "pairwise-basic_price_change_percent": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("CONDITION_NOT_MET", 2), ("INPUT_MISSING", 2)),
    ),
    "pairwise-basic_volume_compare": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("CONDITION_NOT_MET", 3), ("INPUT_MISSING", 6)),
    ),
    "pairwise-basic_streak": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("CONDITION_NOT_MET", 4), ("INPUT_MISSING", 12)),
    ),
    "pairwise-basic_sma_cross": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("CONDITION_NOT_MET", 1), ("INPUT_MISSING", 4)),
    ),
    "pairwise-basic_rsi_cross": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("CONDITION_NOT_MET", 2),),
    ),
    "pairwise-basic_macd_cross": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("CONDITION_NOT_MET", 3), ("INPUT_MISSING", 3)),
    ),
    "pairwise-basic_bollinger_reversal": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("CONDITION_NOT_MET", 4), ("INPUT_MISSING", 8)),
    ),
    "pairwise-basic_position_return": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("CANDIDATE", 1), ("INPUT_MISSING", 3)),
    ),
    "pairwise-basic_holding_period": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("CONDITION_NOT_MET", 2), ("INPUT_MISSING", 8)),
    ),
    "pairwise-basic_peak_return": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("CONDITION_NOT_MET", 3),),
    ),
    "pairwise-basic_drawdown_from_peak": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("CONDITION_NOT_MET", 4), ("INPUT_MISSING", 4)),
    ),
    "pairwise-basic_schedule": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("CONDITION_NOT_MET", 1), ("INPUT_MISSING", 2)),
    ),
    "maximum-four-partition-five-instrument-two-side": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("CANDIDATE", 1), ("CONDITION_NOT_MET", 4), ("INPUT_MISSING", 35)),
    ),
    "contradictory-price-boundaries": (
        0,
        "COMPLETED",
        "AVAILABLE",
        (("CONDITION_NOT_MET", 1),),
    ),
    "duplicate-price-condition": (1, "COMPLETED", "AVAILABLE", (("CANDIDATE", 1),)),
    "no-signal": (0, "COMPLETED", "AVAILABLE", (("CONDITION_NOT_MET", 1),)),
    "missing-required-history": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("INPUT_MISSING", 1),),
    ),
    "simultaneous-buy-sell": (2, "COMPLETED", "AVAILABLE", (("CANDIDATE", 2),)),
}


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


class _InputIdentityRuntime(BasicPlanRuntime):
    def __init__(self) -> None:
        super().__init__()
        self.input_ids: dict[str, set[int]] = {}

    def evaluation_for(self, instrument_id, instrument_input, as_of):
        self.input_ids.setdefault(instrument_id, set()).add(id(instrument_input))
        return super().evaluation_for(instrument_id, instrument_input, as_of)


class _StoredObjectReader:
    def iter_batches(self, manifest, policy, *, instrument_ids):
        if manifest["resolution"] != "30m":
            return iter(())
        table = pq.read_table(load_stored_market_snapshot().path)
        selected = table.filter(
            pc.and_(
                pc.is_in(
                    table["instrument_id"], value_set=pa.array(list(instrument_ids))
                ),
                pc.and_(
                    pc.greater_equal(
                        table["bar_start_at"], pa.scalar(policy.period_start)
                    ),
                    pc.less(table["bar_start_at"], pa.scalar(policy.period_end)),
                ),
            )
        )
        return iter(selected.to_batches())


class _PositionRecordingEngine(RecordingEngine):
    def runtime_values(self, instant, events):
        values = load_stored_market_snapshot().inputs[INSTRUMENT_ID].values
        return {INSTRUMENT_ID: values}


def _orchestrated_outcome(case, runtime, plan):
    snapshot = load_stored_market_snapshot()
    requirements = derive_data_requirements(
        plan,
        evaluation_from=snapshot.as_of,
        evaluation_through=snapshot.as_of + timedelta(minutes=30),
    )
    resolution = plan.flows[0].reference_series[1]
    manifest = {"resolution": resolution}
    run_id = str(uuid.uuid5(uuid.NAMESPACE_URL, f"task3:{case.name}"))
    job = BacktestJob(
        run_id=run_id,
        idempotency_key=f"TASK3:{case.name}",
        worker_execution_key=f"TASK3:{case.name}:attempt-1",
        manifest=manifest,
        execution_policy=D17_EXECUTION_POLICY_FIXTURE,
        requirements=requirements,
        data_kind="ADJUSTED_BAR",
        resolution=resolution,
        initial_cash=Decimal(100000),
        evaluation_from=snapshot.as_of,
        evaluation_through=snapshot.as_of + timedelta(minutes=30),
    )
    engine = _PositionRecordingEngine()
    publisher = RecordingPublisher()

    def replay_factory(*, clock, assessment):
        return BasicPlanReplay(
            runtime=runtime, plan=plan, clock=clock, assessment=assessment
        )

    orchestrator = BacktestOrchestrator(
        reader=_StoredObjectReader(),
        calendar=XNYS_CALENDAR,
        replay_factory=replay_factory,
        engine=engine,
        publisher=publisher,
        wall_clock=WallClock(),
    )
    coordinator = AttemptCoordinator(run_id, _policy(), WALL_T0)
    lease = coordinator.acquire("task3-worker", WALL_T0)
    outcome = orchestrator.run(
        job, coordinator=coordinator, lease=lease, monitor=FixedMonitor()
    )
    return outcome, len(engine.placed)


def _actual_case_outcome(
    case: matrix.BasicStrategyCase,
) -> tuple[int, ReplayStatus, AvailabilityStatus, tuple[tuple[str, int], ...]]:
    document = matrix.compiled_plan_document(case)
    runtime = _InputIdentityRuntime()
    plan = runtime.load(document)
    snapshot = load_stored_market_snapshot()
    missing = case.input_scenario == "missing"
    execution = runtime.execute(
        plan, {} if missing else snapshot.inputs, as_of=snapshot.as_of
    )
    assert all(len(ids) == 1 for ids in runtime.input_ids.values())
    runtime.input_ids.clear()
    outcome, signal_count = _orchestrated_outcome(case, runtime, plan)
    assert all(len(ids) == 1 for ids in runtime.input_ids.values())
    decision_counts = Counter(decision.status.value for decision in execution.decisions)
    return (
        signal_count,
        outcome.status,
        outcome.availability_status,
        tuple(sorted(decision_counts.items())),
    )


def test_materialized_documents_consume_resolution_side_partition_and_instruments() -> (
    None
):
    by_name = {case.name: case for case in matrix.generated_cases()}

    assert set(by_name) == set(EXPECTED_SHAPES)
    for name, (resolution, sides, partitions, instruments) in EXPECTED_SHAPES.items():
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
        assert all(
            flow.terminal_step.operation == "EMIT_ORDER_CANDIDATE"
            for flow in plan.flows
        )
        assert all(flow.condition_steps for flow in plan.flows)


def test_maximum_distributes_occurrences_without_duplicate_side_containers() -> None:
    case = next(
        case
        for case in matrix.generated_cases()
        if case.name == "maximum-four-partition-five-instrument-two-side"
    )
    document = matrix.compiled_plan_document(case)
    partitions = document["executionSnapshot"]["partitions"]

    assert len(partitions) == 4
    assert all(
        Counter(flow["steps"][-1]["arguments"]["side"] for flow in partition["flows"])
        <= Counter({"BUY": 1, "SELL": 1})
        for partition in partitions
    )
    assert all(
        len(flow["steps"][:-1]) <= 5
        for partition in partitions
        for flow in partition["flows"]
    )
    actual_conditions = Counter(
        step["operation"]
        for partition in partitions
        for flow in partition["flows"]
        for step in flow["steps"][:-1]
    )
    assert actual_conditions == Counter(
        {
            "PRICE_COMPARE": 2,
            "PRICE_CHANGE_PERCENT": 2,
            "VOLUME_COMPARE": 2,
            "STREAK": 2,
            "SMA_CROSS": 2,
            "RSI_CROSS": 2,
            "MACD_CROSS": 2,
            "BOLLINGER_REVERSAL": 2,
            "POSITION_RETURN": 1,
            "HOLDING_PERIOD": 1,
            "PEAK_RETURN": 1,
            "DRAWDOWN_FROM_PEAK": 1,
            "SCHEDULE": 1,
        }
    )


def test_runtime_uses_one_verified_stored_snapshot_without_relabeling_market_values() -> (
    None
):
    snapshot = load_stored_market_snapshot()
    series = snapshot.inputs[INSTRUMENT_ID].series_for("ADJUSTED_BAR", "30m")

    assert (
        snapshot.object_sha256
        == "fa0cebb4e33275239b8ed4f801bdd137508f68bf2b6411f0ab036df3ec283d08"
    )
    assert (
        snapshot.corpus_sha256
        == "961c0b76f5638c397851e1e909acd8d495fa554904a0349b4aa799bbb90f9286"
    )
    assert series is not None
    assert [
        (bar.starts_at.isoformat(), str(bar.close), str(bar.volume))
        for bar in series.bars
    ] == [
        ("2024-01-02T14:30:00+00:00", "341.45", "2977488"),
        ("2024-01-02T15:00:00+00:00", "338.6", "1816210"),
        ("2024-01-02T15:30:00+00:00", "337.74", "1756774"),
        ("2024-01-02T16:00:00+00:00", "341.03", "1357032"),
    ]
    assert snapshot.event_ids == tuple(
        f"bb559227-dec3-54bd-876d-167c12c6e355:{index}" for index in range(1, 5)
    )


def test_special_outcomes_are_observed_from_loaded_plan_and_pinned_owner_inputs() -> (
    None
):
    by_name = {case.name: case for case in matrix.generated_cases()}
    expected = {
        "no-signal": (
            0,
            ReplayStatus.COMPLETED,
            AvailabilityStatus.AVAILABLE,
            ((BasicDecisionStatus.CONDITION_NOT_MET.value, 1),),
        ),
        "missing-required-history": (
            0,
            ReplayStatus.UNAVAILABLE,
            AvailabilityStatus.UNAVAILABLE,
            ((BasicDecisionStatus.INPUT_MISSING.value, 1),),
        ),
        "simultaneous-buy-sell": (
            2,
            ReplayStatus.COMPLETED,
            AvailabilityStatus.AVAILABLE,
            ((BasicDecisionStatus.CANDIDATE.value, 2),),
        ),
        "contradictory-price-boundaries": (
            0,
            ReplayStatus.COMPLETED,
            AvailabilityStatus.AVAILABLE,
            ((BasicDecisionStatus.CONDITION_NOT_MET.value, 1),),
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
            signals, status, availability, decisions = _actual_case_outcome(generated)
            assert (signals, status.value, availability.value, decisions) == (
                EXPECTED_EXECUTIONS[generated.name]
            )
        except Exception as failure:  # noqa: BLE001 - seed/case identity must wrap every owner failure
            pytest.fail(
                f"seed={seed} case={generated.name}: {type(failure).__name__}: {failure}"
            )
