"""Collect and validate the finite Task 4 corpus into a sanitized Task 2 receipt."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from collections import Counter, defaultdict
from collections.abc import Mapping, Sequence
from datetime import datetime
from pathlib import Path
from typing import Any

from backtest_actual_run_oracle import reconcile, reconcile_terminal_inputs
from release_proof_runner import write_sanitized_receipt
from sqlalchemy import create_engine, text

EXPECTED_COUNTS = {
    "active-long-growth": 3,
    "single-clock": 3,
    "mixed-clock": 3,
    "all-block": 3,
    "warning-bearing": 2,
    "no-signal": 3,
    "typed-unavailable": 3,
}
REPEATED_COUNTS = {
    scenario: count for scenario, count in EXPECTED_COUNTS.items() if count == 3
}
TERMINAL_STATES = {"COMPLETED", "UNAVAILABLE"}


def _canonical_hash(value: Any) -> str:
    return hashlib.sha256(
        json.dumps(
            value,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
    ).hexdigest()


def _sha256_tag(value: str) -> str:
    return value if value.startswith("sha256:") else f"sha256:{value}"


def _scenario_for(key: str, seed: str) -> str:
    prefix = f"{seed}-"
    if not key.startswith(prefix):
        raise AssertionError("release-proof run escaped the requested batch seed")
    suffix = key[len(prefix) :]
    for scenario in EXPECTED_COUNTS:
        scenario_prefix = f"{scenario}-"
        if (
            suffix.startswith(scenario_prefix)
            and suffix[len(scenario_prefix) :].isdigit()
        ):
            return scenario
    raise AssertionError("release-proof run has an unknown scenario identity")


def assert_sequential_terminal_runs(rows: Sequence[Mapping[str, Any]]) -> None:
    """Prove the custom-lane corpus was finite, terminal, and non-overlapping."""
    if not rows:
        raise AssertionError("release-proof corpus is empty")
    prior_completed: datetime | None = None
    for row in rows:
        if row["status"] not in TERMINAL_STATES:
            raise AssertionError("release-proof corpus contains a nonterminal run")
        started = row.get("started_at")
        completed = row.get("completed_at")
        if not isinstance(started, datetime) or not isinstance(completed, datetime):
            raise TypeError("release-proof run has no finite terminal interval")
        if completed < started:
            raise AssertionError("release-proof run completed before it started")
        if prior_completed is not None and started < prior_completed:
            raise AssertionError("custom-lane release-proof runs overlapped")
        prior_completed = completed


def assert_repeatable_evidence(
    evidence: Sequence[Mapping[str, Any]],
    expected_counts: Mapping[str, int] = REPEATED_COUNTS,
) -> None:
    """Require identical immutable inputs and semantic results for each repetition."""
    by_scenario: dict[str, list[Mapping[str, Any]]] = defaultdict(list)
    for item in evidence:
        by_scenario[str(item["scenario"])].append(item)
    for scenario, expected in expected_counts.items():
        items = by_scenario.get(scenario, [])
        if len(items) != expected:
            raise AssertionError(f"repeatable scenario count differs: {scenario}")
        if any(len(item["input"]) != 5 for item in items):
            raise AssertionError(
                f"repeatable scenario has no five-part immutable input evidence: {scenario}"
            )
        if len({_canonical_hash(item["input"]) for item in items}) != 1:
            raise AssertionError(f"immutable input repetition differs: {scenario}")
        if len({str(item["semantic"]) for item in items}) != 1:
            raise AssertionError(f"semantic result repetition differs: {scenario}")


def _load_rows(seed: str) -> tuple[list[dict[str, Any]], dict[str, list[str]]]:
    database_url = os.environ.get(
        "DATABASE_URL", os.environ.get("BACKTEST_DATABASE_URL", "")
    )
    if not database_url:
        raise RuntimeError("DATABASE_URL or BACKTEST_DATABASE_URL is required")
    if database_url.startswith("postgresql://"):
        database_url = database_url.replace("postgresql://", "postgresql+psycopg://", 1)
    engine = create_engine(database_url)
    with engine.connect() as connection:
        rows = [
            dict(row)
            for row in connection.execute(
                text(
                    """select r.id::text run_id, r.idempotency_key, r.lane, r.status,
                              r.queued_at, r.started_at, r.completed_at, r.failure_code,
                              r.missing_requirements, r.result_hash,
                              p.input_bundle_fingerprint
                       from backtest.runs r
                       join backtest.run_input_pins p on p.run_id=r.id
                       where r.idempotency_key like :prefix
                       order by r.queued_at,r.id"""
                ),
                {"prefix": f"{seed}-%"},
            ).mappings()
        ]
        run_ids = [row["run_id"] for row in rows]
        attempts: dict[str, list[str]] = defaultdict(list)
        if run_ids:
            for attempt in connection.execute(
                text(
                    """select id::text attempt_id,run_id::text run_id,attempt_number,
                              status,started_at,completed_at
                       from backtest.run_attempts
                       where run_id = any(cast(:run_ids as uuid[]))
                       order by run_id,attempt_number"""
                ),
                {"run_ids": run_ids},
            ).mappings():
                if attempt["completed_at"] is None:
                    raise AssertionError("release-proof attempt is not terminal")
                attempts[attempt["run_id"]].append(attempt["attempt_id"])
    return rows, attempts


def collect(seed: str) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    rows, attempts = _load_rows(seed)
    if len(rows) != sum(EXPECTED_COUNTS.values()):
        raise AssertionError(
            "release-proof corpus does not contain exactly twenty runs"
        )
    if any(row["lane"] != "CUSTOM" for row in rows):
        raise AssertionError("release-proof run escaped the custom lane")
    scenario_counts = Counter(
        _scenario_for(row["idempotency_key"], seed) for row in rows
    )
    if dict(scenario_counts) != EXPECTED_COUNTS:
        raise AssertionError("release-proof scenario distribution differs")
    assert_sequential_terminal_runs(rows)

    receipts: list[dict[str, Any]] = []
    audit_runs: list[dict[str, Any]] = []
    repetition_evidence: list[dict[str, Any]] = []
    for row in rows:
        scenario = _scenario_for(row["idempotency_key"], seed)
        attempt_lineage = attempts.get(row["run_id"], [])
        if len(attempt_lineage) != 1:
            raise AssertionError(
                "fresh release-proof run does not have exactly one attempt"
            )
        duration = (row["completed_at"] - row["started_at"]).total_seconds()
        missing = row["missing_requirements"]
        if row["status"] == "COMPLETED":
            if (
                row["failure_code"] is not None
                or missing is not None
                or not row["result_hash"]
            ):
                raise AssertionError(
                    "completed release-proof terminal fields are inconsistent"
                )
            oracle = reconcile(row["run_id"])
            trade_counts = {
                "ORDER": int(oracle["orderCount"]),
                "FILL": int(oracle["fillCount"]),
                "REJECTION": int(oracle["rejectionCount"]),
                "CANCELLATION": int(oracle["cancellationCount"]),
            }
            receipt_result_hash = _sha256_tag(str(row["result_hash"]))
            failure_reason = None
            repetition_evidence.append(
                {
                    "scenario": scenario,
                    "input": [
                        oracle["bundleFingerprint"],
                        oracle["sourceVersionDigest"],
                        oracle["compiledPlanChecksum"],
                        oracle["strategySnapshotHash"],
                        oracle["executionPolicyVersion"],
                    ],
                    "semantic": oracle["semanticResultHash"],
                    "runResultHash": receipt_result_hash,
                }
            )
        else:
            if not row["failure_code"] or not missing or row["result_hash"] is not None:
                raise AssertionError(
                    "typed-unavailable terminal fields are inconsistent"
                )
            oracle = reconcile_terminal_inputs(row["run_id"])
            trade_counts = {
                kind: 0 for kind in ("ORDER", "FILL", "REJECTION", "CANCELLATION")
            }
            terminal_material = {
                "failureCode": row["failure_code"],
                "missingRequirements": missing,
            }
            receipt_result_hash = _sha256_tag(_canonical_hash(terminal_material))
            failure_reason = str(row["failure_code"])
            repetition_evidence.append(
                {
                    "scenario": scenario,
                    "input": [
                        oracle["bundleFingerprint"],
                        oracle["sourceVersionDigest"],
                        oracle["compiledPlanChecksum"],
                        oracle["strategySnapshotHash"],
                        oracle["executionPolicyVersion"],
                    ],
                    "semantic": _canonical_hash(terminal_material),
                    "runResultHash": receipt_result_hash,
                }
            )
        receipts.append(
            {
                "scenario": f"actual-data/{row['idempotency_key'][len(seed) + 1 :]}",
                "seed": seed,
                "input_fingerprint": _sha256_tag(str(row["input_bundle_fingerprint"])),
                "terminal_state": row["status"],
                "duration_seconds": duration,
                "run_id": row["run_id"],
                "attempt_lineage": attempt_lineage,
                "result_hash": receipt_result_hash,
                "trade_kind_counts": trade_counts,
                "failure_reason": failure_reason,
                "resource_peak": {},
            }
        )
        audit_runs.append(
            {
                "scenario": scenario,
                "idempotencyKey": row["idempotency_key"],
                "runId": row["run_id"],
                "status": row["status"],
                "queuedAt": row["queued_at"].isoformat(),
                "startedAt": row["started_at"].isoformat(),
                "completedAt": row["completed_at"].isoformat(),
                "durationSeconds": duration,
                "attemptLineage": attempt_lineage,
                "failureCode": row["failure_code"],
                "missingRequirements": missing,
                "oracle": oracle,
            }
        )
    assert_repeatable_evidence(repetition_evidence)
    audit = {
        "batchSeed": seed,
        "receiptCount": len(receipts),
        "scenarioCounts": dict(sorted(scenario_counts.items())),
        "terminalCounts": dict(sorted(Counter(row["status"] for row in rows).items())),
        "sequentialCustomLane": True,
        "repetitionEvidence": repetition_evidence,
        "runs": audit_runs,
    }
    return receipts, audit


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", required=True)
    parser.add_argument("--receipt", type=Path, required=True)
    parser.add_argument("--audit", type=Path)
    arguments = parser.parse_args()
    receipts, audit = collect(arguments.seed)
    write_sanitized_receipt(arguments.receipt, receipts)
    if arguments.audit is not None:
        arguments.audit.parent.mkdir(parents=True, exist_ok=True)
        arguments.audit.write_text(
            json.dumps(audit, ensure_ascii=False, sort_keys=True, indent=2) + "\n",
            encoding="utf-8",
        )
    print(
        json.dumps(
            {
                "receiptCount": audit["receiptCount"],
                "scenarioCounts": audit["scenarioCounts"],
                "terminalCounts": audit["terminalCounts"],
                "sequentialCustomLane": audit["sequentialCustomLane"],
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
