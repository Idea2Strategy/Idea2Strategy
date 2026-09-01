from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest
from release_proof_runner import (
    ScenarioResult,
    assert_terminal_runs,
    write_sanitized_receipt,
)

RUNNER = Path(__file__).with_name("release_proof_runner.py")
SENTINEL_SECRET = "Bearer sentinel-12345678"


def valid_result(**overrides: object) -> dict[str, object]:
    result: dict[str, object] = {
        "scenario": "actual-data/basic-single-instrument",
        "seed": "release-proof-2026-08-31",
        "input_fingerprint": "sha256:0123456789abcdef",
        "terminal_state": "COMPLETED",
        "duration_seconds": 1.25,
        "run_id": "run-0001",
        "attempt_lineage": ["attempt-0001"],
        "result_hash": "sha256:abcdef0123456789",
        "trade_kind_counts": {"BUY": 1, "SELL": 1},
        "failure_reason": None,
        "resource_peak": {"peak_rss_bytes": 4096},
    }
    result.update(overrides)
    return result


# Production mutation caught: removing a required receipt-evidence field must not
# turn a malformed run into apparently usable release proof.
@pytest.mark.parametrize(
    "missing_field",
    [
        "scenario",
        "seed",
        "input_fingerprint",
        "terminal_state",
        "duration_seconds",
        "run_id",
        "attempt_lineage",
        "result_hash",
        "trade_kind_counts",
        "failure_reason",
        "resource_peak",
    ],
)
def test_receipt_rejects_results_missing_required_evidence(
    tmp_path, missing_field: str
) -> None:
    malformed = valid_result()
    del malformed[missing_field]

    with pytest.raises(ValueError, match="^invalid release-proof receipt$") as error:
        write_sanitized_receipt(tmp_path / "receipt.json", [malformed])

    assert missing_field not in str(error.value)


# Production mutation caught: accepting a credential-shaped field would persist a
# secret in the release evidence artifact or reveal its field name in diagnostics.
def test_receipt_rejects_secret_like_fields(tmp_path) -> None:
    secret_bearing = valid_result(api_token="not-a-real-token")

    with pytest.raises(ValueError, match="^invalid release-proof receipt$"):
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
                "attempt_lineage": ["attempt-0001"],
                "scenario": "alpha",
                "failure_reason": None,
                "resource_peak": {"peak_rss_bytes": 4096},
                "result_hash": "sha256:abcdef0123456789",
                "run_id": "run-0001",
                "seed": "9",
                "terminal_state": "COMPLETED",
                "trade_kind_counts": {"BUY": 1, "SELL": 1},
            },
            {
                "duration_seconds": 1.25,
                "input_fingerprint": "sha256:z",
                "attempt_lineage": ["attempt-0001"],
                "scenario": "zeta",
                "failure_reason": None,
                "resource_peak": {"peak_rss_bytes": 4096},
                "result_hash": "sha256:abcdef0123456789",
                "run_id": "run-0001",
                "seed": "2",
                "terminal_state": "COMPLETED",
                "trade_kind_counts": {"BUY": 1, "SELL": 1},
            },
        ],
        "schema_version": 1,
    }


# Production mutation caught: accepting queued, running, or legacy diagnostic
# vocabulary would allow the receipt to misrepresent the service lifecycle.
@pytest.mark.parametrize("terminal_state", ["QUEUED", "RUNNING", "PASSED", "TIMEOUT"])
def test_assert_terminal_runs_rejects_noncanonical_or_nonterminal_results(
    terminal_state: str,
) -> None:
    with pytest.raises(ValueError, match="^invalid release-proof receipt$"):
        assert_terminal_runs([ScenarioResult(**valid_result(terminal_state=terminal_state))])


@pytest.mark.parametrize("terminal_state", ["COMPLETED", "FAILED", "CANCELLED", "UNAVAILABLE"])
def test_assert_terminal_runs_accepts_each_reportable_terminal_state(
    terminal_state: str,
) -> None:
    assert_terminal_runs([ScenarioResult(**valid_result(terminal_state=terminal_state))])


# Production mutation caught: scanning only keys would allow a credential placed in
# an otherwise approved receipt field to persist in the evidence artifact.
@pytest.mark.parametrize(
    "field",
    ["scenario", "seed", "input_fingerprint", "run_id", "result_hash", "failure_reason"],
)
def test_receipt_rejects_secret_like_approved_string_values(tmp_path, field: str) -> None:
    secret_bearing = valid_result(**{field: SENTINEL_SECRET})

    with pytest.raises(ValueError, match="^invalid release-proof receipt$") as error:
        write_sanitized_receipt(tmp_path / "receipt.json", [secret_bearing])

    assert SENTINEL_SECRET not in str(error.value)


# Production mutation caught: a broad secret detector would reject normal immutable
# identifiers, hashes, and typed failure evidence, preventing valid receipts.
def test_receipt_allows_legitimate_ids_hashes_and_typed_failure_reason(tmp_path) -> None:
    receipt_path = tmp_path / "receipt.json"
    write_sanitized_receipt(
        receipt_path,
        [
            valid_result(
                terminal_state="FAILED",
                input_fingerprint="sha256:0123456789abcdef",
                run_id="2e0be20f-4beb-448e-82ff-d30f6d3e831f",
                result_hash="sha256:fedcba9876543210",
                failure_reason="TEST_TIMEOUT",
            )
        ],
    )

    assert json.loads(receipt_path.read_text(encoding="utf-8"))["results"][0]["failure_reason"] == "TEST_TIMEOUT"


# Production mutation caught: accepting an object as a failure reason makes terminal
# failure evidence ambiguous and prevents deterministic typed reporting.
def test_receipt_rejects_untyped_failure_reason(tmp_path) -> None:
    with pytest.raises(ValueError, match="^invalid release-proof receipt$"):
        write_sanitized_receipt(tmp_path / "receipt.json", [valid_result(failure_reason=["TIMEOUT"])])


# Production mutation caught: formatting caller input into an invalid-state error
# would leak a supplied value into logs or the command line.
def test_invalid_state_error_does_not_echo_caller_value(tmp_path) -> None:
    invalid_state = "RUNNING-sentinel-12345678"

    with pytest.raises(ValueError, match="^invalid release-proof receipt$") as error:
        write_sanitized_receipt(
            tmp_path / "receipt.json", [valid_result(terminal_state=invalid_state)]
        )

    assert invalid_state not in str(error.value)


# Production mutation caught: CLI exception formatting would expose a supplied
# credential-shaped value even if the receipt writer rejects it.
def test_cli_error_output_does_not_echo_sentinel_secret(tmp_path) -> None:
    result = subprocess.run(
        [
            sys.executable,
            str(RUNNER),
            "--receipt",
            str(tmp_path / "receipt.json"),
            "--result",
            json.dumps(valid_result(failure_reason=SENTINEL_SECRET)),
        ],
        capture_output=True,
        check=False,
        text=True,
    )

    assert result.returncode == 2
    assert SENTINEL_SECRET not in f"{result.stdout}{result.stderr}"


# Production mutation caught: treating an empty result collection as release proof
# lets the gate pass without exercising a single asynchronous scenario.
def test_receipt_rejects_empty_results(tmp_path) -> None:
    with pytest.raises(ValueError, match="^invalid release-proof receipt$"):
        write_sanitized_receipt(tmp_path / "receipt.json", [])


# Production mutation caught: a CLI that exits successfully without `--result`
# allows `verify:release-proof` to green-light an empty release candidate.
def test_cli_rejects_zero_scenarios(tmp_path) -> None:
    result = subprocess.run(
        [sys.executable, str(RUNNER), "--receipt", str(tmp_path / "receipt.json")],
        capture_output=True,
        check=False,
        text=True,
    )

    assert result.returncode == 2
    assert not (tmp_path / "receipt.json").exists()


# Production mutation caught: rejecting all command-line results makes the release
# command unusable even when it receives one complete, terminal scenario receipt.
def test_cli_writes_a_valid_terminal_scenario(tmp_path) -> None:
    receipt_path = tmp_path / "receipt.json"
    result = subprocess.run(
        [
            sys.executable,
            str(RUNNER),
            "--receipt",
            str(receipt_path),
            "--result",
            json.dumps(valid_result()),
        ],
        capture_output=True,
        check=False,
        text=True,
    )

    assert result.returncode == 0
    assert json.loads(receipt_path.read_text(encoding="utf-8"))["results"][0]["run_id"] == "run-0001"
