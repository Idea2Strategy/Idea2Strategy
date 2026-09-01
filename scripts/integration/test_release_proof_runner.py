from __future__ import annotations

import json

import pytest
from release_proof_runner import (
    ScenarioResult,
    assert_terminal_runs,
    write_sanitized_receipt,
)


def valid_result(**overrides: object) -> dict[str, object]:
    result: dict[str, object] = {
        "scenario": "actual-data/basic-single-instrument",
        "seed": "release-proof-2026-08-31",
        "input_fingerprint": "sha256:0123456789abcdef",
        "terminal_state": "PASSED",
        "duration_seconds": 1.25,
    }
    result.update(overrides)
    return result


# Production mutation caught: removing a required receipt-evidence field must not
# turn a malformed run into apparently usable release proof.
@pytest.mark.parametrize(
    "missing_field",
    ["scenario", "seed", "input_fingerprint", "terminal_state", "duration_seconds"],
)
def test_receipt_rejects_results_missing_required_evidence(
    tmp_path, missing_field: str
) -> None:
    malformed = valid_result()
    del malformed[missing_field]

    with pytest.raises(ValueError, match=missing_field):
        write_sanitized_receipt(tmp_path / "receipt.json", [malformed])


# Production mutation caught: accepting a credential-shaped field would persist a
# secret in the release evidence artifact.
def test_receipt_rejects_secret_like_fields(tmp_path) -> None:
    secret_bearing = valid_result(api_token="not-a-real-token")

    with pytest.raises(ValueError, match="secret-like"):
        write_sanitized_receipt(tmp_path / "receipt.json", [secret_bearing])


# Production mutation caught: preserving caller order makes receipt bytes vary for
# identical results and hides changes between repeatable release runs.
def test_receipt_sorts_results_deterministically(tmp_path) -> None:
    receipt_path = tmp_path / "receipt.json"
    write_sanitized_receipt(
        receipt_path,
        [
            valid_result(scenario="zeta", seed="2", input_fingerprint="sha256:z"),
            valid_result(scenario="alpha", seed="9", input_fingerprint="sha256:a"),
        ],
    )

    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    assert receipt == {
        "results": [
            {
                "duration_seconds": 1.25,
                "input_fingerprint": "sha256:a",
                "scenario": "alpha",
                "seed": "9",
                "terminal_state": "PASSED",
            },
            {
                "duration_seconds": 1.25,
                "input_fingerprint": "sha256:z",
                "scenario": "zeta",
                "seed": "2",
                "terminal_state": "PASSED",
            },
        ],
        "schema_version": 1,
    }


# Production mutation caught: treating a queued or running outcome as complete
# would let a release gate report success while asynchronous work is still live.
def test_assert_terminal_runs_rejects_nonterminal_results() -> None:
    with pytest.raises(ValueError, match="nonterminal"):
        assert_terminal_runs([ScenarioResult(**valid_result(terminal_state="RUNNING"))])


@pytest.mark.parametrize("terminal_state", ["PASSED", "FAILED", "TIMEOUT", "UNAVAILABLE"])
def test_assert_terminal_runs_accepts_each_reportable_terminal_state(
    terminal_state: str,
) -> None:
    assert_terminal_runs([ScenarioResult(**valid_result(terminal_state=terminal_state))])
