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
KNOWN_CREDENTIAL_SHAPES = (
    "sk-proj-sentinel_1234567890",
    "AKIA0123456789ABCDEF",
    "eyJzZW50aW5lbA.eyJwYXlsb2FkMTIz.signature123",
)


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
    failure_reason = None if terminal_state == "COMPLETED" else "EXPECTED_TERMINAL_REASON"
    assert_terminal_runs(
        [ScenarioResult(**valid_result(terminal_state=terminal_state, failure_reason=failure_reason))]
    )


# Production mutation caught: terminal failure, cancellation, or unavailability
# without a typed reason leaves operators unable to explain the recorded outcome.
@pytest.mark.parametrize(
    ("terminal_state", "failure_reason"),
    [("FAILED", None), ("CANCELLED", ""), ("UNAVAILABLE", None)],
)
def test_noncompleted_terminal_states_require_typed_failure_reasons(
    tmp_path, terminal_state: str, failure_reason: str | None
) -> None:
    with pytest.raises(ValueError, match="^invalid release-proof receipt$"):
        write_sanitized_receipt(
            tmp_path / "receipt.json",
            [valid_result(terminal_state=terminal_state, failure_reason=failure_reason)],
        )


# Production mutation caught: a completed run carrying a failure reason conflates
# successful result evidence with diagnostic failure evidence.
def test_completed_terminal_state_requires_no_failure_reason(tmp_path) -> None:
    with pytest.raises(ValueError, match="^invalid release-proof receipt$"):
        write_sanitized_receipt(
            tmp_path / "receipt.json",
            [valid_result(terminal_state="COMPLETED", failure_reason="TEST_TIMEOUT")],
        )


# Production mutation caught: the CLI bypasses terminal/reason consistency enforced
# by direct receipt construction and accepts misleading release evidence.
@pytest.mark.parametrize(
    ("terminal_state", "failure_reason"),
    [("FAILED", None), ("COMPLETED", "TEST_TIMEOUT")],
)
def test_cli_rejects_inconsistent_terminal_failure_evidence(
    tmp_path, terminal_state: str, failure_reason: str | None
) -> None:
    result = subprocess.run(
        [
            sys.executable,
            str(RUNNER),
            "--receipt",
            str(tmp_path / "receipt.json"),
            "--result",
            json.dumps(valid_result(terminal_state=terminal_state, failure_reason=failure_reason)),
        ],
        capture_output=True,
        check=False,
        text=True,
    )

    assert result.returncode == 2


# Production mutation caught: a frozen dataclass with mutable nested collections
# lets later code alter recorded attempt, trade, or resource evidence in place.
def test_scenario_result_freezes_nested_evidence_at_construction() -> None:
    result = ScenarioResult(**valid_result())

    with pytest.raises(AttributeError):
        result.attempt_lineage.append("attempt-0002")
    with pytest.raises(TypeError):
        result.trade_kind_counts["HOLD"] = 1
    with pytest.raises(TypeError):
        result.resource_peak["peak_cpu_seconds"] = 2.0


# Production mutation caught: validation that retains caller-owned nested values
# permits a caller to rewrite receipt evidence after the terminal assertion returns.
def test_terminal_assertion_coerces_nested_evidence_to_an_immutable_snapshot() -> None:
    source = valid_result()
    result = assert_terminal_runs([source])[0]
    source["attempt_lineage"].append("attempt-0002")
    source["trade_kind_counts"]["HOLD"] = 1
    source["resource_peak"]["peak_cpu_seconds"] = 2.0

    assert result.attempt_lineage == ("attempt-0001",)
    assert dict(result.trade_kind_counts) == {"BUY": 1, "SELL": 1}
    assert dict(result.resource_peak) == {"peak_rss_bytes": 4096.0}


# Production mutation caught: shallow wrappers accept nested mutable values that can
# later alter evidence despite the outer ScenarioResult being frozen.
@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("attempt_lineage", ("attempt-0001", ["attempt-0002"])),
        ("trade_kind_counts", {"BUY": {"count": 1}}),
        ("resource_peak", {"peak_rss_bytes": [4096]}),
    ],
)
def test_scenario_result_rejects_nested_mutable_evidence_at_construction(
    field: str, value: object
) -> None:
    with pytest.raises(ValueError, match="^invalid release-proof receipt$") as error:
        ScenarioResult(**valid_result(**{field: value}))

    assert repr(value) not in str(error.value)


# Production mutation caught: exact nested validation accidentally rejects scalar
# attempt IDs and numeric counters/peaks, or changes their deterministic JSON shape.
def test_direct_scenario_result_keeps_valid_scalar_evidence_serializable(tmp_path) -> None:
    receipt_path = tmp_path / "receipt.json"
    direct_result = ScenarioResult(**valid_result())

    write_sanitized_receipt(receipt_path, [direct_result])

    assert json.loads(receipt_path.read_text(encoding="utf-8"))["results"][0] == valid_result()


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


# Production mutation caught: omitting known credential formats lets a secret pass
# through an approved field merely because it has no assignment label or Bearer prefix.
@pytest.mark.parametrize("credential_like", KNOWN_CREDENTIAL_SHAPES)
def test_receipt_rejects_known_credential_shapes_without_echoing_values(
    tmp_path, credential_like: str
) -> None:
    with pytest.raises(ValueError, match="^invalid release-proof receipt$") as error:
        write_sanitized_receipt(
            tmp_path / "receipt.json", [valid_result(result_hash=credential_like)]
        )

    assert credential_like not in str(error.value)


# Production mutation caught: broadening credential matching can reject ordinary
# immutable IDs, hashes, run IDs, and typed failure codes needed for release evidence.
@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("input_fingerprint", "sha256:0123456789abcdef"),
        ("result_hash", "sha256:fedcba9876543210"),
        ("run_id", "2e0be20f-4beb-448e-82ff-d30f6d3e831f"),
        ("run_id", "run-2026-09-01-001"),
        ("failure_reason", "RETRY_LIMIT_EXCEEDED"),
    ],
)
def test_receipt_allows_ordinary_identifier_shapes(tmp_path, field: str, value: str) -> None:
    result = valid_result(**{field: value})
    if field == "failure_reason":
        result["terminal_state"] = "FAILED"

    write_sanitized_receipt(tmp_path / "receipt.json", [result])


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


# Production mutation caught: an atomic-write filesystem error escapes the CLI and
# prints the caller-controlled receipt target in a traceback.
def test_cli_filesystem_error_does_not_echo_receipt_target(tmp_path) -> None:
    invalid_target = tmp_path / "receipt<>target-sentinel.json"
    result = subprocess.run(
        [
            sys.executable,
            str(RUNNER),
            "--receipt",
            str(invalid_target),
            "--result",
            json.dumps(valid_result()),
        ],
        capture_output=True,
        check=False,
        text=True,
    )

    assert result.returncode == 2
    assert str(invalid_target) not in f"{result.stdout}{result.stderr}"
