from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest
from actual_data_receipt_collector import (
    assert_repeatable_evidence,
    assert_sequential_terminal_runs,
)


def _run(index: int) -> dict[str, object]:
    started = datetime(2026, 9, 1, 0, index * 2, tzinfo=UTC)
    return {
        "idempotency_key": f"proof-single-clock-{index:02d}",
        "status": "COMPLETED",
        "started_at": started,
        "completed_at": started + timedelta(minutes=1),
    }


def test_custom_lane_proof_requires_finite_nonoverlapping_terminal_runs() -> None:
    rows = [_run(1), _run(2), _run(3)]

    assert_sequential_terminal_runs(rows)

    rows[1]["started_at"] = rows[0]["completed_at"] - timedelta(microseconds=1)
    with pytest.raises(AssertionError, match="overlapped"):
        assert_sequential_terminal_runs(rows)


def test_repetition_proof_compares_inputs_and_semantic_outputs_not_run_hashes() -> None:
    evidence = [
        {
            "scenario": "single-clock",
            "input": ["bundle", "sources", "plan", "policy"],
            "semantic": "same-semantic-result",
            "runResultHash": f"run-specific-{index}",
        }
        for index in range(3)
    ]

    assert_repeatable_evidence(evidence, {"single-clock": 3})

    evidence[-1]["semantic"] = "different"
    with pytest.raises(AssertionError, match="semantic"):
        assert_repeatable_evidence(evidence, {"single-clock": 3})
