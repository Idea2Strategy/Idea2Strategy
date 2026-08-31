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
from collections import defaultdict, deque
from collections.abc import Iterable
from datetime import date
from decimal import ROUND_HALF_EVEN, Decimal
from io import BytesIO
from typing import Any

import boto3
import pyarrow.parquet as pq
from sqlalchemy import create_engine, text

MONEY = Decimal("0.00000001")


def money(value: Decimal) -> Decimal:
    return value.quantize(MONEY, rounding=ROUND_HALF_EVEN)


def infer_side(entries: Iterable[dict[str, Any]]) -> str:
    security = [row for row in entries if row["account_code"] == "SECURITY"]
    if len(security) != 1:
        raise AssertionError("each fill must post exactly one SECURITY entry")
    return "BUY" if security[0]["direction"] == "DEBIT" else "SELL"


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


def _list_keys(s3: Any, bucket: str, prefix: str) -> list[str]:
    keys: list[str] = []
    token: str | None = None
    while True:
        request: dict[str, Any] = {"Bucket": bucket, "Prefix": prefix}
        if token is not None:
            request["ContinuationToken"] = token
        page = s3.list_objects_v2(**request)
        keys.extend(item["Key"] for item in page.get("Contents", ()))
        token = page.get("NextContinuationToken")
        if token is None:
            return sorted(keys)


def _parquet_rows(s3: Any, bucket: str, key: str) -> list[dict[str, Any]]:
    body = s3.get_object(Bucket=bucket, Key=key)["Body"].read()
    return pq.read_table(BytesIO(body)).to_pylist()


def reconcile(run_id: str) -> dict[str, Any]:
    database_url = os.environ["DATABASE_URL"].replace(
        "postgresql://", "postgresql+psycopg://", 1
    )
    s3 = boto3.client(
        "s3",
        endpoint_url=os.environ.get("S3_ENDPOINT_URL"),
        region_name=os.environ.get(
            "S3_REGION", os.environ.get("AWS_REGION", "us-east-1")
        ),
    )
    engine = create_engine(database_url)
    with engine.connect() as connection:
        run = (
            connection.execute(
                text(
                    """select r.status, r.initial_cash_amount, r.evaluation_end,
                p.input_bundle_fingerprint, p.compiled_plan_checksum,
                p.strategy_snapshot_hash, p.execution_policy_version,
                ep.policy_document, ps.metrics_document
                from backtest.runs r
                join backtest.run_input_pins p on p.run_id=r.id
                join backtest.execution_policy_versions ep
                  on ep.version=p.execution_policy_version
                join backtest.performance_summaries ps on ps.run_id=r.id
                where r.id=:run_id"""
                ),
                {"run_id": run_id},
            )
            .mappings()
            .one()
        )
        if run["status"] != "COMPLETED":
            raise AssertionError(f"run is not completed: {run['status']}")
        sources = (
            connection.execute(
                text(
                    """select m.id::text manifest_id, m.instrument_id::text instrument_id,
                m.dataset_hash, d.locked_dataset_hash, o.bucket_name, o.object_key,
                o.content_hash, o.row_count
                from backtest.run_input_pins p
                join backtest.input_datasets d on d.input_bundle_id=p.input_bundle_id
                join market_data.dataset_manifests m on m.id=d.dataset_manifest_id
                join market_data.dataset_objects mo on mo.dataset_manifest_id=m.id
                join storage.objects o on o.id=mo.object_id
                where p.run_id=:run_id order by m.instrument_id,m.period_start,o.object_key"""
                ),
                {"run_id": run_id},
            )
            .mappings()
            .all()
        )

    market: dict[tuple[str, date], dict[str, Any]] = {}
    source_rows = 0
    for source in sources:
        if (
            str(source["locked_dataset_hash"]).removeprefix("sha256:")
            != source["dataset_hash"]
        ):
            raise AssertionError("locked dataset hash differs from its pinned manifest")
        body = s3.get_object(Bucket=source["bucket_name"], Key=source["object_key"])[
            "Body"
        ].read()
        if hashlib.sha256(body).hexdigest() != source["content_hash"]:
            raise AssertionError(f"source object hash mismatch: {source['object_key']}")
        table = pq.read_table(BytesIO(body))
        if table.num_rows != source["row_count"]:
            raise AssertionError(f"source row count mismatch: {source['object_key']}")
        source_rows += table.num_rows
        for row in table.to_pylist():
            key = (str(row["instrument_id"]), row["session_date_et"])
            if key in market:
                raise AssertionError(f"duplicate pinned market session: {key}")
            market[key] = row

    results_bucket = os.environ.get(
        "S3_RESULTS_BUCKET", os.environ["BACKTEST_RESULTS_BUCKET"]
    )
    result_prefix = os.environ.get("BACKTEST_RESULTS_PREFIX", "backtest-results").strip(
        "/"
    )
    result_rows: dict[str, list[dict[str, Any]]] = {}
    for record_type in ("TRADE_DETAIL", "REPLAY_LEDGER"):
        prefix = f"{result_prefix}/{run_id}/{record_type}/"
        result_rows[record_type] = [
            row
            for key in _list_keys(s3, results_bucket, prefix)
            for row in _parquet_rows(s3, results_bucket, key)
        ]

    ledgers: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for entry in result_rows["REPLAY_LEDGER"]:
        ledgers[entry["source_event_id"]].append(entry)
    for entries in ledgers.values():
        debit = sum(
            Decimal(row["amount"]) for row in entries if row["direction"] == "DEBIT"
        )
        credit = sum(
            Decimal(row["amount"]) for row in entries if row["direction"] == "CREDIT"
        )
        if debit != credit:
            raise AssertionError(
                f"unbalanced transaction: debit={debit}, credit={credit}"
            )

    fills = [row for row in result_rows["TRADE_DETAIL"] if row["kind"] == "FILL"]
    policy = run["policy_document"]
    fee_rate = Decimal(str(policy["feeRate"]))
    slippage_bps = Decimal(str(policy["slippageRateBps"]))
    cash = money(Decimal(str(run["initial_cash_amount"])))
    lots: dict[str, deque[list[Decimal]]] = defaultdict(deque)
    quantities: dict[str, Decimal] = defaultdict(Decimal)
    total_fees = Decimal(0)
    total_slippage = Decimal(0)
    realized_pnl = Decimal(0)

    ordered_fills: list[dict[str, Any]] = []
    by_instant: dict[Any, list[dict[str, Any]]] = defaultdict(list)
    for fill in fills:
        by_instant[fill["occurred_at"]].append(fill)
    ordering_cash = cash
    for instant in sorted(by_instant):
        remaining = by_instant[instant]
        while remaining:
            matching: list[dict[str, Any]] = []
            for candidate in remaining:
                candidate_entries = ledgers[candidate["fill_id"]]
                candidate_side = infer_side(candidate_entries)
                gross = Decimal(candidate["gross_amount"])
                fee = Decimal(candidate["fee"])
                after = Decimal(candidate["cash_after"])
                before = (
                    after + gross + fee
                    if candidate_side == "BUY"
                    else after - gross + fee
                )
                if money(before) == ordering_cash:
                    matching.append(candidate)
            if len(matching) != 1:
                raise AssertionError(
                    f"cash chain is not uniquely reconstructable at {instant}: {len(matching)} matches"
                )
            selected = matching[0]
            remaining.remove(selected)
            ordered_fills.append(selected)
            ordering_cash = Decimal(selected["cash_after"])

    for fill in ordered_fills:
        fill_id = fill["fill_id"]
        entries = ledgers.get(fill_id)
        if entries is None:
            raise AssertionError(f"fill has no ledger transaction: {fill_id}")
        side = infer_side(entries)
        session_key = (fill["instrument_id"], fill["occurred_at"].date())
        raw = market.get(session_key)
        if raw is None:
            raise AssertionError(f"fill has no pinned market session: {session_key}")
        raw_open = money(Decimal(str(raw["open"])))
        base = Decimal(fill["base_price"])
        quantity = Decimal(fill["quantity"])
        if base != raw_open:
            raise AssertionError(f"fill base price differs from raw open: {fill_id}")
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
        if side == "BUY":
            lots[fill["instrument_id"]].append([quantity, gross])
            quantities[fill["instrument_id"]] += quantity
            cash = money(cash - gross - fee)
            expected_cost = gross
            expected_realized = Decimal(0).quantize(MONEY)
        else:
            expected_cost = consume_fifo(lots[fill["instrument_id"]], quantity)
            quantities[fill["instrument_id"]] -= quantity
            expected_realized = money(gross - expected_cost)
            cash = money(cash + gross - fee)
        if Decimal(fill["cost_basis"]) != expected_cost:
            raise AssertionError(f"FIFO cost mismatch: {fill_id}")
        if Decimal(fill["realized_pnl"]) != expected_realized:
            raise AssertionError(f"realized PnL mismatch: {fill_id}")
        if Decimal(fill["cash_after"]) != cash:
            raise AssertionError(f"cash sequence mismatch: {fill_id}")
        total_fees += fee
        total_slippage += slippage
        realized_pnl += expected_realized

    metrics = run["metrics_document"]
    ending_equity = cash
    evaluation_end = run["evaluation_end"]
    for instrument_id, quantity in quantities.items():
        if quantity == 0:
            continue
        candidates = [
            row
            for (candidate_instrument, session), row in market.items()
            if candidate_instrument == instrument_id and session <= evaluation_end
        ]
        if not candidates:
            raise AssertionError(
                f"open position has no terminal valuation bar: {instrument_id}"
            )
        last = max(candidates, key=lambda row: row["session_date_et"])
        ending_equity = money(ending_equity + quantity * Decimal(str(last["close"])))

    expected_metrics = {
        "fillCount": len(fills),
        "totalFees": str(money(total_fees)),
        "totalSlippage": str(money(total_slippage)),
        "realizedPnl": str(money(realized_pnl)),
        "endingCash": str(cash),
        "endingEquity": str(ending_equity),
    }
    for key, expected_value in expected_metrics.items():
        actual_value = metrics[key]
        if str(actual_value) != str(expected_value):
            raise AssertionError(
                f"metric mismatch {key}: {actual_value} != {expected_value}"
            )

    return {
        "runId": run_id,
        "status": "VERIFIED",
        "manifestCount": len(sources),
        "sourceRowCount": source_rows,
        "fillCount": len(fills),
        "ledgerTransactionCount": len(ledgers),
        "bundleFingerprint": run["input_bundle_fingerprint"],
        "compiledPlanChecksum": run["compiled_plan_checksum"],
        "strategySnapshotHash": run["strategy_snapshot_hash"],
        "executionPolicyVersion": run["execution_policy_version"],
        **expected_metrics,
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
