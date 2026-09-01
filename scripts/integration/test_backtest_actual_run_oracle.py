from __future__ import annotations

import hashlib
from collections import deque
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal

import pytest
from backtest_actual_run_oracle import (
    DatasetCandidate,
    ExactObject,
    MarketBar,
    TriggerInputMissing,
    bar_identity,
    build_trigger_contexts,
    consume_fifo,
    evaluate_trigger_step,
    exact_fill_bar,
    exact_flow_resolution,
    exact_object_bytes,
    expected_fill_values,
    expected_trigger_order_id,
    infer_side,
    latest_market_bars_by_instant,
    market_bar_from_row,
    minimum_manifest_cover,
    order_fills_by_cash_chain,
    require_exact_manifest_pairs,
    result_hash_evidence,
    row_is_replay_eligible,
    sorted_trigger_semantics,
    validate_result_families,
)


def _trigger_bar(
    *,
    offset: int,
    close: str,
    volume: str = "100",
    resolution: str = "30m",
) -> MarketBar:
    starts_at = datetime(2024, 1, 2, 14, 30, tzinfo=UTC) + timedelta(
        minutes=30 * offset
    )
    return MarketBar(
        instrument_id="instrument-1",
        resolution=resolution,
        starts_at=starts_at,
        ends_at=starts_at + timedelta(minutes=30),
        session_date_et=date(2024, 1, 2),
        open=Decimal(close),
        high=Decimal(close),
        low=Decimal(close),
        close=Decimal(close),
        volume=Decimal(volume),
    )


def test_trigger_oracle_recomputes_raw_cross_and_context_conditions() -> None:
    bars = tuple(
        _trigger_bar(offset=index, close=close, volume=volume)
        for index, (close, volume) in enumerate(
            (("3", "80"), ("2", "90"), ("1", "100"), ("4", "120"))
        )
    )
    instant = bars[-1].ends_at

    assert evaluate_trigger_step(
        {
            "operation": "SMA_CROSS",
            "arguments": {
                "direction": "UP",
                "shortPeriod": "2",
                "longPeriod": "3",
                "resolution": "30m",
            },
        },
        bars,
        as_of=instant,
    )
    assert evaluate_trigger_step(
        {
            "operation": "VOLUME_COMPARE",
            "arguments": {
                "operator": "GTE",
                "reference": "PREVIOUS_VOLUME",
                "period": "1",
                "multiplier": "1",
                "resolution": "30m",
            },
        },
        bars,
        as_of=instant,
    )
    assert evaluate_trigger_step(
        {
            "operation": "POSITION_RETURN",
            "arguments": {"direction": "LOSS", "thresholdPercent": "0"},
        },
        bars,
        as_of=instant,
        position_values={"returnPercent": Decimal("-0.00000001")},
    )
    assert evaluate_trigger_step(
        {
            "operation": "SCHEDULE",
            "arguments": {"cycle": "EVERY_TRADING_DAY", "interval": "1"},
        },
        bars,
        as_of=instant,
        schedule_values={"newTradingDay": True, "tradingDayIndex": 7},
    )


def test_trigger_order_identity_binds_plan_instant_flow_and_instrument() -> None:
    assert (
        expected_trigger_order_id(
            run_snapshot_id="run-snapshot",
            plan_checksum="sha256:" + "a" * 64,
            occurred_at=datetime(2024, 1, 2, 15, tzinfo=UTC),
            flow_id="flow-1",
            instrument_id="instrument-1",
        )
        == "c03b3e97-6214-5ab8-8196-c9ccc8bab0b8"
    )


def test_position_trigger_context_counts_the_entry_bar_before_evaluation() -> None:
    entry = _trigger_bar(offset=0, close="100")
    later = _trigger_bar(offset=1, close="110")
    fill_states = (
        (
            entry.ends_at,
            Decimal(900),
            {"instrument-1": (Decimal(1), Decimal(100))},
            {"instrument-1": entry.starts_at},
        ),
    )

    position, schedule = build_trigger_contexts(
        (entry, later),
        fill_states=fill_states,
        session_hours={
            date(2024, 1, 2): (
                datetime(2024, 1, 2, 14, 30, tzinfo=UTC),
                datetime(2024, 1, 2, 21, tzinfo=UTC),
            )
        },
        period_start=datetime(2024, 1, 2, 14, 30, tzinfo=UTC),
        period_end=datetime(2024, 1, 3, tzinfo=UTC),
    )

    assert position[(entry.ends_at, "instrument-1")] == {
        "averageEntryPrice": Decimal("100.00000000"),
        "returnPercent": Decimal("0E-8"),
        "peakReturnPercent": Decimal("0E-8"),
        "drawdownPercent": Decimal("0E-8"),
        "holdingTradingDays": 0,
        "holdingBars.30m": 1,
        "holdingBars.1h": 0,
        "holdingBars.4h": 0,
        "holdingBars.1d": 0,
    }
    assert position[(later.ends_at, "instrument-1")]["holdingBars.30m"] == 2
    assert position[(later.ends_at, "instrument-1")]["peakReturnPercent"] == Decimal(
        "10.00000000"
    )
    assert schedule[entry.ends_at]["newTradingDay"] is True
    assert schedule[later.ends_at]["newTradingDay"] is False


def test_position_only_flow_resolves_its_clock_from_exact_pinned_partition() -> None:
    flow = {
        "key": "sell-flow",
        "officialInstrumentIds": ["instrument-1"],
        "steps": [
            {
                "operation": "POSITION_RETURN",
                "arguments": {"direction": "LOSS", "thresholdPercent": "1"},
            },
            {"operation": "EMIT_ORDER_CANDIDATE", "arguments": {"side": "SELL"}},
        ],
    }

    assert (
        exact_flow_resolution(
            flow,
            {("instrument-1", "1d"), ("unrelated-instrument", "30m")},
        )
        == "1d"
    )


def test_required_manifest_pairs_reject_an_omitted_pair_or_unrelated_cross_product() -> (
    None
):
    plan = {
        "executionSnapshot": {
            "partitions": [
                {
                    "flows": [
                        {
                            "key": "aapl-buy",
                            "officialInstrumentIds": ["aapl"],
                            "steps": [
                                {
                                    "operation": "PRICE_COMPARE",
                                    "arguments": {"resolution": "30m"},
                                }
                            ],
                        },
                        {
                            "key": "aapl-sell",
                            "officialInstrumentIds": ["aapl"],
                            "steps": [
                                {
                                    "operation": "POSITION_RETURN",
                                    "arguments": {"thresholdPercent": "1"},
                                }
                            ],
                        },
                        {
                            "key": "msft-buy",
                            "officialInstrumentIds": ["msft"],
                            "steps": [
                                {
                                    "operation": "PRICE_COMPARE",
                                    "arguments": {"resolution": "1d"},
                                }
                            ],
                        },
                    ]
                }
            ]
        }
    }

    assert require_exact_manifest_pairs(plan, {("aapl", "30m"), ("msft", "1d")}) == {
        ("aapl", "30m"),
        ("msft", "1d"),
    }
    with pytest.raises(AssertionError, match="missing=.*msft.*1d"):
        require_exact_manifest_pairs(plan, {("aapl", "30m")})
    with pytest.raises(AssertionError, match="unrelated=.*meta.*4h"):
        require_exact_manifest_pairs(
            plan,
            {("aapl", "30m"), ("msft", "1d"), ("meta", "4h")},
        )


def test_trigger_warmup_gap_is_typed_separately_from_a_false_condition() -> None:
    only_bar = _trigger_bar(offset=0, close="100")

    with pytest.raises(TriggerInputMissing, match="previous close"):
        evaluate_trigger_step(
            {
                "operation": "PRICE_COMPARE",
                "arguments": {
                    "operator": "GT",
                    "reference": "PREVIOUS_CLOSE",
                    "resolution": "30m",
                },
            },
            (only_bar,),
            as_of=only_bar.ends_at,
        )


def test_trigger_semantics_ignore_run_specific_record_order_at_same_instant() -> None:
    first = {
        "occurredAt": "2024-01-02T15:00:00Z",
        "instrumentId": "instrument-1",
        "flowId": "flow-a",
        "recordKind": "ORDER",
        "conditions": [[1, "PRICE_COMPARE"]],
    }
    second = {
        **first,
        "flowId": "flow-b",
        "recordKind": "REJECTION",
    }

    assert sorted_trigger_semantics([second, first]) == [first, second]
    assert sorted_trigger_semantics([first, second]) == [first, second]


def test_fill_math_is_hand_calculated_at_eight_decimal_places() -> None:
    assert expected_fill_values(
        base_price=Decimal("100.25000000"),
        quantity=Decimal("122.00000000"),
        side="BUY",
        slippage_bps=Decimal(5),
        fee_rate=Decimal("0.002"),
    ) == (
        Decimal("100.30012500"),
        Decimal("12236.61525000"),
        Decimal("6.11525000"),
        Decimal("24.47323050"),
    )


def test_fifo_oracle_consumes_partial_lots_without_production_helpers() -> None:
    lots = deque(
        ([Decimal(2), Decimal("20.00000000")], [Decimal(3), Decimal("36.00000000")])
    )

    assert consume_fifo(lots, Decimal(4)) == Decimal("44.00000000")
    assert lots == deque(([Decimal(1), Decimal("12.00000000")],))


def test_ledger_side_requires_exactly_one_security_entry() -> None:
    assert infer_side([{"account_code": "SECURITY", "direction": "DEBIT"}]) == "BUY"
    assert infer_side([{"account_code": "SECURITY", "direction": "CREDIT"}]) == "SELL"
    with pytest.raises(AssertionError, match="exactly one"):
        infer_side([])


def test_exact_object_fetch_always_names_the_immutable_provider_version() -> None:
    body = b"immutable parquet bytes"
    calls = []

    class Body:
        def read(self):
            return body

    class S3:
        def get_object(self, **kwargs):
            calls.append(kwargs)
            return {"Body": Body()}

    reference = ExactObject(
        bucket="market",
        key="bars.parquet",
        version_id="version-7",
        content_hash=hashlib.sha256(body).hexdigest(),
        byte_size=len(body),
    )

    assert exact_object_bytes(S3(), reference) == body
    assert calls == [
        {"Bucket": "market", "Key": "bars.parquet", "VersionId": "version-7"}
    ]


def test_bar_identity_keeps_mixed_resolutions_separate_at_the_same_instant() -> None:
    row = {
        "instrument_id": "instrument-1",
        "bar_start_at": "2024-01-02T14:30:00Z",
    }

    assert bar_identity("30m", row) != bar_identity("1d", row)


def test_latest_market_bars_are_resolved_in_one_chronological_pass() -> None:
    day = date(2024, 1, 2)
    start = datetime(2024, 1, 2, 14, 30, tzinfo=UTC)

    def bar(resolution: str, minutes: int, close: str) -> MarketBar:
        return MarketBar(
            instrument_id="aapl",
            resolution=resolution,
            starts_at=start,
            ends_at=start + timedelta(minutes=minutes),
            session_date_et=day,
            open=Decimal(close),
            high=Decimal(close),
            low=Decimal(close),
            close=Decimal(close),
            volume=Decimal(1),
        )

    event_bars = [bar("30m", 30, "100"), bar("1d", 390, "101")]
    snapshots = latest_market_bars_by_instant(
        event_bars,
        [
            start + timedelta(minutes=29),
            start + timedelta(minutes=30),
            start + timedelta(minutes=390),
        ],
    )

    assert snapshots[0] == {}
    assert snapshots[1]["aapl"].close == Decimal(100)
    assert snapshots[2]["aapl"].close == Decimal(101)


def test_partial_fill_matches_its_own_later_exact_bar_not_only_the_first_bar() -> None:
    day = date(2024, 1, 2)
    submitted = datetime(2024, 1, 2, 14, 30, tzinfo=UTC)

    def bar(offset: int, open_price: str) -> MarketBar:
        starts_at = submitted + timedelta(minutes=offset)
        return MarketBar(
            instrument_id="aapl",
            resolution="30m",
            starts_at=starts_at,
            ends_at=starts_at + timedelta(minutes=30),
            session_date_et=day,
            open=Decimal(open_price),
            high=Decimal(open_price),
            low=Decimal(open_price),
            close=Decimal(open_price),
            volume=Decimal(1000),
        )

    first, later = bar(0, "100"), bar(30, "99")

    assert (
        exact_fill_bar(
            [first, later],
            instrument_id="aapl",
            order_at=submitted,
            fill_at=later.ends_at,
            base_price=Decimal("99.00000000"),
        )
        == later
    )


def test_daily_bar_uses_explicit_session_close_not_provider_source_minutes() -> None:
    opens_at = datetime(2018, 5, 2, 13, 30, tzinfo=UTC)
    closes_at = datetime(2018, 5, 2, 20, 0, tzinfo=UTC)
    row = {
        "bar_start_at": datetime(2018, 5, 2, tzinfo=UTC),
        "session_date_et": date(2018, 5, 2),
        "source_minutes": 210,
        "open": 87.23,
        "high": 88.0,
        "low": 87.0,
        "close": 87.9,
        "volume": 1000,
    }

    actual = market_bar_from_row(
        instrument_id="msft",
        resolution="1d",
        row=row,
        session_opens_at=opens_at,
        session_closes_at=closes_at,
    )

    assert actual.starts_at == opens_at
    assert actual.ends_at == closes_at


def test_source_row_at_half_open_policy_end_is_verified_but_not_replayed() -> None:
    period_start = datetime(2016, 1, 1, 5, tzinfo=UTC)
    period_end = datetime(2026, 7, 30, 4, tzinfo=UTC)

    assert row_is_replay_eligible(
        {"bar_start_at": period_end - timedelta(microseconds=1)},
        period_start=period_start,
        period_end=period_end,
    )
    assert not row_is_replay_eligible(
        {"bar_start_at": period_end},
        period_start=period_start,
        period_end=period_end,
    )


def test_fill_cash_chain_is_reconstructed_without_result_row_order() -> None:
    buy = {
        "fill_id": "buy",
        "gross_amount": "100.00000000",
        "fee": "1.00000000",
        "cash_after": "899.00000000",
    }
    sell = {
        "fill_id": "sell",
        "gross_amount": "110.00000000",
        "fee": "1.00000000",
        "cash_after": "1008.00000000",
    }
    ledgers = {
        "buy": [{"account_code": "SECURITY", "direction": "DEBIT"}],
        "sell": [{"account_code": "SECURITY", "direction": "CREDIT"}],
    }

    assert order_fills_by_cash_chain([sell, buy], ledgers, Decimal(1000)) == [buy, sell]


def test_no_signal_result_may_omit_empty_trade_ledger_and_position_families() -> None:
    validate_result_families({"CALCULATION_SERIES": [{"metric_id": "equity"}]})

    with pytest.raises(AssertionError, match="ledger and position"):
        validate_result_families(
            {
                "CALCULATION_SERIES": [{"metric_id": "equity"}],
                "TRADE_DETAIL": [{"kind": "FILL"}],
            }
        )


def test_minimum_cover_is_scoped_deterministic_and_not_a_manifest_cross_product() -> (
    None
):
    candidates = (
        DatasetCandidate(
            "global-new",
            None,
            "1d",
            9,
            "2024-01-01",
            "2026-01-01",
            "2026-01-02T00:00:00Z",
        ),
        DatasetCandidate(
            "aapl-full",
            "aapl",
            "1d",
            1,
            "2024-01-01",
            "2026-01-01",
            "2026-01-01T00:00:00Z",
        ),
        DatasetCandidate(
            "aapl-2024",
            "aapl",
            "1d",
            8,
            "2024-01-01",
            "2025-01-01",
            "2026-01-02T00:00:00Z",
        ),
        DatasetCandidate(
            "aapl-2025",
            "aapl",
            "1d",
            8,
            "2025-01-01",
            "2026-01-01",
            "2026-01-02T00:00:00Z",
        ),
        DatasetCandidate(
            "msft-full",
            "msft",
            "1d",
            10,
            "2024-01-01",
            "2026-01-01",
            "2026-01-03T00:00:00Z",
        ),
    )

    selected = minimum_manifest_cover(
        candidates,
        instrument_id="aapl",
        resolution="1d",
        coverage_start="2024-02-01",
        coverage_end="2025-12-01",
    )

    assert [item.manifest_id for item in selected] == ["aapl-full"]


def test_result_hash_chain_uses_exact_decimal_text_and_canonical_material() -> None:
    evidence = result_hash_evidence(
        run_payload={
            "backtest_run_id": "00000000-0000-4000-8000-000000000001",
            "strategy_version_id": "00000000-0000-4000-8000-000000000002",
            "input_bundle_fingerprint": "1" * 64,
            "calculation_model_version": "backtest-calculation-v1",
            "cost_model_version": "backtest-cost:1.0.0",
            "execution_model_version": "backtest-execution:1.0.0",
            "initial_cash": "100000",
        },
        records=[],
        calculated_at="2026-01-02T03:04:05Z",
        valuation={
            "basis": "MARK_TO_MARKET",
            "basis_rule_id": "equity.valuation:mark_to_market:1.0.0",
            "periodicity": "DAILY",
            "opening_at": "2024-01-02T20:59:59.999999Z",
            "instants": [{"as_of": "2024-01-02T21:00:00Z", "marks": []}],
        },
        equity_curve={
            "basis": "MARK_TO_MARKET",
            "periodicity": "DAILY",
            "points": [
                {
                    "as_of": "2024-01-02T20:59:59.999999Z",
                    "cash": "100000.00000000",
                    "position_value": "0.00000000",
                    "equity": "100000.00000000",
                    "holdings": [],
                },
                {
                    "as_of": "2024-01-02T21:00:00Z",
                    "cash": "100000.00000000",
                    "position_value": "0.00000000",
                    "equity": "100000.00000000",
                    "holdings": [],
                },
            ],
        },
        metrics=[["fillCount", "metric.fill_count:1.0.0", "COUNT", "0"]],
    )

    assert evidence == {
        "run_snapshot_id": "d80c9bfaddb674f47e64bac37b798f8d089f6f549f07d7c70ca123d97b1efdeb",
        "source_set_hash": "1db0eee4a9697fc3f1845bf9a2e3e667477cae654a13b97b46f28bb3132d224e",
        "input_hash": "cb61fd3ebb2c718bab44f04ce0afebdc7b7711a5baa4abbc7db51284e9ce949a",
        "result_hash": "78598b3c777879c28029d513c7e00d057b3f9d074f8eb3c2206ded5b47ab64c2",
    }
