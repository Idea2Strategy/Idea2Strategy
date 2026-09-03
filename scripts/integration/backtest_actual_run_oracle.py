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
from collections import Counter, defaultdict, deque
from collections.abc import Iterable, Mapping, Sequence
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta
from decimal import (
    ROUND_FLOOR,
    ROUND_HALF_EVEN,
    ROUND_HALF_UP,
    Context,
    Decimal,
    localcontext,
)
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
PARTICIPATION_RATE = Decimal("0.10")
BUYING_POWER_BUFFER_RATE = Decimal("0.0001")
MAX_STRATEGY_NOTIONAL = Decimal(1000000)
MAX_GROSS_EXPOSURE = Decimal(1000000)
MAX_INSTRUMENT_EXPOSURE = Decimal(250000)

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


@dataclass(slots=True)
class _ExpectedOrder:
    semantic_identity: str
    order_id: str
    flow_id: str
    instrument_id: str
    side: str
    order_type: str
    quantity: Decimal
    remaining_quantity: Decimal
    filled_quantity: Decimal
    submitted_at: datetime
    eligible_at: datetime
    expires_at: datetime
    reference_price: Decimal
    max_position_notional: Decimal
    submission_sequence: int
    status: str = "ACCEPTED"
    reason_code: str | None = None
    reserved_cash: Decimal = Decimal(0)
    reserved_notional: Decimal = Decimal(0)
    reserved_quantity: Decimal = Decimal(0)
    fill_sequence: int = 0


@dataclass(slots=True)
class _ExpectedExecutionGate:
    executions: int = 0
    bars_since_execution: int = 0
    last_session_index: int | None = None
    condition_rearmed: bool = True

    def observe(self, condition_outcome: str) -> None:
        if self.executions:
            self.bars_since_execution += 1
        if condition_outcome == "FALSE":
            self.condition_rearmed = True

    def accepts(
        self,
        terminal: Mapping[str, Any],
        *,
        session_index: int | None,
    ) -> bool:
        if self.executions:
            self.bars_since_execution += 1
        arguments = terminal["arguments"]
        execution_mode = str(arguments.get("executionMode", "1회만"))
        wait_mode = str(arguments.get("waitMode", "조건 재충족"))
        wait_interval = int(arguments.get("waitInterval", "1"))
        maximum = (
            1 if execution_mode == "1회만" else int(arguments.get("maxExecutions", "1"))
        )
        if self.executions >= maximum:
            return False
        if self.executions == 0 or execution_mode == "주기마다":
            eligible = True
        elif wait_mode == "조건 재충족":
            eligible = self.condition_rearmed
        elif wait_mode == "N봉 이후":
            eligible = self.bars_since_execution >= wait_interval
        elif wait_mode == "N거래일 이후":
            eligible = (
                self.last_session_index is not None
                and session_index is not None
                and session_index - self.last_session_index >= wait_interval
            )
        else:
            eligible = False
        if not eligible:
            return False
        self.executions += 1
        self.bars_since_execution = 0
        self.last_session_index = session_index
        self.condition_rearmed = False
        return True


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


def expected_market_fill_path(
    market_bars: Sequence[MarketBar],
    *,
    instrument_id: str,
    eligible_at: datetime,
    expires_at: datetime,
    quantity: Decimal,
    participation_rate: Decimal = Decimal("0.10"),
) -> list[dict[str, str]]:
    """Derive the next eligible MARKET-bar allocations without observing fills."""
    remaining = quantity
    expected: list[dict[str, str]] = []
    for bar in sorted(
        (
            item
            for item in market_bars
            if item.instrument_id == instrument_id
            and eligible_at <= item.starts_at < expires_at
        ),
        key=lambda item: (item.starts_at, item.ends_at, item.resolution),
    ):
        capacity = (bar.volume * participation_rate).to_integral_value(
            rounding=ROUND_FLOOR
        )
        allocated = min(remaining, capacity)
        if allocated <= 0:
            continue
        expected.append(
            {
                "barStartsAt": _timestamp(bar.starts_at),
                "occurredAt": _timestamp(bar.ends_at),
                "basePrice": _money_text(bar.open),
                "quantity": _decimal_text(allocated),
            }
        )
        remaining -= allocated
        if remaining <= 0:
            break
    return expected


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


def exact_stage_allowed(
    series_bars: Mapping[tuple[str, str], Sequence[MarketBar]],
    *,
    required_pairs: set[tuple[str, str]],
    session_hours: Mapping[date, tuple[datetime, datetime]],
    session_date: date,
    instant: datetime,
) -> bool:
    """Derive the shared availability gate from exact bar intervals.

    The assessment is strategy-wide: a hole in any required series suppresses
    evaluation, order triggering, and fills for every flow during that half-open
    interval.  Closed-market instants are covered by the pinned calendar and are
    therefore allowed without inventing provider bars.
    """

    opens_at, closes_at = session_hours[session_date]
    if not opens_at <= instant < closes_at:
        return True
    for pair in required_pairs:
        bars = series_bars.get(pair, ())
        cursor = bisect_right(bars, instant, key=lambda bar: bar.starts_at) - 1
        if cursor < 0 or not bars[cursor].starts_at <= instant < bars[cursor].ends_at:
            return False
    return True


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


def require_exact_semantic_set(
    expected: Sequence[Mapping[str, Any]],
    actual: Sequence[Mapping[str, Any]],
    *,
    family: str,
) -> None:
    """Compare canonical multisets so an omission and an extra are both fatal."""
    canonical = lambda value: json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    )
    expected_rows = sorted(canonical(dict(row)) for row in expected)
    actual_rows = sorted(canonical(dict(row)) for row in actual)
    if expected_rows == actual_rows:
        return
    missing = list(expected_rows)
    extra: list[str] = []
    for row in actual_rows:
        try:
            missing.remove(row)
        except ValueError:
            extra.append(row)
    first_difference = ""
    if family == "independently enumerated execution":

        def execution_key(row: Mapping[str, Any]) -> tuple[str, ...]:
            return (
                str(row.get("occurred_at") or row.get("occurredAt") or ""),
                str(row.get("kind") or ""),
                str(row.get("order_id") or row.get("order") or ""),
                str(row.get("fill_id") or ""),
            )

        expected_by_key = {execution_key(row): dict(row) for row in expected}
        actual_by_key = {execution_key(row): dict(row) for row in actual}
        for key in sorted(set(expected_by_key) | set(actual_by_key)):
            if expected_by_key.get(key) != actual_by_key.get(key):
                first_difference = (
                    f" firstKey={key} expected={expected_by_key.get(key)} "
                    f"actual={actual_by_key.get(key)}"
                )
                break
    raise AssertionError(
        f"{family} semantic set differs:{first_difference} "
        f"missing={missing[:3]} extra={extra[:3]}"
    )


def semantic_repetition_hash(material: Mapping[str, Any]) -> str:
    """Hash the complete canonical result evidence used across fresh repetitions."""
    required = {
        "inputs",
        "opportunities",
        "orders",
        "cancellations",
        "fills",
        "ledger",
        "positions",
        "equityCurve",
        "metrics",
        "resultObjects",
    }
    missing = required - set(material)
    if missing:
        raise AssertionError(
            f"semantic repetition material omits families: {sorted(missing)}"
        )
    return _canonical_hash({key: material[key] for key in sorted(required)})


def _canonical_scalar(value: Any) -> Any:
    if isinstance(value, datetime):
        return _timestamp(value)
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, Decimal):
        return _decimal_text(value)
    return value


def canonical_result_object_semantics(
    detail_objects: Sequence[Mapping[str, Any]],
    *,
    trade_record_aliases: Mapping[str, str],
    order_aliases: Mapping[str, str],
    fill_aliases: Mapping[str, str],
    ledger_aliases: Mapping[str, str],
) -> list[dict[str, Any]]:
    """Retain every result partition and version after aliasing only record IDs.

    Physical object/version IDs are independently retained and verified by the
    result-version digest and exact VersionId fetch.  They necessarily differ for
    fresh runs.  The repetition domain therefore represents each physical version
    by the SHA-256 of its complete rows after replacing only run-derived record,
    order, fill, ledger, and point IDs with deterministic semantic identities.
    """

    def require_alias(
        aliases: Mapping[str, str], value: Any, *, family: str
    ) -> str | None:
        if value is None:
            return None
        alias = aliases.get(str(value))
        if alias is None:
            raise AssertionError(f"{family} has no independent semantic alias: {value}")
        return alias

    result: list[dict[str, Any]] = []
    for item in detail_objects:
        detail = item["detail"]
        record_type = str(detail["record_type"])
        canonical_rows: list[dict[str, Any]] = []
        for source in item["rows"]:
            row = {key: _canonical_scalar(value) for key, value in source.items()}
            if record_type == "TRADE_DETAIL":
                row["record_id"] = require_alias(
                    trade_record_aliases,
                    source["record_id"],
                    family="trade record",
                )
                row["order_id"] = require_alias(
                    order_aliases, source["order_id"], family="order record"
                )
                row["fill_id"] = require_alias(
                    fill_aliases, source.get("fill_id"), family="fill record"
                )
            elif record_type == "POSITION_SNAPSHOT":
                row["record_id"] = require_alias(
                    trade_record_aliases,
                    source["record_id"],
                    family="position snapshot record",
                )
            elif record_type == "REPLAY_LEDGER":
                for field in ("transaction_id", "source_event_id", "entry_id"):
                    row[field] = require_alias(
                        ledger_aliases,
                        source[field],
                        family=f"ledger {field}",
                    )
            elif record_type == "CALCULATION_SERIES":
                occurred_at = _timestamp(source["occurred_at"])
                instrument_id = str(source.get("instrument_id") or "PORTFOLIO")
                row["point_id"] = (
                    f"CALCULATION_SERIES|{source['metric_id']}|"
                    f"{instrument_id}|{occurred_at}"
                )
            else:  # validate_result_families should make this unreachable.
                raise AssertionError(f"unknown result object family: {record_type}")
            canonical_rows.append(row)
        canonical_rows = sorted_trigger_semantics(canonical_rows)
        canonical_content_hash = _canonical_hash(canonical_rows)
        if not detail["provider_version_id"]:
            raise AssertionError("result object lacks an exact provider version")
        identity = {
            "recordType": record_type,
            "weekStart": detail["week_start_date"].isoformat(),
            "periodStart": _timestamp(detail["period_start"]),
            "periodEnd": _timestamp(detail["period_end"]),
            "partNumber": int(detail["part_number"]),
        }
        result.append(
            {
                "identity": identity,
                "version": {
                    "schemaVersion": str(detail["schema_version"]),
                    "rowCount": int(detail["row_count"]),
                    "canonicalContentSha256": canonical_content_hash,
                    "exactProviderVersionVerified": True,
                },
            }
        )
    identities = [_canonical_hash(item["identity"]) for item in result]
    if len(identities) != len(set(identities)):
        raise AssertionError("canonical result object identities are not unique")
    return sorted_trigger_semantics(result)


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


def independent_execution_oracle(
    *,
    plan_document: Mapping[str, Any],
    market_bars: Sequence[MarketBar],
    feature_series: Mapping[tuple[str, str, str], Sequence[tuple[datetime, Decimal]]],
    session_hours: Mapping[date, tuple[datetime, datetime]],
    period_start: datetime,
    period_end: datetime,
    run_snapshot_id: str,
    plan_checksum: str,
    initial_cash: Decimal,
    fee_rate: Decimal,
    slippage_bps: Decimal,
) -> dict[str, Any]:
    """Replay immutable inputs without consulting any persisted execution output.

    This is intentionally a small, literal implementation of the published Basic
    MARKET/DAY and whole-share contracts used by the fixed Task 4 corpus. It owns
    the market-time loop, trigger truth/warm-up classification, candidate gate,
    sizing, reservations, next-bar eligibility, shared bar capacity, FIFO book,
    double-entry legs, and position snapshots. Persisted trade/fill timestamps or
    quantities are not parameters and therefore cannot seed its answer.
    """

    ordered_events = sorted(
        (bar for bar in market_bars if period_start <= bar.ends_at < period_end),
        key=lambda item: (
            item.ends_at,
            _resolution_minutes(item.resolution),
            item.instrument_id,
            item.starts_at,
        ),
    )
    events_at: dict[datetime, list[MarketBar]] = defaultdict(list)
    bars_by_pair: dict[tuple[str, str], list[MarketBar]] = defaultdict(list)
    for bar in ordered_events:
        events_at[bar.ends_at].append(bar)
        bars_by_pair[(bar.instrument_id, bar.resolution)].append(bar)
    bar_end_times = {
        key: [bar.ends_at for bar in values] for key, values in bars_by_pair.items()
    }
    feature_start_times = {
        key: [item[0] for item in values] for key, values in feature_series.items()
    }
    pinned_pairs = set(bars_by_pair)

    flow_entries: list[tuple[Mapping[str, Any], int, str]] = []
    flow_resolutions: dict[str, str] = {}
    for partition in plan_document["executionSnapshot"]["partitions"]:
        for flow in partition["flows"]:
            flow_id = str(flow["key"])
            resolution = exact_flow_resolution(flow, pinned_pairs)
            flow_resolutions[flow_id] = resolution
            flow_entries.append((flow, int(partition["budgetCapBps"]), resolution))
    required_pairs = {
        (str(instrument_id), resolution)
        for flow, _budget_cap_bps, resolution in flow_entries
        for instrument_id in flow["officialInstrumentIds"]
    }

    session_dates = sorted(
        day
        for day, (opens_at, closes_at) in session_hours.items()
        if closes_at > period_start and opens_at < period_end
    )
    session_index = {day: index for index, day in enumerate(session_dates)}
    next_session = {
        day: (session_dates[index + 1] if index + 1 < len(session_dates) else None)
        for index, day in enumerate(session_dates)
    }

    cash = money(initial_cash)
    lots: dict[str, deque[list[Decimal]]] = defaultdict(deque)
    quantities: dict[str, Decimal] = defaultdict(Decimal)
    costs: dict[str, Decimal] = defaultdict(Decimal)
    opened_cycles: dict[str, datetime] = {}
    orders: list[_ExpectedOrder] = []
    trade_payloads: list[dict[str, Any]] = []
    trade_semantics: list[dict[str, Any]] = []
    ledger_semantics: list[dict[str, Any]] = []
    canonical_ledger_semantics: list[dict[str, Any]] = []
    position_semantics: list[dict[str, Any]] = []
    cancellation_semantics: list[dict[str, Any]] = []
    fill_semantics: list[dict[str, Any]] = []
    fill_states: list[
        tuple[
            datetime,
            Decimal,
            dict[str, tuple[Decimal, Decimal]],
            dict[str, datetime],
        ]
    ] = []
    opportunities: list[dict[str, Any]] = []
    trigger_semantics: list[dict[str, Any]] = []
    triggered_operations: set[str] = set()
    record_alias_by_key: dict[tuple[str, str, str, str], str] = {}
    order_alias_by_id: dict[str, str] = {}
    fill_alias_by_id: dict[str, str] = {}
    ledger_alias_by_id: dict[str, str] = {}

    gates: dict[tuple[str, str], _ExpectedExecutionGate] = {}
    position_gate_identities: dict[str, datetime | None] = {}
    tracked_cycle: dict[str, datetime] = {}
    peak_price: dict[str, Decimal] = {}
    holding_bars: dict[tuple[str, str], int] = {}
    last_schedule_date: date | None = None

    def positions_after() -> list[dict[str, str]]:
        return [
            {
                "instrument_id": instrument_id,
                "quantity": _decimal_text(quantity),
                "cost_basis": _decimal_text(money(costs[instrument_id])),
            }
            for instrument_id, quantity in sorted(quantities.items())
            if quantity > 0
        ]

    def append_trade(
        order: _ExpectedOrder,
        *,
        kind: str,
        occurred_at: datetime,
        alias: str,
        fill: Mapping[str, Decimal | str] | None = None,
    ) -> None:
        payload: dict[str, Any] = {
            "kind": kind,
            "occurred_at": _timestamp(occurred_at),
            "order_id": order.order_id,
            "instrument_id": order.instrument_id,
            "order_status": order.status,
            "cash_after": _decimal_text(cash),
            "positions_after": positions_after(),
        }
        if order.reason_code is not None:
            payload["reason_code"] = order.reason_code
        fill_id = ""
        if fill is not None:
            fill_id = str(fill["fill_id"])
            fill_alias_by_id[fill_id] = alias
            payload["fill_id"] = fill_id
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
                payload[key] = _decimal_text(Decimal(fill[key]))
        trade_payloads.append(payload)
        semantic_payload = dict(payload)
        semantic_payload["order_id"] = order.semantic_identity
        if fill_id:
            semantic_payload["fill_id"] = alias
        trade_semantics.append(semantic_payload)
        record_alias_by_key[
            (kind, order.order_id, _timestamp(occurred_at), fill_id)
        ] = alias
        position_semantics.append(
            {
                "after": alias,
                "occurredAt": _timestamp(occurred_at),
                "cashAfter": _money_text(cash),
                "holdings": [
                    [
                        item["instrument_id"],
                        item["quantity"],
                        _money_text(Decimal(item["cost_basis"])),
                    ]
                    for item in positions_after()
                ],
            }
        )

    def open_orders() -> list[_ExpectedOrder]:
        return [
            order
            for order in orders
            if order.status in {"ACCEPTED", "PARTIALLY_FILLED"}
        ]

    def buying_power() -> Decimal:
        return money(cash - money(cash * BUYING_POWER_BUFFER_RATE))

    def reserved_cash(excluding: _ExpectedOrder | None = None) -> Decimal:
        return sum(
            (order.reserved_cash for order in open_orders() if order is not excluding),
            Decimal(0),
        )

    def reserved_notional(excluding: _ExpectedOrder | None = None) -> Decimal:
        return sum(
            (
                order.reserved_notional
                for order in open_orders()
                if order is not excluding
            ),
            Decimal(0),
        )

    def instrument_reserved(
        instrument_id: str, excluding: _ExpectedOrder | None = None
    ) -> Decimal:
        return sum(
            (
                order.reserved_notional
                for order in open_orders()
                if order is not excluding
                and order.side == "BUY"
                and order.instrument_id == instrument_id
            ),
            Decimal(0),
        )

    def estimated_commitment(order: _ExpectedOrder) -> tuple[Decimal, Decimal]:
        estimated_price = expected_fill_values(
            base_price=order.reference_price,
            quantity=Decimal(1),
            side="BUY",
            slippage_bps=slippage_bps,
            fee_rate=fee_rate,
        )[0]
        notional = money(estimated_price * order.remaining_quantity)
        fee = money(notional * fee_rate)
        return notional, money(notional + fee)

    def release_reservation(order: _ExpectedOrder) -> None:
        order.reserved_cash = Decimal(0)
        order.reserved_notional = Decimal(0)
        order.reserved_quantity = Decimal(0)

    def refresh_reservation(order: _ExpectedOrder) -> None:
        if order.side == "SELL":
            order.reserved_quantity = order.remaining_quantity
        else:
            order.reserved_notional, order.reserved_cash = estimated_commitment(order)

    def reserve_or_reject(order: _ExpectedOrder) -> None:
        if order.side == "SELL":
            available = quantities[order.instrument_id] - sum(
                (
                    other.reserved_quantity
                    for other in open_orders()
                    if other is not order
                    and other.side == "SELL"
                    and other.instrument_id == order.instrument_id
                ),
                Decimal(0),
            )
            if available < order.remaining_quantity:
                order.status = "REJECTED"
                order.reason_code = "POSITION_UNAVAILABLE"
                return
            order.reserved_quantity = order.remaining_quantity
            return

        estimated_notional, estimated_cash = estimated_commitment(order)
        estimated_price = expected_fill_values(
            base_price=order.reference_price,
            quantity=Decimal(1),
            side="BUY",
            slippage_bps=slippage_bps,
            fee_rate=fee_rate,
        )[0]
        marked = money(quantities[order.instrument_id] * estimated_price)
        if (
            marked + instrument_reserved(order.instrument_id, order)
            >= order.max_position_notional
        ):
            order.status = "REJECTED"
            order.reason_code = "MAX_INSTRUMENT_POSITION_PERCENT"
            return
        if estimated_cash > buying_power() - reserved_cash(order):
            order.status = "REJECTED"
            order.reason_code = "INSUFFICIENT_AVAILABLE_CASH"
            return
        exposure = sum(costs.values(), Decimal(0))
        if exposure + reserved_notional(order) + estimated_cash > MAX_STRATEGY_NOTIONAL:
            order.status = "REJECTED"
            order.reason_code = "STRATEGY_BUDGET_EXCEEDED"
            return
        if (
            exposure + reserved_notional(order) + estimated_notional
            > MAX_GROSS_EXPOSURE
        ):
            order.status = "REJECTED"
            order.reason_code = "GROSS_EXPOSURE_EXCEEDED"
            return
        if (
            costs[order.instrument_id]
            + instrument_reserved(order.instrument_id, order)
            + estimated_notional
            > MAX_INSTRUMENT_EXPOSURE
        ):
            order.status = "REJECTED"
            order.reason_code = "INSTRUMENT_EXPOSURE_EXCEEDED"
            return
        order.reserved_notional = estimated_notional
        order.reserved_cash = estimated_cash

    def append_ledger(
        *,
        order: _ExpectedOrder,
        fill_id: str,
        occurred_at: datetime,
        gross: Decimal,
        fee: Decimal,
        cost_basis: Decimal,
        realized_pnl: Decimal,
        fill_alias: str,
    ) -> None:
        transaction_id = str(
            uuid.uuid5(uuid.NAMESPACE_URL, f"idea2strategy:d23:ledger:{fill_id}")
        )
        transaction_alias = f"{fill_alias}|LEDGER"
        ledger_alias_by_id[transaction_id] = transaction_alias
        ledger_alias_by_id[fill_id] = fill_alias
        if order.side == "BUY":
            legs = [
                ("SECURITY", "DEBIT", gross),
                ("FEE_EXPENSE", "DEBIT", fee),
                ("CASH", "CREDIT", money(gross + fee)),
            ]
        else:
            legs = [
                ("CASH", "DEBIT", money(gross - fee)),
                ("FEE_EXPENSE", "DEBIT", fee),
                ("SECURITY", "CREDIT", cost_basis),
            ]
            if realized_pnl > 0:
                legs.append(("REALIZED_PNL", "CREDIT", realized_pnl))
            elif realized_pnl < 0:
                legs.append(("REALIZED_PNL", "DEBIT", money(-realized_pnl)))
        for index, (account, direction, amount) in enumerate(legs, start=1):
            if amount == 0:
                continue
            ledger_semantics.append(
                {
                    "transactionId": transaction_id,
                    "postedAt": _timestamp(occurred_at),
                    "sourceEventId": fill_id,
                    "entryId": str(
                        uuid.uuid5(
                            uuid.NAMESPACE_URL,
                            f"idea2strategy:d23:entry:{fill_id}:{index}",
                        )
                    ),
                    "accountCode": account,
                    "direction": direction,
                    "amount": _money_text(amount),
                    "currency": "USD",
                }
            )
            entry_id = str(
                uuid.uuid5(
                    uuid.NAMESPACE_URL,
                    f"idea2strategy:d23:entry:{fill_id}:{index}",
                )
            )
            entry_alias = f"{transaction_alias}|LEG|{index}"
            ledger_alias_by_id[entry_id] = entry_alias
            canonical_ledger_semantics.append(
                {
                    "transactionId": transaction_alias,
                    "postedAt": _timestamp(occurred_at),
                    "sourceEventId": fill_alias,
                    "entryId": entry_alias,
                    "accountCode": account,
                    "direction": direction,
                    "amount": _money_text(amount),
                    "currency": "USD",
                }
            )

    def expire_orders(at: datetime) -> None:
        for order in sorted(
            open_orders(),
            key=lambda item: (
                item.submitted_at,
                item.submission_sequence,
                item.order_id,
            ),
        ):
            if at < order.expires_at:
                continue
            order.status = "EXPIRED"
            order.reason_code = "DAY_EXPIRED"
            release_reservation(order)
            alias = f"{order.semantic_identity}|CANCELLATION|{_timestamp(at)}"
            append_trade(
                order,
                kind="CANCELLATION",
                occurred_at=at,
                alias=alias,
            )
            cancellation_semantics.append(
                {
                    "identity": order.semantic_identity,
                    "occurredAt": _timestamp(at),
                    "status": order.status,
                    "reasonCode": order.reason_code,
                    "filledQuantity": _decimal_text(order.filled_quantity),
                    "remainingQuantity": _decimal_text(order.remaining_quantity),
                }
            )

    def process_bar(bar: MarketBar) -> None:
        nonlocal cash
        expire_orders(bar.starts_at)
        capacity = (bar.volume * PARTICIPATION_RATE).to_integral_value(
            rounding=ROUND_FLOOR
        )
        if capacity <= 0:
            return
        before_quantity = quantities[bar.instrument_id]
        eligible = sorted(
            (
                order
                for order in open_orders()
                if order.instrument_id == bar.instrument_id
                and order.eligible_at <= bar.starts_at
            ),
            key=lambda item: (
                item.submitted_at,
                item.submission_sequence,
                item.order_id,
            ),
        )
        for order in eligible:
            if capacity <= 0:
                break
            base = money(bar.open)
            price, _one_gross, _one_slippage, _one_fee = expected_fill_values(
                base_price=base,
                quantity=Decimal(1),
                side=order.side,
                slippage_bps=slippage_bps,
                fee_rate=fee_rate,
            )
            caps = [capacity, order.remaining_quantity]
            if order.side == "SELL":
                caps.append(quantities[order.instrument_id])
            else:
                unit_cash = money(price + money(price * fee_rate))
                exposure = sum(costs.values(), Decimal(0))
                caps.extend(
                    [
                        max(buying_power() - reserved_cash(order), Decimal(0))
                        / unit_cash,
                        max(
                            MAX_STRATEGY_NOTIONAL - exposure - reserved_cash(order),
                            Decimal(0),
                        )
                        / unit_cash,
                        max(
                            MAX_GROSS_EXPOSURE - exposure - reserved_notional(order),
                            Decimal(0),
                        )
                        / price,
                        max(
                            order.max_position_notional
                            - money(quantities[order.instrument_id] * price)
                            - instrument_reserved(order.instrument_id, order),
                            Decimal(0),
                        )
                        / price,
                        max(
                            MAX_INSTRUMENT_EXPOSURE
                            - costs[order.instrument_id]
                            - instrument_reserved(order.instrument_id, order),
                            Decimal(0),
                        )
                        / price,
                    ]
                )
            fill_quantity = min(caps).to_integral_value(rounding=ROUND_FLOOR)
            if fill_quantity <= 0:
                continue
            capacity -= fill_quantity
            price, gross, slippage, fee = expected_fill_values(
                base_price=base,
                quantity=fill_quantity,
                side=order.side,
                slippage_bps=slippage_bps,
                fee_rate=fee_rate,
            )
            if order.side == "BUY":
                lots[order.instrument_id].append([fill_quantity, gross])
                quantities[order.instrument_id] += fill_quantity
                costs[order.instrument_id] += gross
                cash = money(cash - gross - fee)
                cost_basis = gross
                realized_pnl = money(Decimal(0))
                if before_quantity <= 0 < quantities[order.instrument_id]:
                    opened_cycles[order.instrument_id] = bar.starts_at
            else:
                cost_basis = consume_fifo(lots[order.instrument_id], fill_quantity)
                quantities[order.instrument_id] -= fill_quantity
                costs[order.instrument_id] -= cost_basis
                realized_pnl = money(gross - cost_basis)
                cash = money(cash + gross - fee)
                if quantities[order.instrument_id] <= 0:
                    opened_cycles.pop(order.instrument_id, None)
            order.fill_sequence += 1
            fill_id = str(
                uuid.uuid5(
                    uuid.NAMESPACE_URL,
                    f"idea2strategy:d23:{order.order_id}:{order.fill_sequence}",
                )
            )
            order.filled_quantity += fill_quantity
            order.remaining_quantity -= fill_quantity
            if order.remaining_quantity == 0:
                order.status = "FILLED"
                release_reservation(order)
            else:
                order.status = "PARTIALLY_FILLED"
                refresh_reservation(order)
            fill_values: dict[str, Decimal | str] = {
                "fill_id": fill_id,
                "quantity": fill_quantity,
                "base_price": base,
                "price": price,
                "gross_amount": gross,
                "slippage_amount": slippage,
                "fee": fee,
                "cost_basis": cost_basis,
                "realized_pnl": realized_pnl,
            }
            alias = f"{order.semantic_identity}|FILL|{order.fill_sequence}"
            append_trade(
                order,
                kind="FILL",
                occurred_at=bar.ends_at,
                alias=alias,
                fill=fill_values,
            )
            append_ledger(
                order=order,
                fill_id=fill_id,
                occurred_at=bar.ends_at,
                gross=gross,
                fee=fee,
                cost_basis=cost_basis,
                realized_pnl=realized_pnl,
                fill_alias=alias,
            )
            expected_positions = {
                instrument_id: (amount, money(costs[instrument_id]))
                for instrument_id, amount in quantities.items()
                if amount > 0
            }
            fill_states.append(
                (
                    bar.ends_at,
                    cash,
                    expected_positions,
                    dict(opened_cycles),
                )
            )
            fill_semantics.append(
                {
                    "occurredAt": _timestamp(bar.ends_at),
                    "instrumentId": order.instrument_id,
                    "side": order.side,
                    "resolution": bar.resolution,
                    "barStartsAt": _timestamp(bar.starts_at),
                    "quantity": _decimal_text(fill_quantity),
                    "basePrice": _money_text(base),
                    "price": _money_text(price),
                    "gross": _money_text(gross),
                    "fee": _money_text(fee),
                    "slippage": _money_text(slippage),
                    "costBasis": _money_text(cost_basis),
                    "realizedPnl": _money_text(realized_pnl),
                    "cashAfter": _money_text(cash),
                }
            )

    def visible_bars(
        instrument_id: str, resolution: str, instant: datetime
    ) -> tuple[MarketBar, ...]:
        key = (instrument_id, resolution)
        values = bars_by_pair.get(key, [])
        cursor = bisect_right(bar_end_times.get(key, []), instant)
        return tuple(values[max(0, cursor - 180) : cursor])

    def visible_features(
        instrument_id: str, step: Mapping[str, Any], instant: datetime
    ) -> tuple[tuple[datetime, Decimal], ...]:
        if step["operation"] != "RSI_CROSS":
            return ()
        resolution = str(step["arguments"]["resolution"]).lower()
        key = (instrument_id, "RSI_14", resolution)
        values = feature_series.get(key, ())
        starts = feature_start_times.get(key, [])
        if not values:
            raise TriggerInputMissing(
                f"RSI trigger has no pinned feature series: {key}"
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

    position_operations = {
        "POSITION_RETURN",
        "HOLDING_PERIOD",
        "PEAK_RETURN",
        "DRAWDOWN_FROM_PEAK",
    }

    for instant, current_events in events_at.items():
        session_days = {bar.session_date_et for bar in current_events}
        if len(session_days) != 1:
            raise AssertionError(f"execution instant spans sessions: {instant}")
        session_day = session_days.pop()
        _opens_at, closes_at = session_hours[session_day]
        for bar in current_events:
            fill_probe = instant if instant < closes_at else bar.starts_at
            if exact_stage_allowed(
                bars_by_pair,
                required_pairs=required_pairs,
                session_hours=session_hours,
                session_date=session_day,
                instant=fill_probe,
            ):
                process_bar(bar)

        held = {
            instrument_id
            for instrument_id, quantity in quantities.items()
            if quantity > 0
        }
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
            if instrument_id not in held:
                continue
            quantity = quantities[instrument_id]
            average = money(costs[instrument_id] / quantity)
            cycle = opened_cycles[instrument_id]
            if tracked_cycle.get(instrument_id) != cycle:
                tracked_cycle[instrument_id] = cycle
                peak_price[instrument_id] = average
                holding_bars = {
                    key: value
                    for key, value in holding_bars.items()
                    if key[0] != instrument_id
                }
        for bar in current_events:
            if bar.instrument_id in held:
                key = (bar.instrument_id, bar.resolution)
                holding_bars[key] = holding_bars.get(key, 0) + 1

        day_position = session_index[session_day]
        previous_day = session_dates[day_position - 1] if day_position else None
        following_day = (
            session_dates[day_position + 1]
            if day_position + 1 < len(session_dates)
            else None
        )
        new_day = last_schedule_date != session_day
        schedule_values: dict[str, Decimal | int | bool] = {
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
        position_values: dict[str, dict[str, Decimal | int | bool]] = {}
        for instrument_id, price in current_prices.items():
            if instrument_id not in held:
                continue
            quantity = quantities[instrument_id]
            average = money(costs[instrument_id] / quantity)
            peak = max(peak_price.get(instrument_id, average), price)
            peak_price[instrument_id] = peak
            opened_day = opened_cycles[instrument_id].astimezone(ET).date()
            position_values[instrument_id] = {
                "averageEntryPrice": average,
                "returnPercent": money((price - average) * Decimal(100) / average),
                "peakReturnPercent": money((peak - average) * Decimal(100) / average),
                "drawdownPercent": money((peak - price) * Decimal(100) / peak),
                "holdingTradingDays": max(
                    0, session_index[session_day] - session_index[opened_day]
                ),
                **{
                    f"holdingBars.{resolution}": holding_bars.get(
                        (instrument_id, resolution), 0
                    )
                    for resolution in ("30m", "1h", "4h", "1d")
                },
            }

        if not exact_stage_allowed(
            bars_by_pair,
            required_pairs=required_pairs,
            session_hours=session_hours,
            session_date=session_day,
            instant=instant,
        ):
            for flow, _budget_cap_bps, _resolution in flow_entries:
                for instrument_id in sorted(
                    (str(value) for value in flow["officialInstrumentIds"]),
                    key=uuid.UUID,
                ):
                    opportunities.append(
                        {
                            "occurredAt": _timestamp(instant),
                            "instrumentId": instrument_id,
                            "flowId": str(flow["key"]),
                            "conditionOutcome": "SKIPPED_DATA_GAP",
                            "candidateOutcome": "NONE",
                            "firstFailureOperation": None,
                        }
                    )
            continue
        last_schedule_date = session_day

        observed_identities = {
            instrument_id: opened_cycles[instrument_id]
            for instrument_id in position_values
        }
        for instrument_id in set(position_gate_identities) | set(observed_identities):
            current_identity = observed_identities.get(instrument_id)
            if position_gate_identities.get(instrument_id) == current_identity:
                continue
            position_gate_identities[instrument_id] = current_identity
            gates = {
                key: value for key, value in gates.items() if key[1] != instrument_id
            }

        evaluated: list[
            tuple[
                Mapping[str, Any],
                int,
                str,
                str,
                str,
                list[list[str | int]],
                dict[str, Any],
            ]
        ] = []
        for flow, budget_cap_bps, resolution in flow_entries:
            conditions = [
                step
                for step in flow["steps"]
                if step["operation"] != "EMIT_ORDER_CANDIDATE"
            ]
            terminal = next(
                step
                for step in flow["steps"]
                if step["operation"] == "EMIT_ORDER_CANDIDATE"
            )
            for instrument_id in sorted(
                (str(value) for value in flow["officialInstrumentIds"]),
                key=uuid.UUID,
            ):
                visible = visible_bars(instrument_id, resolution, instant)
                verified: list[list[str | int]] = []
                condition_outcome = "TRUE"
                failure: str | None = None
                for step in conditions:
                    if (
                        step["operation"] in position_operations
                        and instrument_id not in position_values
                    ):
                        condition_outcome = "INPUT_MISSING"
                        failure = str(step["operation"])
                        break
                    try:
                        passed = evaluate_trigger_step(
                            step,
                            visible,
                            as_of=instant,
                            feature_values=visible_features(
                                instrument_id, step, instant
                            ),
                            position_values=position_values.get(instrument_id, {}),
                            schedule_values=schedule_values,
                        )
                    except TriggerInputMissing:
                        condition_outcome = "WARMUP"
                        failure = str(step["operation"])
                        break
                    if not passed:
                        condition_outcome = "FALSE"
                        failure = str(step["operation"])
                        break
                    verified.append([int(step["sequence"]), str(step["operation"])])
                opportunity = {
                    "occurredAt": _timestamp(instant),
                    "instrumentId": instrument_id,
                    "flowId": str(flow["key"]),
                    "conditionOutcome": condition_outcome,
                    "candidateOutcome": "NONE",
                    "firstFailureOperation": failure,
                }
                opportunities.append(opportunity)
                evaluated.append(
                    (
                        flow,
                        budget_cap_bps,
                        resolution,
                        instrument_id,
                        condition_outcome,
                        verified,
                        opportunity,
                    )
                )

        candidate_day = session_day
        eligible_at = instant
        if instant >= session_hours[session_day][1]:
            candidate_day = next_session[session_day]
            if candidate_day is not None:
                eligible_at = session_hours[candidate_day][0]
        if candidate_day is None:
            for (
                _flow,
                _cap,
                _resolution,
                _instrument,
                outcome,
                _steps,
                item,
            ) in evaluated:
                if outcome == "TRUE":
                    item["candidateOutcome"] = "NO_NEXT_SESSION"
            continue

        survivor_counts: dict[str, int] = Counter(
            str(flow["key"])
            for flow, _cap, _resolution, _instrument, outcome, _steps, _item in evaluated
            if outcome == "TRUE"
        )
        for (
            flow,
            budget_cap_bps,
            resolution,
            instrument_id,
            outcome,
            verified,
            item,
        ) in evaluated:
            gate_key = (str(flow["key"]), instrument_id)
            gate = gates.setdefault(gate_key, _ExpectedExecutionGate())
            if outcome != "TRUE":
                gate.observe(outcome)
                continue
            terminal = next(
                step
                for step in flow["steps"]
                if step["operation"] == "EMIT_ORDER_CANDIDATE"
            )
            if not gate.accepts(
                terminal, session_index=session_index.get(candidate_day)
            ):
                item["candidateOutcome"] = "GATED"
                continue
            visible = visible_bars(instrument_id, resolution, instant)
            if not visible:
                item["conditionOutcome"] = "WARMUP"
                item["candidateOutcome"] = "NONE"
                item["firstFailureOperation"] = "REFERENCE_PRICE"
                continue
            reference_price = money(visible[-1].close)
            arguments = terminal["arguments"]
            side = str(arguments["side"])
            if side == "SELL":
                raw_quantity = (
                    quantities[instrument_id]
                    * Decimal(str(arguments.get("orderPercent", "100")))
                    / Decimal(100)
                )
            else:
                budget = money(
                    buying_power() * Decimal(budget_cap_bps) / Decimal(10_000)
                )
                denominator = survivor_counts[str(flow["key"])]
                share = money(
                    budget
                    / Decimal(denominator)
                    * Decimal(str(arguments.get("orderPercent", "100")))
                    / Decimal(100)
                )
                unit_price = expected_fill_values(
                    base_price=reference_price,
                    quantity=Decimal(1),
                    side="BUY",
                    slippage_bps=slippage_bps,
                    fee_rate=fee_rate,
                )[0]
                unit_cash = money(unit_price + money(unit_price * fee_rate))
                raw_quantity = share / unit_cash
            quantity = raw_quantity.to_integral_value(rounding=ROUND_FLOOR)
            if quantity <= 0:
                item["candidateOutcome"] = "DECLINED_ZERO_SIZE"
                continue
            order_id = expected_trigger_order_id(
                run_snapshot_id=run_snapshot_id,
                plan_checksum=plan_checksum,
                occurred_at=instant,
                flow_id=str(flow["key"]),
                instrument_id=instrument_id,
            )
            identity = f"{flow['key']}|{instrument_id}|{_timestamp(instant)}"
            order = _ExpectedOrder(
                semantic_identity=identity,
                order_id=order_id,
                flow_id=str(flow["key"]),
                instrument_id=instrument_id,
                side=side,
                order_type=str(arguments["orderType"]),
                quantity=quantity,
                remaining_quantity=quantity,
                filled_quantity=Decimal(0),
                submitted_at=instant,
                eligible_at=eligible_at,
                expires_at=session_hours[candidate_day][1],
                reference_price=reference_price,
                max_position_notional=money(
                    initial_cash
                    * Decimal(str(arguments.get("maxPositionPercent", "100")))
                    / Decimal(100)
                ),
                submission_sequence=len(orders) + 1,
            )
            orders.append(order)
            order_alias_by_id[order_id] = identity
            reserve_or_reject(order)
            kind = "ORDER" if order.status == "ACCEPTED" else "REJECTION"
            item["candidateOutcome"] = kind
            alias = f"{identity}|{kind}|{_timestamp(instant)}"
            append_trade(order, kind=kind, occurred_at=instant, alias=alias)
            triggered_operations.update(
                str(step["operation"])
                for step in flow["steps"]
                if step["operation"] != "EMIT_ORDER_CANDIDATE"
            )
            trigger_semantics.append(
                {
                    "occurredAt": _timestamp(instant),
                    "instrumentId": instrument_id,
                    "flowId": str(flow["key"]),
                    "recordKind": kind,
                    "conditions": verified,
                }
            )

    order_semantics = [
        {
            "identity": order.semantic_identity,
            "flowId": order.flow_id,
            "instrumentId": order.instrument_id,
            "side": order.side,
            "orderType": order.order_type,
            "quantityMode": "WHOLE_SHARES",
            "quantity": _decimal_text(order.quantity),
            "filledQuantity": _decimal_text(order.filled_quantity),
            "remainingQuantity": _decimal_text(order.remaining_quantity),
            "submittedAt": _timestamp(order.submitted_at),
            "eligibleAt": _timestamp(order.eligible_at),
            "expiresAt": _timestamp(order.expires_at),
            "referencePrice": _money_text(order.reference_price),
            "maxPositionNotional": _money_text(order.max_position_notional),
            "submissionSequence": order.submission_sequence,
            "timeInForce": "DAY",
            "status": order.status,
            "reasonCode": order.reason_code,
        }
        for order in orders
    ]
    opportunity_counts = Counter(
        f"{item['conditionOutcome']}:{item['candidateOutcome']}"
        for item in opportunities
    )
    return {
        "opportunities": sorted_trigger_semantics(opportunities),
        "opportunityCounts": dict(sorted(opportunity_counts.items())),
        "tradePayloads": trade_payloads,
        "tradeSemantics": trade_semantics,
        "ledger": sorted_trigger_semantics(ledger_semantics),
        "ledgerSemantics": sorted_trigger_semantics(canonical_ledger_semantics),
        "positions": position_semantics,
        "orders": order_semantics,
        "cancellations": sorted_trigger_semantics(cancellation_semantics),
        "fillSemantics": fill_semantics,
        "fillStates": fill_states,
        "triggerSemantics": sorted_trigger_semantics(trigger_semantics),
        "triggeredOperations": sorted(triggered_operations),
        "recordAliases": record_alias_by_key,
        "orderAliases": order_alias_by_id,
        "fillAliases": fill_alias_by_id,
        "ledgerAliases": ledger_alias_by_id,
    }


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
                    """select dm.id::text detail_manifest_id, dm.object_id::text object_id,
                          dm.record_type, dm.week_start_date, dm.period_start,
                          dm.period_end, dm.part_number, dm.schema_version,
                          dm.source_set_hash detail_source_set_hash, dm.detail_hash,
                          dm.row_count manifest_row_count,
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
    detail_objects: list[dict[str, Any]] = []
    run_snapshot_metadata: set[str] = set()
    for detail in details:
        if int(detail["manifest_row_count"]) != int(detail["row_count"]):
            raise AssertionError("detail manifest and object row counts differ")
        rows, metadata = _load_exact_parquet(s3, detail)
        record_type = detail["record_type"]
        result_rows[record_type].extend(rows)
        detail_objects.append({"detail": detail, "rows": rows})
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

    independent = independent_execution_oracle(
        plan_document=run["plan_document"],
        market_bars=market_bars,
        feature_series=feature_series,
        session_hours=session_hours,
        period_start=policy_period_start,
        period_end=policy_period_end,
        run_snapshot_id=run_snapshot_id,
        plan_checksum=str(run["compiled_plan_checksum"]),
        initial_cash=Decimal(str(run["initial_cash_amount"])),
        fee_rate=Decimal(str(policy["feeRate"])),
        slippage_bps=Decimal(str(policy["slippageRateBps"])),
    )
    actual_execution_payloads = [
        {
            key: value
            for key, value in payload.items()
            if key not in {"run_snapshot_id", "record_id"}
        }
        for payload in trade_payloads
    ]
    require_exact_semantic_set(
        independent["tradePayloads"],
        actual_execution_payloads,
        family="independently enumerated execution",
    )
    actual_ledger_semantics = [
        {
            "transactionId": str(row["transaction_id"]),
            "postedAt": _timestamp(row["posted_at"]),
            "sourceEventId": str(row["source_event_id"]),
            "entryId": str(row["entry_id"]),
            "accountCode": str(row["account_code"]),
            "direction": str(row["direction"]),
            "amount": _money_text(Decimal(row["amount"])),
            "currency": str(row["currency"]),
        }
        for row in result_rows["REPLAY_LEDGER"]
    ]
    require_exact_semantic_set(
        independent["ledger"],
        actual_ledger_semantics,
        family="independently derived ledger legs",
    )
    actual_position_semantics: list[dict[str, Any]] = []
    trade_record_aliases: dict[str, str] = {}
    for trade in trades:
        alias_key = (
            str(trade["kind"]),
            str(trade["order_id"]),
            _timestamp(trade["occurred_at"]),
            str(trade["fill_id"] or ""),
        )
        alias = independent["recordAliases"].get(alias_key)
        if alias is None:
            raise AssertionError(
                "persisted position record has no independently derived execution alias: "
                f"{alias_key}"
            )
        trade_record_aliases[str(trade["record_id"])] = alias
        actual_position_semantics.append(
            {
                "after": alias,
                "occurredAt": _timestamp(trade["occurred_at"]),
                "cashAfter": _money_text(Decimal(trade["cash_after"])),
                "holdings": [
                    [
                        str(item["instrument_id"]),
                        _decimal_text(Decimal(item["quantity"])),
                        _money_text(Decimal(item["cost_basis"])),
                    ]
                    for item in sorted(
                        positions.get(trade["record_id"], ()),
                        key=lambda value: value["instrument_id"],
                    )
                ],
            }
        )
    require_exact_semantic_set(
        independent["positions"],
        actual_position_semantics,
        family="independently derived position snapshots",
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

    require_exact_semantic_set(
        independent["fillSemantics"],
        fill_semantics,
        family="independently derived fill path and allocation",
    )
    fill_semantics = list(independent["fillSemantics"])
    fill_states = list(independent["fillStates"])
    total_fees = sum((Decimal(row["fee"]) for row in fill_semantics), Decimal(0))
    total_slippage = sum(
        (Decimal(row["slippage"]) for row in fill_semantics), Decimal(0)
    )
    realized_pnl = sum(
        (Decimal(row["realizedPnl"]) for row in fill_semantics), Decimal(0)
    )
    closing_count = sum(row["side"] == "SELL" for row in fill_semantics)
    winning_count = sum(
        row["side"] == "SELL" and Decimal(row["realizedPnl"]) > 0
        for row in fill_semantics
    )
    losing_count = sum(
        row["side"] == "SELL" and Decimal(row["realizedPnl"]) < 0
        for row in fill_semantics
    )
    cash = (
        money(Decimal(str(run["initial_cash_amount"])))
        if not fill_states
        else fill_states[-1][1]
    )

    candidate_records = sorted(
        (row for row in trades if row["kind"] in {"ORDER", "REJECTION"}),
        key=lambda item: (item["occurred_at"], item["record_id"]),
    )
    if len({row["order_id"] for row in candidate_records}) != len(candidate_records):
        raise AssertionError("persisted candidate order identities are not unique")
    trigger_semantics = list(independent["triggerSemantics"])
    triggered_operations = set(independent["triggeredOperations"])
    opportunities = list(independent["opportunities"])
    opportunity_counts = dict(independent["opportunityCounts"])
    no_signal_evaluations_checked = len(opportunities)

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
    result_object_semantics = canonical_result_object_semantics(
        detail_objects,
        trade_record_aliases=trade_record_aliases,
        order_aliases=independent["orderAliases"],
        fill_aliases=independent["fillAliases"],
        ledger_aliases=independent["ledgerAliases"],
    )
    semantic_material = {
        "inputs": {
            "compiledPlanChecksum": run["compiled_plan_checksum"],
            "executionPolicyVersion": run["execution_policy_version"],
            "sourceObjects": sorted(source_versions),
            "featureObjects": sorted(
                [row["object_key"], row["provider_version_id"], row["content_hash"]]
                for row in feature_objects
            ),
        },
        "opportunities": opportunities,
        "orders": independent["orders"],
        "cancellations": independent["cancellations"],
        "fills": fill_semantics,
        "ledger": independent["ledgerSemantics"],
        "positions": independent["positions"],
        "equityCurve": equity_curve,
        "metrics": metrics_material,
        "resultObjects": result_object_semantics,
    }
    semantic_result_hash = semantic_repetition_hash(semantic_material)
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
        "opportunityCount": len(opportunities),
        "opportunityOutcomeCounts": opportunity_counts,
        "opportunitySemanticHash": _canonical_hash(opportunities),
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
        "orderSemanticHash": _canonical_hash(independent["orders"]),
        "cancellationSemanticHash": _canonical_hash(independent["cancellations"]),
        "ledgerSemanticHash": _canonical_hash(independent["ledgerSemantics"]),
        "positionSemanticHash": _canonical_hash(independent["positions"]),
        "resultObjectSemanticHash": _canonical_hash(result_object_semantics),
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
