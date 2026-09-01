"""Independent actual-data reconciliation for one completed backtest run.

This audit program deliberately imports no backtest-engine calculation code.  It reads the
immutable database pins and S3 objects, recomputes execution/accounting values with Decimal, and
prints a JSON receipt suitable for attaching to a release audit.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import uuid
from bisect import bisect_left, bisect_right
from collections import defaultdict, deque
from collections.abc import Iterable, Mapping, Sequence
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta
from decimal import ROUND_HALF_EVEN, ROUND_HALF_UP, Context, Decimal, localcontext
from io import BytesIO
from itertools import pairwise
from typing import Any
from zoneinfo import ZoneInfo

import boto3
import pyarrow.parquet as pq
from sqlalchemy import create_engine, text

MONEY = Decimal("0.00000001")
RETURN_QUANTUM = Decimal("0.00000001")
WORKING_PRECISION = 50
ET = ZoneInfo("America/New_York")
TRIGGER_MATH = Context(prec=18, rounding=ROUND_HALF_UP)
EVALUATION_ID_NAMESPACE = uuid.UUID("6f5f4d8c-9a5b-4a3e-9b2f-1d0c8e7a6b54")
ORDER_ID_NAMESPACE = uuid.UUID("2c1c1d0e-1f4b-4d67-9a2a-6a7f4a1b9c31")

METRIC_RULES: Mapping[str, tuple[str, str]] = {
    "annualizedVolatilityPct": ("metric.annualized_volatility_pct:1.0.0", "PERCENT"),
    "closingTradeCount": ("metric.closing_trade_count:1.0.0", "COUNT"),
    "endingCash": ("metric.ending_cash:1.0.0", "MONEY"),
    "endingEquity": ("metric.ending_equity:1.0.0", "MONEY"),
    "fillCount": ("metric.fill_count:1.0.0", "COUNT"),
    "losingTradeCount": ("metric.losing_trade_count:1.0.0", "COUNT"),
    "maxDrawdownPct": ("metric.max_drawdown_pct:1.0.0", "PERCENT"),
    "realizedPnl": ("metric.realized_pnl:1.0.0", "MONEY"),
    "sharpe": ("metric.sharpe_ratio:1.0.0", "RATIO"),
    "startingEquity": ("metric.starting_equity:1.0.0", "MONEY"),
    "totalFees": ("metric.total_fees:1.0.0", "MONEY"),
    "totalReturnPct": ("metric.total_return_pct:1.0.0", "PERCENT"),
    "totalSlippage": ("metric.total_slippage:1.0.0", "MONEY"),
    "valuationPointCount": ("metric.valuation_point_count:1.0.0", "COUNT"),
    "winRatePct": ("metric.win_rate_pct:1.0.0", "PERCENT"),
    "winningTradeCount": ("metric.winning_trade_count:1.0.0", "COUNT"),
}


@dataclass(frozen=True, slots=True)
class ExactObject:
    bucket: str
    key: str
    version_id: str
    content_hash: str
    byte_size: int


@dataclass(frozen=True, slots=True)
class DatasetCandidate:
    manifest_id: str
    instrument_id: str | None
    resolution: str
    revision: int
    period_start: str
    period_end: str
    available_at: str


@dataclass(frozen=True, slots=True)
class MarketBar:
    instrument_id: str
    resolution: str
    starts_at: datetime
    ends_at: datetime
    session_date_et: date
    open: Decimal
    high: Decimal
    low: Decimal
    close: Decimal
    volume: Decimal


class TriggerInputMissing(AssertionError):
    """An independent trigger could not yet be evaluated from available history."""


def latest_market_bars_by_instant(
    event_bars: Sequence[MarketBar],
    instants: Sequence[datetime],
) -> list[dict[str, MarketBar]]:
    """Resolve latest marks with one monotonic pass over already-sorted bars."""
    latest: dict[str, MarketBar] = {}
    snapshots: list[dict[str, MarketBar]] = []
    cursor = 0
    prior_instant: datetime | None = None
    for instant in instants:
        if prior_instant is not None and instant < prior_instant:
            raise AssertionError("valuation instants are not chronological")
        while cursor < len(event_bars) and event_bars[cursor].ends_at <= instant:
            bar = event_bars[cursor]
            latest[bar.instrument_id] = bar
            cursor += 1
        snapshots.append(dict(latest))
        prior_instant = instant
    return snapshots


def exact_fill_bar(
    market_bars: Sequence[MarketBar],
    *,
    instrument_id: str,
    order_at: datetime,
    fill_at: datetime,
    base_price: Decimal,
) -> MarketBar:
    """Bind one (possibly partial) fill to its unique immutable execution bar."""
    matches = [
        bar
        for bar in market_bars
        if bar.instrument_id == instrument_id
        and bar.starts_at >= order_at
        and bar.ends_at == fill_at
        and money(bar.open) == money(base_price)
    ]
    if len(matches) != 1:
        facts = [
            (
                bar.resolution,
                _timestamp(bar.starts_at),
                _timestamp(bar.ends_at),
                _money_text(bar.open),
            )
            for bar in market_bars
            if bar.instrument_id == instrument_id
            and (bar.ends_at == fill_at or (order_at <= bar.starts_at <= fill_at))
        ]
        raise AssertionError(
            "fill does not bind to one unique pinned bar after its order: "
            f"instrument={instrument_id} order={_timestamp(order_at)} "
            f"fill={_timestamp(fill_at)} base={_money_text(base_price)} candidates={facts}"
        )
    return matches[0]


def market_bar_from_row(
    *,
    instrument_id: str,
    resolution: str,
    row: Mapping[str, Any],
    session_opens_at: datetime,
    session_closes_at: datetime,
) -> MarketBar:
    """Sessionize one exact provider row from independent calendar evidence."""
    provider_starts_at = row["bar_start_at"].astimezone(UTC)
    starts_at = session_opens_at if resolution == "1d" else provider_starts_at
    if not session_opens_at <= starts_at < session_closes_at:
        raise AssertionError(
            "source bar starts outside its explicit regular session: "
            f"{instrument_id}/{resolution} {starts_at}"
        )
    ends_at = min(
        starts_at + timedelta(minutes=_resolution_minutes(resolution)),
        session_closes_at,
    )
    if ends_at <= starts_at:
        raise AssertionError("source bar has a non-positive sessionized interval")
    return MarketBar(
        instrument_id=instrument_id,
        resolution=resolution,
        starts_at=starts_at,
        ends_at=ends_at,
        session_date_et=row["session_date_et"],
        open=Decimal(str(row["open"])),
        high=Decimal(str(row["high"])),
        low=Decimal(str(row["low"])),
        close=Decimal(str(row["close"])),
        volume=Decimal(str(row["volume"])),
    )


def row_is_replay_eligible(
    row: Mapping[str, Any],
    *,
    period_start: datetime,
    period_end: datetime,
) -> bool:
    """Mirror only the public half-open timestamp boundary, not engine logic."""
    starts_at = row["bar_start_at"].astimezone(UTC)
    return period_start <= starts_at < period_end


def exact_object_bytes(s3: Any, reference: ExactObject) -> bytes:
    """Fetch and verify one immutable object version, never the mutable latest key."""
    if not reference.version_id:
        raise AssertionError("exact object has no provider version")
    body = s3.get_object(
        Bucket=reference.bucket,
        Key=reference.key,
        VersionId=reference.version_id,
    )["Body"].read()
    if len(body) != reference.byte_size:
        raise AssertionError(f"object size mismatch: {reference.key}")
    if hashlib.sha256(body).hexdigest() != reference.content_hash.removeprefix(
        "sha256:"
    ):
        raise AssertionError(f"object hash mismatch: {reference.key}")
    return body


def bar_identity(resolution: str, row: dict[str, Any]) -> tuple[str, str, str]:
    return (
        str(row["instrument_id"]),
        resolution,
        str(row["bar_start_at"]),
    )


def _parse_date(value: str) -> date:
    return date.fromisoformat(value[:10])


def minimum_manifest_cover(
    candidates: Iterable[DatasetCandidate],
    *,
    instrument_id: str,
    resolution: str,
    coverage_start: str,
    coverage_end: str,
) -> tuple[DatasetCandidate, ...]:
    """Independently solve the strict exact-instrument minimum interval cover."""
    start = _parse_date(coverage_start)
    end = _parse_date(coverage_end)
    eligible = tuple(
        candidate
        for candidate in candidates
        if candidate.instrument_id == instrument_id
        and candidate.resolution.lower() == resolution.lower()
    )

    def ranking(path: tuple[DatasetCandidate, ...]) -> tuple[Any, ...]:
        ordered = tuple(
            sorted(
                path,
                key=lambda item: (
                    _parse_date(item.period_start),
                    _parse_date(item.period_end),
                    item.manifest_id,
                ),
            )
        )
        revisions = tuple(
            -value
            for value in sorted((item.revision for item in ordered), reverse=True)
        )
        availability = tuple(
            -datetime.fromisoformat(
                item.available_at.replace("Z", "+00:00")
            ).timestamp()
            for item in sorted(
                ordered, key=lambda item: item.available_at, reverse=True
            )
        )
        outside = (start - _parse_date(ordered[0].period_start)).days + (
            _parse_date(ordered[-1].period_end) - end
        ).days
        return (
            len(ordered),
            revisions,
            availability,
            outside,
            tuple(item.manifest_id for item in ordered),
        )

    def paths(
        cursor: date, used: frozenset[str]
    ) -> Iterable[tuple[DatasetCandidate, ...]]:
        for candidate in eligible:
            candidate_start = _parse_date(candidate.period_start)
            candidate_end = _parse_date(candidate.period_end)
            begins = (
                candidate_start <= cursor
                if cursor == start
                else candidate_start == cursor
            )
            if candidate.manifest_id in used or not begins or candidate_end <= cursor:
                continue
            if candidate_end >= end:
                yield (candidate,)
            else:
                for suffix in paths(candidate_end, used | {candidate.manifest_id}):
                    yield (candidate, *suffix)

    choices = tuple(paths(start, frozenset()))
    if not choices:
        raise AssertionError(
            f"no exact {instrument_id}/{resolution} manifest cover for {start}..{end}"
        )
    return tuple(
        sorted(
            min(choices, key=ranking),
            key=lambda item: (_parse_date(item.period_start), item.manifest_id),
        )
    )


def _canonical_hash(value: Any) -> str:
    return hashlib.sha256(
        json.dumps(
            value,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
    ).hexdigest()


def sorted_trigger_semantics(
    values: Sequence[dict[str, Any]],
) -> list[dict[str, Any]]:
    """Canonicalize the semantic multiset without run-specific record ordering."""
    return sorted(
        values,
        key=lambda value: json.dumps(
            value,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        ),
    )


def result_hash_evidence(
    *,
    run_payload: dict[str, Any],
    records: list[dict[str, Any]],
    calculated_at: str,
    valuation: dict[str, Any],
    equity_curve: dict[str, Any],
    metrics: list[list[str | None]],
) -> dict[str, str]:
    """Reproduce the four public hash domains from independently built material."""
    run_snapshot_id = _canonical_hash(run_payload)
    source_set_hash = _canonical_hash(
        {
            "domain": "backtest.performance.source_set:1.0.0",
            "run_snapshot": run_payload,
            "records": records,
        }
    )
    input_hash = _canonical_hash(
        {
            "domain": "backtest.performance.input:1.0.0",
            "source_set_hash": source_set_hash,
            "metric_catalog_version": "metrics:1.0.0",
            "calculation_rules_version": "metric-rules:1.0.0",
            "precision_rules_version": "precision:1.0.0",
            "calculated_at": calculated_at,
            "valuation": valuation,
        }
    )
    result_hash = _canonical_hash(
        {
            "domain": "backtest.performance.result:1.0.0",
            "input_hash": input_hash,
            "equity_curve": equity_curve,
            "metrics": metrics,
        }
    )
    return {
        "run_snapshot_id": run_snapshot_id,
        "source_set_hash": source_set_hash,
        "input_hash": input_hash,
        "result_hash": result_hash,
    }


def money(value: Decimal) -> Decimal:
    return value.quantize(MONEY, rounding=ROUND_HALF_EVEN)


def infer_side(entries: Iterable[dict[str, Any]]) -> str:
    security = [row for row in entries if row["account_code"] == "SECURITY"]
    if len(security) != 1:
        raise AssertionError("each fill must post exactly one SECURITY entry")
    return "BUY" if security[0]["direction"] == "DEBIT" else "SELL"


def order_fills_by_cash_chain(
    fills: Sequence[dict[str, Any]],
    ledgers: Mapping[str, Sequence[dict[str, Any]]],
    initial_cash: Decimal,
) -> list[dict[str, Any]]:
    """Rebuild the unique causal fill order with a cash-before index."""
    by_cash_before: dict[Decimal, list[dict[str, Any]]] = defaultdict(list)
    for fill in fills:
        entries = ledgers.get(fill["fill_id"], ())
        if not entries:
            continue
        side = infer_side(entries)
        gross = Decimal(fill["gross_amount"])
        fee = Decimal(fill["fee"])
        after = Decimal(fill["cash_after"])
        before = after + gross + fee if side == "BUY" else after - gross + fee
        by_cash_before[money(before)].append(fill)

    ordered: list[dict[str, Any]] = []
    cash = money(initial_cash)
    while len(ordered) < len(fills):
        matching = by_cash_before.get(cash, [])
        if len(matching) != 1:
            raise AssertionError(
                f"fill cash chain is not uniquely reconstructable: {len(matching)} matches"
            )
        selected = matching.pop()
        if not matching:
            del by_cash_before[cash]
        ordered.append(selected)
        cash = money(Decimal(selected["cash_after"]))
    return ordered


def validate_result_families(
    result_rows: Mapping[str, Sequence[Mapping[str, Any]]],
) -> None:
    """Require every nonempty family while permitting a genuinely empty trade result."""
    allowed = {
        "CALCULATION_SERIES",
        "POSITION_SNAPSHOT",
        "REPLAY_LEDGER",
        "TRADE_DETAIL",
    }
    present = set(result_rows)
    if "CALCULATION_SERIES" not in present or not result_rows["CALCULATION_SERIES"]:
        raise AssertionError("completed result lacks its calculation series")
    if unknown := present - allowed:
        raise AssertionError(
            f"completed result has unknown detail families: {sorted(unknown)}"
        )
    fills = [
        row for row in result_rows.get("TRADE_DETAIL", ()) if row.get("kind") == "FILL"
    ]
    ledger = result_rows.get("REPLAY_LEDGER", ())
    positions = result_rows.get("POSITION_SNAPSHOT", ())
    if fills and (not ledger or not positions):
        raise AssertionError(
            "completed fills require nonempty ledger and position families"
        )
    if not fills and (ledger or positions):
        raise AssertionError(
            "ledger and position families exist without a completed fill"
        )


def expected_fill_values(
    *,
    base_price: Decimal,
    quantity: Decimal,
    side: str,
    slippage_bps: Decimal,
    fee_rate: Decimal,
) -> tuple[Decimal, Decimal, Decimal, Decimal]:
    direction = Decimal(1) if side == "BUY" else Decimal(-1)
    price = money(
        base_price * (Decimal(1) + direction * slippage_bps / Decimal(10_000))
    )
    gross = money(price * quantity)
    slippage = money(abs(price - base_price) * quantity)
    fee = money(gross * fee_rate)
    return price, gross, slippage, fee


def consume_fifo(lots: deque[list[Decimal]], quantity: Decimal) -> Decimal:
    remaining = quantity
    cost = Decimal(0)
    while remaining > 0:
        if not lots:
            raise AssertionError("SELL exceeds independently reconstructed position")
        lot_quantity, lot_cost = lots[0]
        used = min(remaining, lot_quantity)
        used_cost = (
            lot_cost if used == lot_quantity else money(lot_cost * used / lot_quantity)
        )
        cost += used_cost
        remaining -= used
        if used == lot_quantity:
            lots.popleft()
        else:
            lots[0] = [lot_quantity - used, lot_cost - used_cost]
    return money(cost)


def _timestamp(value: datetime) -> str:
    return value.astimezone(UTC).isoformat().replace("+00:00", "Z")


def _decimal_text(value: Decimal) -> str:
    normalized = value.normalize()
    return "0" if normalized == 0 else format(normalized, "f")


def _money_text(value: Decimal) -> str:
    return format(money(value), ".8f")


def _resolution_minutes(resolution: str) -> int:
    return {"30m": 30, "1h": 60, "4h": 240, "1d": 390}[resolution.lower()]


def _compare(left: Decimal, operator: str, right: Decimal) -> bool:
    return {
        "LT": left < right,
        "LTE": left <= right,
        "GT": left > right,
        "GTE": left >= right,
        "EQ": left == right,
        "NEQ": left != right,
    }[operator]


def expected_trigger_order_id(
    *,
    run_snapshot_id: str,
    plan_checksum: str,
    occurred_at: datetime,
    flow_id: str,
    instrument_id: str,
) -> str:
    """Derive the public deterministic order identity without runtime imports."""
    instant = occurred_at.astimezone(UTC).isoformat()
    evaluation_id = uuid.uuid5(
        EVALUATION_ID_NAMESPACE,
        f"{plan_checksum}|{instant}",
    )
    return str(
        uuid.uuid5(
            ORDER_ID_NAMESPACE,
            f"{run_snapshot_id}|{evaluation_id}|{flow_id}|{instrument_id}",
        )
    )


def exact_flow_resolution(
    flow: Mapping[str, Any],
    pinned_pairs: set[tuple[str, str]],
) -> str:
    """Resolve a flow clock from its arguments or its exact scoped data pin."""
    conditions = [
        step for step in flow["steps"] if step["operation"] != "EMIT_ORDER_CANDIDATE"
    ]
    resolutions = {
        str(step["arguments"]["resolution"]).lower()
        for step in conditions
        if "resolution" in step["arguments"]
    }
    if not resolutions:
        instruments = {str(value) for value in flow["officialInstrumentIds"]}
        resolutions = {
            resolution
            for instrument_id, resolution in pinned_pairs
            if instrument_id in instruments
        }
    if len(resolutions) != 1:
        raise AssertionError(
            "trigger flow does not resolve to one exact market clock: "
            f"{flow['key']} {sorted(resolutions)}"
        )
    return resolutions.pop()


def require_exact_manifest_pairs(
    plan_document: Mapping[str, Any],
    pinned_pairs: set[tuple[str, str]],
    *,
    allow_ambiguous_position_only: bool = False,
) -> set[tuple[str, str]]:
    """Require pins for every exact plan clock and reject unrelated pair pins."""
    required: set[tuple[str, str]] = set()
    for partition in plan_document["executionSnapshot"]["partitions"]:
        flows = partition["flows"]
        explicit_by_instrument: dict[str, set[str]] = defaultdict(set)
        flow_resolutions: dict[str, set[str]] = {}
        for flow in flows:
            resolutions = {
                str(step["arguments"]["resolution"]).lower()
                for step in flow["steps"]
                if step["operation"] != "EMIT_ORDER_CANDIDATE"
                and "resolution" in step["arguments"]
            }
            if len(resolutions) > 1:
                raise AssertionError(
                    "one plan flow declares multiple market clocks: "
                    f"{flow['key']} {sorted(resolutions)}"
                )
            flow_resolutions[str(flow["key"])] = resolutions
            for instrument_id in flow["officialInstrumentIds"]:
                explicit_by_instrument[str(instrument_id)].update(resolutions)

        for flow in flows:
            explicit = flow_resolutions[str(flow["key"])]
            for instrument_id_value in flow["officialInstrumentIds"]:
                instrument_id = str(instrument_id_value)
                resolutions = explicit or explicit_by_instrument[instrument_id]
                if len(resolutions) != 1:
                    if allow_ambiguous_position_only and not explicit:
                        continue
                    raise AssertionError(
                        "position-only flow does not resolve from one exact partition clock: "
                        f"{flow['key']} {instrument_id} {sorted(resolutions)}"
                    )
                required.add((instrument_id, next(iter(resolutions))))

    missing = required - pinned_pairs
    unrelated = pinned_pairs - required
    if missing or unrelated:
        raise AssertionError(
            "pinned manifest pairs differ from compiled-plan requirements: "
            f"missing={sorted(missing)} unrelated={sorted(unrelated)}"
        )
    return required


def _trigger_average(values: Sequence[Decimal]) -> Decimal:
    if not values:
        raise AssertionError("trigger average has no values")
    return TRIGGER_MATH.divide(sum(values, Decimal(0)), Decimal(len(values)))


def _trigger_percent(numerator: Decimal, denominator: Decimal) -> Decimal:
    if denominator == 0:
        raise AssertionError("trigger percentage denominator is zero")
    return TRIGGER_MATH.divide(
        TRIGGER_MATH.multiply(numerator, Decimal(100)),
        denominator,
    )


def _trigger_ema(values: Sequence[Decimal], period: int) -> list[Decimal]:
    if not values:
        raise AssertionError("trigger EMA has no values")
    alpha = TRIGGER_MATH.divide(Decimal(2), Decimal(period + 1))
    current = values[0]
    result = [current]
    for value in values[1:]:
        current = TRIGGER_MATH.add(
            TRIGGER_MATH.multiply(value, alpha),
            TRIGGER_MATH.multiply(current, Decimal(1) - alpha),
        )
        result.append(current)
    return result


def _trigger_feature_value(
    values: Sequence[tuple[datetime, Decimal]],
    *,
    boundary: datetime,
    resolution: str,
) -> Decimal:
    span = {
        "30m": timedelta(minutes=30),
        "1h": timedelta(hours=1),
        "4h": timedelta(hours=4),
        "1d": timedelta(days=1),
    }[resolution.lower()]
    earliest = boundary - span
    for starts_at, value in reversed(values):
        if starts_at >= boundary:
            continue
        if starts_at >= earliest:
            return value
        break
    raise TriggerInputMissing(
        f"pinned trigger feature has a gap at {_timestamp(boundary)}"
    )


def _trigger_reference_price(
    reference: str,
    closes: Sequence[Decimal],
    bars: Sequence[MarketBar],
    position_values: Mapping[str, Decimal | int | bool],
) -> Decimal:
    if reference == "PREVIOUS_CLOSE":
        if len(closes) < 2:
            raise TriggerInputMissing("price trigger needs a previous close")
        return closes[-2]
    if reference == "SESSION_OPEN":
        if not bars:
            raise TriggerInputMissing("price trigger needs a current session")
        current_date = bars[-1].session_date_et
        session = [bar for bar in bars if bar.session_date_et == current_date]
        return session[0].open
    if reference == "AVERAGE_ENTRY_PRICE":
        try:
            return Decimal(position_values["averageEntryPrice"])
        except KeyError as exc:
            raise TriggerInputMissing("price trigger needs an open position") from exc
    prefix, separator, raw_period = reference.partition("_")
    if not separator:
        raise AssertionError(f"unsupported price trigger reference {reference}")
    period = int(raw_period)
    required = period + (1 if prefix in {"HIGH", "LOW"} else 0)
    if len(closes) < required:
        raise TriggerInputMissing(f"price trigger {reference} has insufficient history")
    if prefix == "SMA":
        return _trigger_average(closes[-period:])
    prior = closes[-period - 1 : -1]
    if prefix == "HIGH":
        return max(prior)
    if prefix == "LOW":
        return min(prior)
    raise AssertionError(f"unsupported price trigger reference {reference}")


def evaluate_trigger_step(
    step: Mapping[str, Any],
    bars: Sequence[MarketBar],
    *,
    as_of: datetime,
    feature_values: Sequence[tuple[datetime, Decimal]] = (),
    position_values: Mapping[str, Decimal | int | bool] | None = None,
    schedule_values: Mapping[str, Decimal | int | bool] | None = None,
) -> bool:
    """Independently evaluate one persisted plan condition from immutable facts."""
    operation = str(step["operation"])
    arguments = step["arguments"]
    position = position_values or {}
    schedule = schedule_values or {}
    resolution = arguments.get("resolution")
    visible = tuple(
        bar
        for bar in bars
        if bar.ends_at <= as_of
        and (resolution is None or bar.resolution.lower() == str(resolution).lower())
    )[-180:]
    if (
        resolution is not None
        and operation not in {"HOLDING_PERIOD", "SCHEDULE"}
        and (not visible or visible[-1].ends_at != as_of)
    ):
        return False
    closes = tuple(bar.close for bar in visible)
    volumes = tuple(bar.volume for bar in visible)

    if operation in {"PRICE_COMPARE", "PRICE_CHANGE_PERCENT"}:
        if not closes:
            raise TriggerInputMissing(f"{operation} has no close")
        reference_name = str(
            arguments["reference"]
            if operation == "PRICE_COMPARE"
            else arguments["base"]
        )
        reference = _trigger_reference_price(
            reference_name,
            closes,
            visible,
            position,
        )
        if operation == "PRICE_COMPARE":
            return _compare(closes[-1], str(arguments["operator"]), reference)
        change = _trigger_percent(closes[-1] - reference, reference)
        threshold = Decimal(str(arguments["thresholdPercent"]))
        return (
            change >= threshold
            if arguments["direction"] == "UP"
            else change <= -threshold
        )
    if operation == "VOLUME_COMPARE":
        reference_name = str(arguments["reference"])
        period = int(arguments["period"])
        required = 2 if reference_name == "PREVIOUS_VOLUME" else period + 1
        if len(volumes) < required:
            raise TriggerInputMissing("volume trigger has insufficient history")
        reference = (
            volumes[-2]
            if reference_name == "PREVIOUS_VOLUME"
            else _trigger_average(volumes[-period - 1 : -1])
        )
        reference = TRIGGER_MATH.multiply(
            reference, Decimal(str(arguments["multiplier"]))
        )
        return _compare(volumes[-1], str(arguments["operator"]), reference)
    if operation == "STREAK":
        required = int(arguments["bars"])
        if len(closes) < required + 1:
            raise TriggerInputMissing("streak trigger has insufficient history")
        direction = str(arguments["direction"])
        count = 0
        for current, previous in zip(
            reversed(closes[1:]), reversed(closes[:-1]), strict=True
        ):
            if (direction == "UP" and current > previous) or (
                direction == "DOWN" and current < previous
            ):
                count += 1
            else:
                break
        return count >= required
    if operation == "SMA_CROSS":
        short = int(arguments["shortPeriod"])
        long = int(arguments["longPeriod"])
        if len(closes) < long + 1:
            raise TriggerInputMissing("SMA trigger has insufficient history")
        previous_short = _trigger_average(closes[-short - 1 : -1])
        previous_long = _trigger_average(closes[-long - 1 : -1])
        current_short = _trigger_average(closes[-short:])
        current_long = _trigger_average(closes[-long:])
        if arguments["direction"] == "UP":
            return previous_short <= previous_long and current_short > current_long
        return previous_short >= previous_long and current_short < current_long
    if operation == "RSI_CROSS":
        token = str(arguments["resolution"]).lower()
        span = {
            "30m": timedelta(minutes=30),
            "1h": timedelta(hours=1),
            "4h": timedelta(hours=4),
            "1d": timedelta(days=1),
        }[token]
        current = _trigger_feature_value(
            feature_values,
            boundary=as_of,
            resolution=token,
        )
        previous = _trigger_feature_value(
            feature_values,
            boundary=as_of - span,
            resolution=token,
        )
        threshold = Decimal(str(arguments["threshold"]))
        if arguments["direction"] == "UP":
            return previous <= threshold < current
        return previous >= threshold > current
    if operation == "MACD_CROSS":
        fast = int(arguments["fastPeriod"])
        slow = int(arguments["slowPeriod"])
        signal = int(arguments["signalPeriod"])
        if len(closes) < slow + signal + 2:
            raise TriggerInputMissing("MACD trigger has insufficient history")
        fast_values = _trigger_ema(closes, fast)
        slow_values = _trigger_ema(closes, slow)
        macd = [
            left - right for left, right in zip(fast_values, slow_values, strict=True)
        ]
        signal_values = _trigger_ema(macd, signal)
        histogram = [
            left - right for left, right in zip(macd, signal_values, strict=True)
        ]
        previous, current = histogram[-2:]
        if arguments["direction"] == "UP":
            return previous <= 0 < current
        return previous >= 0 > current
    if operation == "BOLLINGER_REVERSAL":
        period = int(arguments["period"])
        deviations = Decimal(str(arguments["deviations"]))
        if len(closes) < period + 1:
            raise TriggerInputMissing("Bollinger trigger has insufficient history")

        def band(offset: int) -> tuple[Decimal, Decimal]:
            end = len(closes) - offset
            window = closes[end - period : end]
            mean = _trigger_average(window)
            variance = TRIGGER_MATH.divide(
                sum(
                    (TRIGGER_MATH.power(value - mean, 2) for value in window),
                    Decimal(0),
                ),
                Decimal(period),
            )
            width = TRIGGER_MATH.multiply(TRIGGER_MATH.sqrt(variance), deviations)
            return mean - width, mean + width

        previous_band, current_band = band(1), band(0)
        previous, current = closes[-2:]
        if arguments["direction"] == "UP":
            return previous <= previous_band[0] and current > current_band[0]
        return previous >= previous_band[1] and current < current_band[1]
    if operation == "POSITION_RETURN":
        value = Decimal(position["returnPercent"])
        threshold = Decimal(str(arguments["thresholdPercent"]))
        return (
            value >= threshold
            if arguments["direction"] == "PROFIT"
            else value <= -threshold
        )
    if operation == "HOLDING_PERIOD":
        unit = str(arguments["unit"])
        amount = int(arguments["amount"])
        if unit == "SESSION_CLOSE":
            return bool(schedule.get("sessionClose", False))
        if unit == "BAR":
            key = f"holdingBars.{arguments['resolution']}"
            return int(position[key]) >= amount
        return int(position["holdingTradingDays"]) >= amount
    if operation in {"PEAK_RETURN", "DRAWDOWN_FROM_PEAK"}:
        key = "peakReturnPercent" if operation == "PEAK_RETURN" else "drawdownPercent"
        return _compare(
            Decimal(position[key]),
            str(arguments["operator"]),
            Decimal(str(arguments["thresholdPercent"])),
        )
    if operation == "SCHEDULE":
        cycle = str(arguments["cycle"])
        interval = int(arguments["interval"])
        new_day = bool(schedule.get("newTradingDay", False))
        day_index = int(schedule.get("tradingDayIndex", 0))
        return {
            "EVERY_TRADING_DAY": new_day,
            "WEEK_FIRST_TRADING_DAY": bool(schedule.get("weekFirstTradingDay", False)),
            "MONTH_FIRST_TRADING_DAY": bool(
                schedule.get("monthFirstTradingDay", False)
            ),
            "MONTH_LAST_TRADING_DAY": bool(schedule.get("monthLastTradingDay", False)),
            "EVERY_N_TRADING_DAYS": new_day
            and interval > 0
            and (day_index - 1) % interval == 0,
        }[cycle]
    raise AssertionError(f"unsupported independent trigger operation {operation}")


def build_trigger_contexts(
    event_bars: Sequence[MarketBar],
    *,
    fill_states: Sequence[
        tuple[
            datetime,
            Decimal,
            dict[str, tuple[Decimal, Decimal]],
            dict[str, datetime],
        ]
    ],
    session_hours: Mapping[date, tuple[datetime, datetime]],
    period_start: datetime,
    period_end: datetime,
) -> tuple[
    dict[tuple[datetime, str], dict[str, Decimal | int | bool]],
    dict[datetime, dict[str, Decimal | int | bool]],
]:
    """Rebuild schedule and post-settlement position inputs at each replay instant."""
    ordered_events = sorted(
        (bar for bar in event_bars if period_start <= bar.ends_at < period_end),
        key=lambda item: (
            item.ends_at,
            _resolution_minutes(item.resolution),
            item.instrument_id,
            item.starts_at,
        ),
    )
    events_at: dict[datetime, list[MarketBar]] = defaultdict(list)
    for bar in ordered_events:
        events_at[bar.ends_at].append(bar)

    if any(current[0] < previous[0] for previous, current in pairwise(fill_states)):
        raise AssertionError("fill states are not chronological")
    schedule_first = period_start.astimezone(ET).date()
    schedule_last = (period_end - timedelta(microseconds=1)).astimezone(ET).date()
    session_dates = sorted(
        day for day in session_hours if schedule_first <= day <= schedule_last
    )
    session_index = {day: index for index, day in enumerate(session_dates)}

    positions: dict[str, tuple[Decimal, Decimal]] = {}
    opened_at: dict[str, datetime] = {}
    state_cursor = 0
    tracked_cycle: dict[str, datetime] = {}
    peak_price: dict[str, Decimal] = {}
    holding_bars: dict[tuple[str, str], int] = {}
    position_contexts: dict[tuple[datetime, str], dict[str, Decimal | int | bool]] = {}
    schedule_contexts: dict[datetime, dict[str, Decimal | int | bool]] = {}
    last_schedule_date: date | None = None

    for instant, current_events in events_at.items():
        while (
            state_cursor < len(fill_states) and fill_states[state_cursor][0] <= instant
        ):
            positions = dict(fill_states[state_cursor][2])
            opened_at = dict(fill_states[state_cursor][3])
            state_cursor += 1

        held = set(positions)
        for instrument_id in set(tracked_cycle) - held:
            tracked_cycle.pop(instrument_id, None)
            peak_price.pop(instrument_id, None)
            holding_bars = {
                key: value
                for key, value in holding_bars.items()
                if key[0] != instrument_id
            }

        current_prices: dict[str, Decimal] = {}
        for bar in current_events:
            current_prices[bar.instrument_id] = bar.close
        for instrument_id in current_prices:
            if instrument_id not in positions:
                continue
            quantity, cost = positions[instrument_id]
            average = money(cost / quantity)
            cycle = opened_at.get(instrument_id)
            if cycle is None:
                raise AssertionError(
                    "open position has no independently reconstructed cycle"
                )
            if tracked_cycle.get(instrument_id) != cycle:
                tracked_cycle[instrument_id] = cycle
                peak_price[instrument_id] = average
                holding_bars = {
                    key: value
                    for key, value in holding_bars.items()
                    if key[0] != instrument_id
                }

        for bar in current_events:
            if bar.instrument_id in positions:
                key = (bar.instrument_id, bar.resolution)
                holding_bars[key] = holding_bars.get(key, 0) + 1

        session_days = {bar.session_date_et for bar in current_events}
        if len(session_days) != 1:
            raise AssertionError(f"replay instant spans multiple sessions: {instant}")
        session_day = session_days.pop()
        day_position = session_index.get(session_day)
        if day_position is None:
            raise AssertionError(f"replay event has no policy session: {session_day}")
        previous_day = session_dates[day_position - 1] if day_position else None
        following_day = (
            session_dates[day_position + 1]
            if day_position + 1 < len(session_dates)
            else None
        )
        new_day = last_schedule_date != session_day
        last_schedule_date = session_day
        schedule_contexts[instant] = {
            "sessionClose": instant >= session_hours[session_day][1],
            "newTradingDay": new_day,
            "tradingDayIndex": day_position + 1,
            "weekFirstTradingDay": new_day
            and (
                previous_day is None
                or previous_day.isocalendar()[:2] != session_day.isocalendar()[:2]
            ),
            "monthFirstTradingDay": new_day
            and (
                previous_day is None
                or (previous_day.year, previous_day.month)
                != (session_day.year, session_day.month)
            ),
            "monthLastTradingDay": new_day
            and (
                following_day is None
                or (following_day.year, following_day.month)
                != (session_day.year, session_day.month)
            ),
        }

        for instrument_id, price in current_prices.items():
            state = positions.get(instrument_id)
            if state is None:
                continue
            quantity, cost = state
            average = money(cost / quantity)
            peak = max(peak_price.get(instrument_id, average), price)
            peak_price[instrument_id] = peak
            opened_day = opened_at[instrument_id].astimezone(ET).date()
            position_contexts[(instant, instrument_id)] = {
                "averageEntryPrice": average,
                "returnPercent": money((price - average) * Decimal(100) / average),
                "peakReturnPercent": money((peak - average) * Decimal(100) / average),
                "drawdownPercent": money((peak - price) * Decimal(100) / peak),
                "holdingTradingDays": max(
                    0,
                    session_index[session_day] - session_index[opened_day],
                ),
                **{
                    f"holdingBars.{resolution}": holding_bars.get(
                        (instrument_id, resolution), 0
                    )
                    for resolution in ("30m", "1h", "4h", "1d")
                },
            }
    return position_contexts, schedule_contexts


def _load_exact_parquet(
    s3: Any, row: Mapping[str, Any]
) -> tuple[list[dict[str, Any]], Mapping[bytes, bytes]]:
    body = exact_object_bytes(
        s3,
        ExactObject(
            bucket=str(row["bucket_name"]),
            key=str(row["object_key"]),
            version_id=str(row["provider_version_id"] or ""),
            content_hash=str(row["content_hash"]),
            byte_size=int(row["byte_size"]),
        ),
    )
    table = pq.read_table(BytesIO(body))
    if table.num_rows != int(row["row_count"]):
        raise AssertionError(f"object row count mismatch: {row['object_key']}")
    return table.to_pylist(), table.schema.metadata or {}


def _candidate_rows(
    connection: Any, as_of_at: datetime
) -> tuple[DatasetCandidate, ...]:
    rows = connection.execute(
        text(
            """select id::text manifest_id, instrument_id::text instrument_id,
                      resolution, revision_number, period_start, period_end, available_at
               from market_data.dataset_manifests
               where status='AVAILABLE' and data_layer='ADJUSTED'
                 and available_at <= :as_of_at
               order by instrument_id,resolution,period_start,id"""
        ),
        {"as_of_at": as_of_at},
    ).mappings()
    return tuple(
        DatasetCandidate(
            manifest_id=row["manifest_id"],
            instrument_id=row["instrument_id"],
            resolution=row["resolution"],
            revision=int(row["revision_number"]),
            period_start=row["period_start"].isoformat(),
            period_end=row["period_end"].isoformat(),
            available_at=_timestamp(row["available_at"]),
        )
        for row in rows
    )


def _metric_values(
    curve: Sequence[dict[str, Any]],
    *,
    fill_count: int,
    closing_count: int,
    winning_count: int,
    losing_count: int,
    realized_pnl: Decimal,
    total_fees: Decimal,
    total_slippage: Decimal,
) -> dict[str, Decimal | None]:
    equities = [Decimal(point["equity"]) for point in curve]
    opening, closing = equities[0], equities[-1]
    with localcontext() as context:
        context.prec = WORKING_PRECISION
        context.rounding = ROUND_HALF_EVEN
        total_return = (
            None
            if opening == 0
            else ((closing - opening) / opening * 100).quantize(MONEY)
        )
        peak = opening
        worst = Decimal(0)
        for equity in equities:
            peak = max(peak, equity)
            if peak <= 0:
                raise AssertionError(
                    "equity curve cannot compute drawdown from a non-positive peak"
                )
            worst = min(worst, (equity - peak) / peak * 100)
        drawdown = worst.quantize(MONEY)
        returns = tuple(
            ((current - previous) / previous).quantize(RETURN_QUANTUM)
            for previous, current in pairwise(equities)
        )
        sharpe: Decimal | None = None
        volatility: Decimal | None = None
        if len(returns) >= 2:
            mean = sum(returns, Decimal(0)) / Decimal(len(returns))
            variance = sum(
                ((value - mean) ** 2 for value in returns), Decimal(0)
            ) / Decimal(len(returns) - 1)
            stdev = variance.sqrt()
            annualizer = Decimal(252).sqrt()
            volatility = (stdev * annualizer * 100).quantize(MONEY)
            if stdev != 0:
                sharpe = (mean / stdev * annualizer).quantize(MONEY)
        win_rate = (
            None
            if closing_count == 0
            else (Decimal(winning_count) / Decimal(closing_count) * 100).quantize(MONEY)
        )
    return {
        "annualizedVolatilityPct": volatility,
        "closingTradeCount": Decimal(closing_count),
        "endingCash": Decimal(curve[-1]["cash"]),
        "endingEquity": closing,
        "fillCount": Decimal(fill_count),
        "losingTradeCount": Decimal(losing_count),
        "maxDrawdownPct": drawdown,
        "realizedPnl": money(realized_pnl),
        "sharpe": sharpe,
        "startingEquity": opening,
        "totalFees": money(total_fees),
        "totalReturnPct": total_return,
        "totalSlippage": money(total_slippage),
        "valuationPointCount": Decimal(len(curve)),
        "winRatePct": win_rate,
        "winningTradeCount": Decimal(winning_count),
    }


def _verify_metrics(
    document: Mapping[str, Any], values: Mapping[str, Decimal | None]
) -> list[list[str | None]]:
    expected_rules = {key: value[0] for key, value in METRIC_RULES.items()}
    if document.get("metricRules") != expected_rules:
        raise AssertionError(
            "stored metric rule index differs from the independent catalog"
        )
    if (
        document.get("metricCatalogVersion") != "metrics:1.0.0"
        or document.get("calculationRulesVersion") != "metric-rules:1.0.0"
        or document.get("valuationBasis") != "MARK_TO_MARKET"
        or document.get("valuationBasisRuleId")
        != "equity.valuation:mark_to_market:1.0.0"
        or document.get("valuationPeriodicity") != "DAILY"
    ):
        raise AssertionError(
            "stored metric qualification differs from the fixed public contract"
        )
    material: list[list[str | None]] = []
    for key in sorted(values):
        value = values[key]
        rule, unit = METRIC_RULES[key]
        if value is None:
            exact = None
            if document.get(key) is not None:
                raise AssertionError(f"metric {key} should be undefined")
        elif unit == "COUNT":
            exact = str(int(value))
            if document.get(key) != int(value):
                raise AssertionError(
                    f"metric mismatch {key}: {document.get(key)} != {exact}"
                )
        elif unit == "MONEY":
            exact = _money_text(value)
            if str(document.get(key)) != exact:
                raise AssertionError(
                    f"metric mismatch {key}: {document.get(key)} != {exact}"
                )
        else:
            exact = format(value, "f")
            if Decimal(str(document.get(key))) != value:
                raise AssertionError(
                    f"metric mismatch {key}: {document.get(key)} != {exact}"
                )
        material.append([key, rule, unit, exact])
    return material


def _record_payload(
    row: Mapping[str, Any],
    positions: Mapping[str, Sequence[Mapping[str, Any]]],
    run_snapshot_id: str,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "run_snapshot_id": run_snapshot_id,
        "record_id": row["record_id"],
        "kind": row["kind"],
        "occurred_at": _timestamp(row["occurred_at"]),
        "order_id": row["order_id"],
        "instrument_id": row["instrument_id"],
        "order_status": row["order_status"],
        "cash_after": _decimal_text(Decimal(row["cash_after"])),
        "positions_after": [
            {
                "instrument_id": item["instrument_id"],
                "quantity": _decimal_text(Decimal(item["quantity"])),
                "cost_basis": _decimal_text(Decimal(item["cost_basis"])),
            }
            for item in sorted(
                positions.get(row["record_id"], ()),
                key=lambda value: value["instrument_id"],
            )
        ],
    }
    if row.get("reason_code") is not None:
        payload["reason_code"] = row["reason_code"]
    if row["kind"] == "FILL":
        for key in (
            "quantity",
            "base_price",
            "price",
            "gross_amount",
            "slippage_amount",
            "fee",
            "cost_basis",
            "realized_pnl",
        ):
            payload[key] = _decimal_text(Decimal(row[key]))
        payload["fill_id"] = row["fill_id"]
    return payload


def reconcile_terminal_inputs(run_id: str) -> dict[str, Any]:
    """Verify exact immutable inputs even when execution terminates unavailable."""
    database_url = os.environ.get(
        "DATABASE_URL", os.environ.get("BACKTEST_DATABASE_URL", "")
    )
    if not database_url:
        raise RuntimeError("DATABASE_URL or BACKTEST_DATABASE_URL is required")
    if database_url.startswith("postgresql://"):
        database_url = database_url.replace("postgresql://", "postgresql+psycopg://", 1)
    s3 = boto3.client(
        "s3",
        endpoint_url=os.environ.get(
            "S3_ENDPOINT_URL", os.environ.get("AWS_ENDPOINT_URL_S3")
        ),
        region_name=os.environ.get(
            "S3_REGION", os.environ.get("AWS_REGION", "us-east-1")
        ),
    )
    engine = create_engine(database_url)
    with engine.connect() as connection:
        run = (
            connection.execute(
                text(
                    """select r.status, r.failure_code, r.missing_requirements,
                              r.evaluation_start, r.evaluation_end,
                              p.input_bundle_fingerprint, p.compiled_plan_checksum,
                              p.strategy_snapshot_hash, p.execution_policy_version,
                              ib.as_of_at, ep.policy_document,
                              lp.plan_checksum launch_plan_checksum, lp.plan_document
                       from backtest.runs r
                       join backtest.run_input_pins p on p.run_id=r.id
                       join backtest.input_bundles ib on ib.id=p.input_bundle_id
                       join backtest.execution_policy_versions ep
                         on ep.version=p.execution_policy_version
                       join bot.launch_contract_plans lp on lp.bot_id=r.bot_id
                       where r.id=:run_id"""
                ),
                {"run_id": run_id},
            )
            .mappings()
            .one()
        )
        if run["status"] not in {"COMPLETED", "UNAVAILABLE"}:
            raise AssertionError(
                f"run has no auditable terminal inputs: {run['status']}"
            )
        allow_ambiguous = run["status"] == "UNAVAILABLE"
        if allow_ambiguous and (
            run["failure_code"] != "REQUIRED_INPUT_UNAVAILABLE"
            or run["missing_requirements"] != ["REQUIRED_INPUT_UNAVAILABLE"]
        ):
            raise AssertionError("unavailable input terminal material is not canonical")
        if str(run["compiled_plan_checksum"]).removeprefix("sha256:") != str(
            run["launch_plan_checksum"]
        ).removeprefix("sha256:"):
            raise AssertionError(
                "launch plan checksum differs from the immutable run pin"
            )
        sources = (
            connection.execute(
                text(
                    """select m.id::text manifest_id,
                              m.instrument_id::text instrument_id,
                              m.resolution, m.revision_number,
                              m.period_start, m.period_end, m.available_at,
                              m.dataset_hash, d.locked_dataset_hash,
                              o.bucket_name, o.object_key, o.provider_version_id,
                              o.content_hash, o.byte_size, o.row_count
                       from backtest.run_input_pins p
                       join backtest.input_datasets d
                         on d.input_bundle_id=p.input_bundle_id
                       join market_data.dataset_manifests m
                         on m.id=d.dataset_manifest_id
                       join market_data.dataset_objects mo
                         on mo.dataset_manifest_id=m.id
                       join storage.objects o on o.id=mo.object_id
                       where p.run_id=:run_id
                       order by m.instrument_id,m.resolution,m.period_start,o.object_key"""
                ),
                {"run_id": run_id},
            )
            .mappings()
            .all()
        )
        candidates = _candidate_rows(connection, run["as_of_at"])

    manifest_ids_by_pair: dict[tuple[str, str], set[str]] = defaultdict(set)
    source_versions: list[list[str]] = []
    source_rows = 0
    for source in sources:
        instrument_id = source["instrument_id"]
        if instrument_id is None:
            raise AssertionError("exact-instrument run pinned a universe-wide manifest")
        if str(source["locked_dataset_hash"]).removeprefix("sha256:") != str(
            source["dataset_hash"]
        ).removeprefix("sha256:"):
            raise AssertionError("locked dataset hash differs from its pinned manifest")
        rows, metadata = _load_exact_parquet(s3, source)
        resolution = str(source["resolution"]).lower()
        if metadata.get(b"resolution", b"").decode() != resolution:
            raise AssertionError(
                "source Parquet resolution metadata differs from its manifest"
            )
        manifest_ids_by_pair[(instrument_id, resolution)].add(source["manifest_id"])
        source_versions.append(
            [
                source["object_key"],
                source["provider_version_id"],
                source["content_hash"],
            ]
        )
        source_rows += len(rows)
        for row in rows:
            if str(row["instrument_id"]) != instrument_id:
                raise AssertionError("source row escaped its exact-instrument manifest")
            prices = [
                Decimal(str(row[key])) for key in ("open", "high", "low", "close")
            ]
            open_price, high, low, close = prices
            if (
                min(prices) <= 0
                or high < max(open_price, low, close)
                or low > min(open_price, high, close)
            ):
                raise AssertionError("source OHLC invariants failed")
            if Decimal(str(row["volume"])) < 0:
                raise AssertionError("source volume is negative")

    required_pairs = require_exact_manifest_pairs(
        run["plan_document"],
        set(manifest_ids_by_pair),
        allow_ambiguous_position_only=allow_ambiguous,
    )
    coverage_start = run["evaluation_start"].isoformat()
    coverage_end = (run["evaluation_end"] + timedelta(days=1)).isoformat()
    selected_manifest_ids: set[str] = set()
    for instrument_id, resolution in sorted(required_pairs):
        actual_ids = manifest_ids_by_pair[(instrument_id, resolution)]
        cover = minimum_manifest_cover(
            candidates,
            instrument_id=instrument_id,
            resolution=resolution,
            coverage_start=coverage_start,
            coverage_end=coverage_end,
        )
        expected_ids = {item.manifest_id for item in cover}
        if actual_ids != expected_ids:
            raise AssertionError(
                f"pinned manifests are not the deterministic minimum cover for {instrument_id}/{resolution}: "
                f"actual={sorted(actual_ids)} expected={sorted(expected_ids)}"
            )
        selected_manifest_ids.update(expected_ids)

    return {
        "status": "VERIFIED_INPUTS",
        "runId": run_id,
        "bundleFingerprint": run["input_bundle_fingerprint"],
        "compiledPlanChecksum": run["compiled_plan_checksum"],
        "strategySnapshotHash": run["strategy_snapshot_hash"],
        "executionPolicyVersion": run["execution_policy_version"],
        "manifestCount": len(selected_manifest_ids),
        "sourceObjectCount": len(sources),
        "sourceRowCount": source_rows,
        "sourceVersionDigest": _canonical_hash(sorted(source_versions)),
        "requiredPairs": [list(pair) for pair in sorted(required_pairs)],
    }


def reconcile(run_id: str) -> dict[str, Any]:
    database_url = os.environ.get(
        "DATABASE_URL", os.environ.get("BACKTEST_DATABASE_URL", "")
    )
    if not database_url:
        raise RuntimeError("DATABASE_URL or BACKTEST_DATABASE_URL is required")
    if database_url.startswith("postgresql://"):
        database_url = database_url.replace("postgresql://", "postgresql+psycopg://", 1)
    s3 = boto3.client(
        "s3",
        endpoint_url=os.environ.get(
            "S3_ENDPOINT_URL", os.environ.get("AWS_ENDPOINT_URL_S3")
        ),
        region_name=os.environ.get(
            "S3_REGION", os.environ.get("AWS_REGION", "us-east-1")
        ),
    )
    engine = create_engine(database_url)
    with engine.connect() as connection:
        run = (
            connection.execute(
                text(
                    """select r.id::text run_id, r.bot_id::text bot_id, r.status,
                          r.initial_cash_amount, r.evaluation_start, r.evaluation_end,
                          r.result_hash run_result_hash, r.completed_at,
                          p.input_bundle_id::text input_bundle_id,
                          p.input_bundle_fingerprint, p.compiled_plan_checksum,
                          p.strategy_snapshot_hash, p.execution_policy_version,
                          ib.as_of_at, ep.policy_document,
                          ps.metric_catalog_version, ps.metrics_document,
                          ps.calculation_rules_version, ps.source_set_hash,
                          ps.input_hash, ps.result_hash summary_result_hash, ps.calculated_at,
                          lp.plan_checksum launch_plan_checksum, lp.plan_document
                   from backtest.runs r
                   join backtest.run_input_pins p on p.run_id=r.id
                   join backtest.input_bundles ib on ib.id=p.input_bundle_id
                   join backtest.execution_policy_versions ep on ep.version=p.execution_policy_version
                   join backtest.performance_summaries ps on ps.run_id=r.id
                   join bot.launch_contract_plans lp on lp.bot_id=r.bot_id
                   where r.id=:run_id"""
                ),
                {"run_id": run_id},
            )
            .mappings()
            .one()
        )
        if run["status"] != "COMPLETED":
            raise AssertionError(f"run is not completed: {run['status']}")
        if str(run["compiled_plan_checksum"]).removeprefix("sha256:") != str(
            run["launch_plan_checksum"]
        ).removeprefix("sha256:"):
            raise AssertionError(
                "launch plan checksum differs from the immutable run pin"
            )
        sources = (
            connection.execute(
                text(
                    """select m.id::text manifest_id, m.instrument_id::text instrument_id,
                          m.resolution, m.revision_number, m.period_start, m.period_end,
                          m.available_at, m.dataset_hash, d.locked_dataset_hash,
                          o.bucket_name, o.object_key, o.provider_version_id,
                          o.content_hash, o.byte_size, o.row_count
                   from backtest.run_input_pins p
                   join backtest.input_datasets d on d.input_bundle_id=p.input_bundle_id
                   join market_data.dataset_manifests m on m.id=d.dataset_manifest_id
                   join market_data.dataset_objects mo on mo.dataset_manifest_id=m.id
                   join storage.objects o on o.id=mo.object_id
                   where p.run_id=:run_id
                   order by m.instrument_id,m.resolution,m.period_start,o.object_key"""
                ),
                {"run_id": run_id},
            )
            .mappings()
            .all()
        )
        details = (
            connection.execute(
                text(
                    """select dm.record_type, dm.row_count manifest_row_count,
                          o.bucket_name, o.object_key, o.provider_version_id,
                          o.content_hash, o.byte_size, o.row_count
                   from backtest.detail_manifests dm
                   join storage.objects o on o.id=dm.object_id
                   where dm.run_id=:run_id
                   order by dm.record_type,dm.period_start,dm.part_number,o.object_key"""
                ),
                {"run_id": run_id},
            )
            .mappings()
            .all()
        )
        feature_objects = (
            connection.execute(
                text(
                    """select fm.id::text materialization_id, fm.result_hash,
                          pin.locked_result_hash, fm.instrument_id::text instrument_id,
                          fd.feature_code, fd.resolution,
                          o.bucket_name,o.object_key,o.provider_version_id,
                          o.content_hash,o.byte_size,o.row_count
                   from backtest.run_input_pins p
                   join backtest.input_feature_materializations pin on pin.input_bundle_id=p.input_bundle_id
                   join market_data.feature_materializations fm on fm.id=pin.feature_materialization_id
                   join market_data.feature_definitions fd on fd.id=fm.feature_definition_id
                   join market_data.dataset_objects mo on mo.dataset_manifest_id=fm.output_dataset_manifest_id
                   join storage.objects o on o.id=mo.object_id
                   where p.run_id=:run_id
                   order by fm.instrument_id,fd.feature_code,fd.resolution,o.object_key"""
                ),
                {"run_id": run_id},
            )
            .mappings()
            .all()
        )
        candidates = _candidate_rows(connection, run["as_of_at"])
        calendar_versions = (
            connection.execute(
                text(
                    """select distinct calendar_version
                   from market_data.trading_sessions
                   where exchange_mic=:exchange_mic
                   order by calendar_version"""
                ),
                {"exchange_mic": run["policy_document"]["sessionCalendar"]},
            )
            .scalars()
            .all()
        )
        if len(calendar_versions) != 1:
            raise AssertionError(
                "execution policy does not resolve to one immutable local calendar version: "
                f"{calendar_versions}"
            )
        calendar_version = str(calendar_versions[0])
        calendar_rows = (
            connection.execute(
                text(
                    """select session_date,opens_at,closes_at,session_type
                   from market_data.trading_sessions
                   where exchange_mic=:exchange_mic and calendar_version=:calendar_version
                     and opens_at is not null and closes_at is not null
                   order by session_date"""
                ),
                {
                    "exchange_mic": run["policy_document"]["sessionCalendar"],
                    "calendar_version": calendar_version,
                },
            )
            .mappings()
            .all()
        )

    session_hours = {
        row["session_date"]: (
            row["opens_at"].astimezone(UTC),
            row["closes_at"].astimezone(UTC),
        )
        for row in calendar_rows
    }
    if len(session_hours) != len(calendar_rows):
        raise AssertionError("immutable local calendar has duplicate session dates")

    manifest_ids_by_pair: dict[tuple[str, str], set[str]] = defaultdict(set)
    market_bars: list[MarketBar] = []
    raw_market_rows: list[tuple[str, str, dict[str, Any]]] = []
    source_rows = 0
    source_versions: list[list[str]] = []
    policy_period_start = datetime.fromisoformat(
        str(run["policy_document"]["periodStart"]).replace("Z", "+00:00")
    )
    policy_period_end = datetime.fromisoformat(
        str(run["policy_document"]["periodEnd"]).replace("Z", "+00:00")
    )
    for source in sources:
        instrument_id = source["instrument_id"]
        if instrument_id is None:
            raise AssertionError("exact-instrument run pinned a universe-wide manifest")
        if str(source["locked_dataset_hash"]).removeprefix("sha256:") != str(
            source["dataset_hash"]
        ).removeprefix("sha256:"):
            raise AssertionError("locked dataset hash differs from its pinned manifest")
        rows, metadata = _load_exact_parquet(s3, source)
        resolution = str(source["resolution"]).lower()
        if metadata.get(b"resolution", b"").decode() != resolution:
            raise AssertionError(
                "source Parquet resolution metadata differs from its manifest"
            )
        manifest_ids_by_pair[(instrument_id, resolution)].add(source["manifest_id"])
        source_versions.append(
            [
                source["object_key"],
                source["provider_version_id"],
                source["content_hash"],
            ]
        )
        source_rows += len(rows)
        for row in rows:
            if str(row["instrument_id"]) != instrument_id:
                raise AssertionError("source row escaped its exact-instrument manifest")
            prices = [
                Decimal(str(row[key])) for key in ("open", "high", "low", "close")
            ]
            open_price, high, low, close = prices
            if (
                min(prices) <= 0
                or high < max(open_price, low, close)
                or low > min(open_price, high, close)
            ):
                raise AssertionError("source OHLC invariants failed")
            if Decimal(str(row["volume"])) < 0:
                raise AssertionError("source volume is negative")
            if row_is_replay_eligible(
                row,
                period_start=policy_period_start,
                period_end=policy_period_end,
            ):
                raw_market_rows.append((instrument_id, resolution, row))

    for instrument_id, resolution, row in raw_market_rows:
        hours = session_hours.get(row["session_date_et"])
        if hours is None:
            raise AssertionError(
                "source row has no matching session in the immutable local calendar: "
                f"{row['session_date_et']}"
            )
        market_bars.append(
            market_bar_from_row(
                instrument_id=instrument_id,
                resolution=resolution,
                row=row,
                session_opens_at=hours[0],
                session_closes_at=hours[1],
            )
        )

    coverage_start = run["evaluation_start"].isoformat()
    coverage_end = (run["evaluation_end"] + timedelta(days=1)).isoformat()
    required_pairs = require_exact_manifest_pairs(
        run["plan_document"], set(manifest_ids_by_pair)
    )
    selected_manifest_ids: set[str] = set()
    for instrument_id, resolution in sorted(required_pairs):
        actual_ids = manifest_ids_by_pair[(instrument_id, resolution)]
        cover = minimum_manifest_cover(
            candidates,
            instrument_id=instrument_id,
            resolution=resolution,
            coverage_start=coverage_start,
            coverage_end=coverage_end,
        )
        expected_ids = {item.manifest_id for item in cover}
        if actual_ids != expected_ids:
            raise AssertionError(
                f"pinned manifests are not the deterministic minimum cover for {instrument_id}/{resolution}: "
                f"actual={sorted(actual_ids)} expected={sorted(expected_ids)}"
            )
        selected_manifest_ids.update(expected_ids)

    feature_rows = 0
    feature_series: dict[tuple[str, str, str], list[tuple[datetime, Decimal]]] = (
        defaultdict(list)
    )
    for feature in feature_objects:
        if str(feature["locked_result_hash"]).removeprefix("sha256:") != str(
            feature["result_hash"]
        ).removeprefix("sha256:"):
            raise AssertionError(
                "feature result hash differs from its immutable input pin"
            )
        rows, _metadata = _load_exact_parquet(s3, feature)
        feature_rows += len(rows)
        key = (
            str(feature["instrument_id"]),
            str(feature["feature_code"]),
            str(feature["resolution"]).lower(),
        )
        for row in rows:
            starts_at = row.get("bar_start_at")
            value = row.get("value")
            if not isinstance(starts_at, datetime) or value is None:
                raise AssertionError("feature object has an invalid value row")
            feature_series[key].append((starts_at.astimezone(UTC), Decimal(str(value))))
    for key, values in feature_series.items():
        values.sort(key=lambda item: item[0])
        if any(current[0] <= previous[0] for previous, current in pairwise(values)):
            raise AssertionError(f"feature series is not strictly chronological: {key}")

    result_rows: dict[str, list[dict[str, Any]]] = defaultdict(list)
    result_versions: list[list[str]] = []
    run_snapshot_metadata: set[str] = set()
    for detail in details:
        if int(detail["manifest_row_count"]) != int(detail["row_count"]):
            raise AssertionError("detail manifest and object row counts differ")
        rows, metadata = _load_exact_parquet(s3, detail)
        record_type = detail["record_type"]
        result_rows[record_type].extend(rows)
        result_versions.append(
            [
                detail["object_key"],
                detail["provider_version_id"],
                detail["content_hash"],
            ]
        )
        if metadata.get(b"backtest_run_id", b"").decode() != run_id:
            raise AssertionError("detail object belongs to a different run")
        run_snapshot_metadata.add(metadata.get(b"run_snapshot_id", b"").decode())
    validate_result_families(result_rows)

    policy = run["policy_document"]
    run_payload = {
        "backtest_run_id": run_id,
        "strategy_version_id": run["bot_id"],
        "input_bundle_fingerprint": str(run["input_bundle_fingerprint"]).removeprefix(
            "sha256:"
        ),
        "calculation_model_version": policy["calculationModelVersion"],
        "cost_model_version": "backtest-cost:1.0.0",
        "execution_model_version": "backtest-execution:1.0.0",
        "initial_cash": _decimal_text(Decimal(str(run["initial_cash_amount"]))),
    }
    run_snapshot_id = _canonical_hash(run_payload)
    if run_snapshot_metadata != {run_snapshot_id}:
        raise AssertionError("detail object run snapshot metadata does not reproduce")

    positions: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in result_rows["POSITION_SNAPSHOT"]:
        positions[row["record_id"]].append(row)
    trades = result_rows["TRADE_DETAIL"]
    if len({row["record_id"] for row in trades}) != len(trades):
        raise AssertionError("trade detail record IDs are not unique")
    rank = {"ORDER": 0, "FILL": 1, "CANCELLATION": 2, "REJECTION": 3}
    trade_payloads = [
        _record_payload(row, positions, run_snapshot_id)
        for row in sorted(
            trades,
            key=lambda item: (
                item["occurred_at"],
                rank[item["kind"]],
                item["record_id"],
            ),
        )
    ]

    ledgers: dict[str, list[dict[str, Any]]] = defaultdict(list)
    transactions: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for entry in result_rows["REPLAY_LEDGER"]:
        ledgers[entry["source_event_id"]].append(entry)
        transactions[entry["transaction_id"]].append(entry)
    for transaction_id, entries in transactions.items():
        debit = sum(
            (Decimal(row["amount"]) for row in entries if row["direction"] == "DEBIT"),
            Decimal(0),
        )
        credit = sum(
            (Decimal(row["amount"]) for row in entries if row["direction"] == "CREDIT"),
            Decimal(0),
        )
        if debit != credit or debit <= 0:
            raise AssertionError(
                f"unbalanced double-entry transaction {transaction_id}: {debit} != {credit}"
            )

    fills = [row for row in trades if row["kind"] == "FILL"]
    orders = {row["order_id"]: row for row in trades if row["kind"] == "ORDER"}
    cash = money(Decimal(str(run["initial_cash_amount"])))
    fee_rate = Decimal(str(policy["feeRate"]))
    slippage_bps = Decimal(str(policy["slippageRateBps"]))
    ordered_fills = order_fills_by_cash_chain(fills, ledgers, cash)

    cash = money(Decimal(str(run["initial_cash_amount"])))
    lots: dict[str, deque[list[Decimal]]] = defaultdict(deque)
    quantities: dict[str, Decimal] = defaultdict(Decimal)
    costs: dict[str, Decimal] = defaultdict(Decimal)
    total_fees = total_slippage = realized_pnl = Decimal(0)
    closing_count = winning_count = losing_count = 0
    fill_states: list[
        tuple[
            datetime,
            Decimal,
            dict[str, tuple[Decimal, Decimal]],
            dict[str, datetime],
        ]
    ] = []
    fill_semantics: list[dict[str, Any]] = []
    fill_bar_index: dict[tuple[str, datetime, Decimal], list[MarketBar]] = defaultdict(
        list
    )
    opened_cycles: dict[str, datetime] = {}
    for bar in market_bars:
        fill_bar_index[(bar.instrument_id, bar.ends_at, money(bar.open))].append(bar)
    for fill in ordered_fills:
        fill_id = fill["fill_id"]
        entries = ledgers.get(fill_id)
        if not entries:
            raise AssertionError(f"fill has no ledger transaction: {fill_id}")
        side = infer_side(entries)
        order = orders.get(fill["order_id"])
        if order is None:
            raise AssertionError(f"fill has no immutable accepted order: {fill_id}")
        base = Decimal(fill["base_price"])
        quantity = Decimal(fill["quantity"])
        raw = exact_fill_bar(
            fill_bar_index.get(
                (fill["instrument_id"], fill["occurred_at"], money(base)),
                (),
            ),
            instrument_id=fill["instrument_id"],
            order_at=order["occurred_at"],
            fill_at=fill["occurred_at"],
            base_price=base,
        )
        expected = expected_fill_values(
            base_price=base,
            quantity=quantity,
            side=side,
            slippage_bps=slippage_bps,
            fee_rate=fee_rate,
        )
        actual = tuple(
            Decimal(fill[field])
            for field in ("price", "gross_amount", "slippage_amount", "fee")
        )
        if actual != expected:
            raise AssertionError(
                f"fill arithmetic mismatch: {fill_id}: {actual} != {expected}"
            )
        _, gross, slippage, fee = expected
        prior_quantity = quantities[fill["instrument_id"]]
        if side == "BUY":
            lots[fill["instrument_id"]].append([quantity, gross])
            quantities[fill["instrument_id"]] += quantity
            costs[fill["instrument_id"]] += gross
            cash = money(cash - gross - fee)
            expected_cost = gross
            expected_realized = money(Decimal(0))
            if prior_quantity <= 0 < quantities[fill["instrument_id"]]:
                opened_cycles[fill["instrument_id"]] = raw.starts_at
        else:
            expected_cost = consume_fifo(lots[fill["instrument_id"]], quantity)
            quantities[fill["instrument_id"]] -= quantity
            costs[fill["instrument_id"]] -= expected_cost
            expected_realized = money(gross - expected_cost)
            cash = money(cash + gross - fee)
            closing_count += 1
            winning_count += expected_realized > 0
            losing_count += expected_realized < 0
            if quantities[fill["instrument_id"]] <= 0:
                opened_cycles.pop(fill["instrument_id"], None)
        if Decimal(fill["cost_basis"]) != expected_cost:
            raise AssertionError(f"FIFO cost mismatch: {fill_id}")
        if Decimal(fill["realized_pnl"]) != expected_realized:
            raise AssertionError(f"realized PnL mismatch: {fill_id}")
        if Decimal(fill["cash_after"]) != cash:
            raise AssertionError(f"cash sequence mismatch: {fill_id}")
        expected_positions = {
            instrument_id: (amount, money(costs[instrument_id]))
            for instrument_id, amount in quantities.items()
            if amount > 0
        }
        actual_positions = {
            item["instrument_id"]: (
                Decimal(item["quantity"]),
                Decimal(item["cost_basis"]),
            )
            for item in positions.get(fill["record_id"], ())
        }
        if actual_positions != expected_positions:
            raise AssertionError(
                f"position snapshot differs from independent FIFO book: {fill_id}"
            )
        fill_states.append(
            (
                fill["occurred_at"],
                cash,
                dict(expected_positions),
                dict(opened_cycles),
            )
        )
        total_fees += fee
        total_slippage += slippage
        realized_pnl += expected_realized
        fill_semantics.append(
            {
                "occurredAt": _timestamp(fill["occurred_at"]),
                "instrumentId": fill["instrument_id"],
                "side": side,
                "resolution": raw.resolution,
                "barStartsAt": _timestamp(raw.starts_at),
                "quantity": _decimal_text(quantity),
                "basePrice": _money_text(base),
                "price": _money_text(expected[0]),
                "gross": _money_text(gross),
                "fee": _money_text(fee),
                "slippage": _money_text(slippage),
                "costBasis": _money_text(expected_cost),
                "realizedPnl": _money_text(expected_realized),
                "cashAfter": _money_text(cash),
            }
        )

    position_trigger_contexts, schedule_trigger_contexts = build_trigger_contexts(
        market_bars,
        fill_states=fill_states,
        session_hours=session_hours,
        period_start=policy_period_start,
        period_end=policy_period_end,
    )
    plan_flows = [
        flow
        for partition in run["plan_document"]["executionSnapshot"]["partitions"]
        for flow in partition["flows"]
    ]
    flows_by_instrument: dict[str, list[Mapping[str, Any]]] = defaultdict(list)
    flow_resolutions: dict[str, str] = {}
    for flow in plan_flows:
        flow_id = str(flow["key"])
        flow_resolutions[flow_id] = exact_flow_resolution(
            flow,
            set(manifest_ids_by_pair),
        )
        for instrument_id in flow["officialInstrumentIds"]:
            flows_by_instrument[str(instrument_id)].append(flow)

    bars_by_pair: dict[tuple[str, str], list[MarketBar]] = defaultdict(list)
    for bar in market_bars:
        bars_by_pair[(bar.instrument_id, bar.resolution)].append(bar)
    bar_end_times: dict[tuple[str, str], list[datetime]] = {}
    for key, values in bars_by_pair.items():
        values.sort(key=lambda item: (item.ends_at, item.starts_at))
        bar_end_times[key] = [item.ends_at for item in values]
    feature_start_times = {
        key: [item[0] for item in values] for key, values in feature_series.items()
    }

    def visible_flow_bars(
        instrument_id: str,
        flow: Mapping[str, Any],
        instant: datetime,
    ) -> tuple[MarketBar, ...]:
        key = (instrument_id, flow_resolutions[str(flow["key"])])
        values = bars_by_pair.get(key, [])
        cursor = bisect_right(bar_end_times.get(key, []), instant)
        return tuple(values[max(0, cursor - 180) : cursor])

    def visible_feature_values(
        instrument_id: str,
        step: Mapping[str, Any],
        instant: datetime,
    ) -> tuple[tuple[datetime, Decimal], ...]:
        if step["operation"] != "RSI_CROSS":
            return ()
        resolution = str(step["arguments"]["resolution"]).lower()
        key = (instrument_id, "RSI_14", resolution)
        values = feature_series.get(key, [])
        starts = feature_start_times.get(key, [])
        if not values:
            raise AssertionError(
                f"RSI trigger has no exact pinned feature series: {key}"
            )
        span = {
            "30m": timedelta(minutes=30),
            "1h": timedelta(hours=1),
            "4h": timedelta(hours=4),
            "1d": timedelta(days=1),
        }[resolution]
        first = bisect_left(starts, instant - span * 2)
        last = bisect_left(starts, instant)
        return tuple(values[first:last])

    candidate_records = sorted(
        (row for row in trades if row["kind"] in {"ORDER", "REJECTION"}),
        key=lambda item: (item["occurred_at"], item["record_id"]),
    )
    if len({row["order_id"] for row in candidate_records}) != len(candidate_records):
        raise AssertionError("persisted candidate order identities are not unique")
    trigger_semantics: list[dict[str, Any]] = []
    triggered_operations: set[str] = set()
    for record in candidate_records:
        instrument_id = str(record["instrument_id"])
        instant = record["occurred_at"]
        matching_flows = [
            flow
            for flow in flows_by_instrument.get(instrument_id, ())
            if expected_trigger_order_id(
                run_snapshot_id=run_snapshot_id,
                plan_checksum=str(run["compiled_plan_checksum"]),
                occurred_at=instant,
                flow_id=str(flow["key"]),
                instrument_id=instrument_id,
            )
            == str(record["order_id"])
        ]
        if len(matching_flows) != 1:
            raise AssertionError(
                "persisted candidate does not bind to exactly one compiled flow: "
                f"{record['order_id']} matches={len(matching_flows)}"
            )
        flow = matching_flows[0]
        bars = visible_flow_bars(instrument_id, flow, instant)
        conditions = [
            step
            for step in flow["steps"]
            if step["operation"] != "EMIT_ORDER_CANDIDATE"
        ]
        verified_steps: list[list[str | int]] = []
        for step in conditions:
            passed = evaluate_trigger_step(
                step,
                bars,
                as_of=instant,
                feature_values=visible_feature_values(instrument_id, step, instant),
                position_values=position_trigger_contexts.get(
                    (instant, instrument_id), {}
                ),
                schedule_values=schedule_trigger_contexts.get(instant, {}),
            )
            if not passed:
                raise AssertionError(
                    "persisted candidate has a false independently recomputed condition: "
                    f"{record['order_id']} {flow['key']} sequence={step['sequence']} "
                    f"operation={step['operation']}"
                )
            triggered_operations.add(str(step["operation"]))
            verified_steps.append([int(step["sequence"]), str(step["operation"])])
        trigger_semantics.append(
            {
                "occurredAt": _timestamp(instant),
                "instrumentId": instrument_id,
                "flowId": str(flow["key"]),
                "recordKind": str(record["kind"]),
                "conditions": verified_steps,
            }
        )

    no_signal_evaluations_checked = 0
    if not candidate_records:
        for flow in plan_flows:
            instrument_ids = [str(value) for value in flow["officialInstrumentIds"]]
            conditions = [
                step
                for step in flow["steps"]
                if step["operation"] != "EMIT_ORDER_CANDIDATE"
            ]
            resolution = flow_resolutions[str(flow["key"])]
            for instrument_id in instrument_ids:
                for bar in bars_by_pair.get((instrument_id, resolution), ()):
                    instant = bar.ends_at
                    if not policy_period_start <= instant < policy_period_end:
                        continue
                    no_signal_evaluations_checked += 1
                    context = position_trigger_contexts.get(
                        (instant, instrument_id), {}
                    )
                    if (
                        any(
                            step["operation"]
                            in {
                                "POSITION_RETURN",
                                "HOLDING_PERIOD",
                                "PEAK_RETURN",
                                "DRAWDOWN_FROM_PEAK",
                            }
                            for step in conditions
                        )
                        and not context
                    ):
                        continue
                    visible = visible_flow_bars(instrument_id, flow, instant)
                    try:
                        passed = all(
                            evaluate_trigger_step(
                                step,
                                visible,
                                as_of=instant,
                                feature_values=visible_feature_values(
                                    instrument_id, step, instant
                                ),
                                position_values=context,
                                schedule_values=schedule_trigger_contexts.get(
                                    instant, {}
                                ),
                            )
                            for step in conditions
                        )
                    except TriggerInputMissing:
                        continue
                    if passed:
                        raise AssertionError(
                            "no-signal result has an independently true compiled flow: "
                            f"{flow['key']} at {_timestamp(instant)}"
                        )
    trigger_semantics = sorted_trigger_semantics(trigger_semantics)

    calculation = sorted(
        result_rows["CALCULATION_SERIES"], key=lambda item: item["occurred_at"]
    )
    if not calculation or any(row["metric_id"] != "equity" for row in calculation):
        raise AssertionError("calculation series is not the complete equity curve")
    if len({row["occurred_at"] for row in calculation}) != len(calculation):
        raise AssertionError("calculation series contains duplicate valuation instants")
    opening_at = calculation[0]["occurred_at"]
    initial_cash = money(Decimal(str(run["initial_cash_amount"])))
    if Decimal(calculation[0]["value"]) != initial_cash:
        raise AssertionError("calculation opening equity differs from initial cash")
    valuation_instants: list[dict[str, Any]] = []
    curve: list[dict[str, Any]] = [
        {
            "as_of": _timestamp(opening_at),
            "cash": _money_text(initial_cash),
            "position_value": _money_text(Decimal(0)),
            "equity": _money_text(initial_cash),
            "holdings": [],
        }
    ]
    event_bars = sorted(
        market_bars,
        key=lambda item: (
            item.ends_at,
            _resolution_minutes(item.resolution),
            item.instrument_id,
            item.starts_at,
        ),
    )
    latest_snapshots = latest_market_bars_by_instant(
        event_bars,
        [row["occurred_at"] for row in calculation[1:]],
    )
    for calculation_row, latest in zip(calculation[1:], latest_snapshots, strict=True):
        instant = calculation_row["occurred_at"]
        applicable_states = [state for state in fill_states if state[0] <= instant]
        state_cash, state_positions = (
            (initial_cash, {})
            if not applicable_states
            else (applicable_states[-1][1], applicable_states[-1][2])
        )
        holdings: list[list[str]] = []
        marks: list[list[str]] = []
        position_value = Decimal(0)
        for instrument_id, (quantity, _cost) in sorted(state_positions.items()):
            bar = latest.get(instrument_id)
            if bar is None:
                raise AssertionError(
                    f"open position has no pinned mark at {instant}: {instrument_id}"
                )
            mark = money(bar.close)
            market_value = money(quantity * mark)
            marks.append([instrument_id, _money_text(mark)])
            holdings.append(
                [
                    instrument_id,
                    _decimal_text(quantity),
                    _money_text(mark),
                    _money_text(market_value),
                ]
            )
            position_value += market_value
        position_value = money(position_value)
        equity = money(state_cash + position_value)
        if Decimal(calculation_row["value"]) != equity:
            raise AssertionError(
                f"calculation equity mismatch at {instant}: {calculation_row['value']} != {equity}"
            )
        valuation_instants.append({"as_of": _timestamp(instant), "marks": marks})
        curve.append(
            {
                "as_of": _timestamp(instant),
                "cash": _money_text(state_cash),
                "position_value": _money_text(position_value),
                "equity": _money_text(equity),
                "holdings": holdings,
            }
        )

    metric_values = _metric_values(
        curve,
        fill_count=len(fills),
        closing_count=closing_count,
        winning_count=winning_count,
        losing_count=losing_count,
        realized_pnl=realized_pnl,
        total_fees=total_fees,
        total_slippage=total_slippage,
    )
    metrics_material = _verify_metrics(run["metrics_document"], metric_values)
    valuation = {
        "basis": "MARK_TO_MARKET",
        "basis_rule_id": "equity.valuation:mark_to_market:1.0.0",
        "periodicity": "DAILY",
        "opening_at": _timestamp(opening_at),
        "instants": valuation_instants,
    }
    equity_curve = {"basis": "MARK_TO_MARKET", "periodicity": "DAILY", "points": curve}
    hashes = result_hash_evidence(
        run_payload=run_payload,
        records=trade_payloads,
        calculated_at=_timestamp(run["calculated_at"]),
        valuation=valuation,
        equity_curve=equity_curve,
        metrics=metrics_material,
    )
    for key, stored in (
        ("source_set_hash", run["source_set_hash"]),
        ("input_hash", run["input_hash"]),
        ("result_hash", run["summary_result_hash"]),
        ("result_hash", run["run_result_hash"]),
    ):
        if hashes[key] != str(stored).removeprefix("sha256:"):
            raise AssertionError(
                f"independent {key} does not reproduce the stored digest"
            )
    if run["calculated_at"] != run["completed_at"]:
        raise AssertionError(
            "performance calculation instant differs from the terminal completion instant"
        )

    plan_operations = sorted(
        {
            step["operation"]
            for partition in run["plan_document"]["executionSnapshot"]["partitions"]
            for flow in partition["flows"]
            for step in flow["steps"]
            if step["operation"] != "EMIT_ORDER_CANDIDATE"
        }
    )
    semantic_result_hash = _canonical_hash(
        {
            "compiledPlanChecksum": run["compiled_plan_checksum"],
            "executionPolicyVersion": run["execution_policy_version"],
            "sourceObjects": sorted(source_versions),
            "featureObjects": sorted(
                [row["object_key"], row["provider_version_id"], row["content_hash"]]
                for row in feature_objects
            ),
            "triggers": trigger_semantics,
            "fills": fill_semantics,
            "equityCurve": equity_curve,
            "metrics": metrics_material,
        }
    )
    return {
        "runId": run_id,
        "status": "VERIFIED",
        "manifestCount": len(selected_manifest_ids),
        "sourceObjectCount": len(sources),
        "sourceRowCount": source_rows,
        "sourceVersionDigest": _canonical_hash(sorted(source_versions)),
        "calendarVersion": calendar_version,
        "calendarSessionCount": len(session_hours),
        "featureMaterializationCount": len(
            {row["materialization_id"] for row in feature_objects}
        ),
        "featureRowCount": feature_rows,
        "resultObjectCount": len(details),
        "resultVersionDigest": _canonical_hash(sorted(result_versions)),
        "triggerCount": len(candidate_records),
        "rejectionCount": sum(row["kind"] == "REJECTION" for row in candidate_records),
        "triggeredOperations": sorted(triggered_operations),
        "triggerSemanticHash": _canonical_hash(trigger_semantics),
        "noSignalEvaluationsChecked": no_signal_evaluations_checked,
        "orderCount": len(orders),
        "cancellationCount": sum(row["kind"] == "CANCELLATION" for row in trades),
        "fillCount": len(fills),
        "ledgerTransactionCount": len(transactions),
        "calculationPointCount": len(calculation),
        "planOperations": plan_operations,
        "bundleFingerprint": run["input_bundle_fingerprint"],
        "compiledPlanChecksum": run["compiled_plan_checksum"],
        "strategySnapshotHash": run["strategy_snapshot_hash"],
        "executionPolicyVersion": run["execution_policy_version"],
        "runSnapshotId": run_snapshot_id,
        "sourceSetHash": hashes["source_set_hash"],
        "inputHash": hashes["input_hash"],
        "resultHash": hashes["result_hash"],
        "semanticResultHash": semantic_result_hash,
        "fillSemanticHash": _canonical_hash(fill_semantics),
        "equityCurveHash": _canonical_hash(equity_curve),
        "metricSemanticHash": _canonical_hash(metrics_material),
        "totalFees": _money_text(total_fees),
        "totalSlippage": _money_text(total_slippage),
        "realizedPnl": _money_text(realized_pnl),
        "endingCash": curve[-1]["cash"],
        "endingEquity": curve[-1]["equity"],
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("run_id")
    args = parser.parse_args()
    print(
        json.dumps(reconcile(args.run_id), ensure_ascii=False, sort_keys=True, indent=2)
    )


if __name__ == "__main__":
    main()
