from __future__ import annotations

from datetime import UTC, datetime, timedelta

import pytest
from actual_data_receipt_collector import (
    FIXED_EVALUATION_END,
    FIXED_EVALUATION_START,
    assert_batch_identity,
    assert_persisted_warning,
    assert_repeatable_evidence,
    assert_sequential_terminal_runs,
    expected_batch_keys,
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
            "input": ["bundle", "sources", "plan", "snapshot", "policy"],
            "semantic": "same-semantic-result",
            "runResultHash": f"run-specific-{index}",
        }
        for index in range(3)
    ]

    assert_repeatable_evidence(evidence, {"single-clock": 3})

    evidence[-1]["semantic"] = "different"
    with pytest.raises(AssertionError, match="semantic"):
        assert_repeatable_evidence(evidence, {"single-clock": 3})


def test_repetition_proof_rejects_a_terminal_shape_without_full_input_evidence() -> (
    None
):
    incomplete = [
        {
            "scenario": "typed-unavailable",
            "input": ["bundle-only"],
            "semantic": "same-terminal-result",
            "runResultHash": "same-terminal-hash",
        }
        for _ in range(3)
    ]

    with pytest.raises(AssertionError, match="five-part"):
        assert_repeatable_evidence(incomplete, {"typed-unavailable": 3})


def test_collector_binds_the_exact_batch_keys_and_requested_interval() -> None:
    seed = "proof"
    keys = expected_batch_keys(seed)
    rows = [
        {
            "idempotency_key": key,
            "evaluation_start": FIXED_EVALUATION_START,
            "evaluation_end": FIXED_EVALUATION_END,
        }
        for key in keys
    ]

    assert_batch_identity(rows, seed)
    rows[0]["evaluation_end"] = FIXED_EVALUATION_END - timedelta(days=1)
    with pytest.raises(AssertionError, match="fixed requested interval"):
        assert_batch_identity(rows, seed)
    rows[0]["evaluation_end"] = FIXED_EVALUATION_END
    rows[0]["idempotency_key"] = "proof-unrelated-01"
    with pytest.raises(AssertionError, match="exact current batch"):
        assert_batch_identity(rows, seed)


def test_warning_proof_requires_the_persisted_contradictory_finding() -> None:
    assert_persisted_warning(
        {
            "status": "VALID",
            "result_document": {
                "findings": [{"severity": "WARNING", "code": "CONTRADICTORY_CONDITION"}]
            },
        }
    )

    with pytest.raises(AssertionError, match="CONTRADICTORY_CONDITION"):
        assert_persisted_warning(
            {
                "status": "VALID",
                "result_document": {
                    "findings": [
                        {"severity": "WARNING", "code": "SELL_REQUIRES_POSITION"}
                    ]
                },
            }
        )
