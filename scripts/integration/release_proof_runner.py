"""Create deterministic, credential-free release-proof receipts."""

from __future__ import annotations

import argparse
import json
import math
import os
import re
import tempfile
from collections.abc import Iterable, Mapping, Sequence
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

TERMINAL_STATES = frozenset({"PASSED", "FAILED", "TIMEOUT", "UNAVAILABLE"})
REQUIRED_RESULT_FIELDS = (
    "scenario",
    "seed",
    "input_fingerprint",
    "terminal_state",
    "duration_seconds",
)
_SECRET_FIELD = re.compile(
    r"(?:password|secret|token|credential|api[-_]?key|cookie|authorization)",
    re.IGNORECASE,
)


@dataclass(frozen=True, slots=True)
class ReleaseScenario:
    """Immutable identity for one release-proof scenario."""

    scenario: str
    seed: str
    input_fingerprint: str


@dataclass(frozen=True, slots=True)
class ScenarioResult:
    """Terminal evidence for one release-proof scenario."""

    scenario: str
    seed: str
    input_fingerprint: str
    terminal_state: str
    duration_seconds: float


def _validated_result(raw_result: ScenarioResult | Mapping[str, Any]) -> ScenarioResult:
    if isinstance(raw_result, ScenarioResult):
        raw: dict[str, Any] = asdict(raw_result)
    elif isinstance(raw_result, Mapping):
        raw = dict(raw_result)
    else:
        raise TypeError("receipt result must be a ScenarioResult or mapping")

    for field_name in raw:
        if _SECRET_FIELD.search(str(field_name)):
            raise ValueError(f"secret-like receipt field is not allowed: {field_name}")

    missing_fields = [field for field in REQUIRED_RESULT_FIELDS if field not in raw]
    if missing_fields:
        raise ValueError(f"receipt result is missing required field: {missing_fields[0]}")

    unexpected_fields = set(raw).difference(REQUIRED_RESULT_FIELDS)
    if unexpected_fields:
        raise ValueError(f"receipt result contains unexpected field: {min(unexpected_fields)}")

    for field in ("scenario", "seed", "input_fingerprint", "terminal_state"):
        if not isinstance(raw[field], str) or not raw[field].strip():
            raise ValueError(f"receipt result requires a non-empty {field}")

    duration = raw["duration_seconds"]
    if (
        isinstance(duration, bool)
        or not isinstance(duration, (int, float))
        or not math.isfinite(duration)
        or duration < 0
    ):
        raise ValueError("receipt result requires a finite non-negative duration_seconds")

    return ScenarioResult(
        scenario=raw["scenario"],
        seed=raw["seed"],
        input_fingerprint=raw["input_fingerprint"],
        terminal_state=raw["terminal_state"],
        duration_seconds=float(duration),
    )


def assert_terminal_runs(
    results: Iterable[ScenarioResult | Mapping[str, Any]],
) -> tuple[ScenarioResult, ...]:
    """Validate and return results only when every async outcome is terminal."""

    validated = tuple(_validated_result(result) for result in results)
    for result in validated:
        if result.terminal_state not in TERMINAL_STATES:
            raise ValueError(
                f"nonterminal release-proof result for {result.scenario}: "
                f"{result.terminal_state}"
            )
    return validated


def write_sanitized_receipt(
    receipt_path: Path | str,
    results: Iterable[ScenarioResult | Mapping[str, Any]],
) -> Path:
    """Atomically write a deterministic receipt containing only safe evidence."""

    validated = assert_terminal_runs(results)
    ordered_results = sorted(
        (asdict(result) for result in validated),
        key=lambda result: (
            result["scenario"],
            result["seed"],
            result["input_fingerprint"],
            result["terminal_state"],
            result["duration_seconds"],
        ),
    )
    receipt = {"schema_version": 1, "results": ordered_results}
    destination = Path(receipt_path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="w", encoding="utf-8", dir=destination.parent, delete=False
    ) as temporary:
        json.dump(receipt, temporary, indent=2, sort_keys=True, allow_nan=False)
        temporary.write("\n")
        temporary.flush()
        os.fsync(temporary.fileno())
        temporary_path = Path(temporary.name)
    os.replace(temporary_path, destination)
    return destination


def _parse_result(value: str) -> Mapping[str, Any]:
    parsed = json.loads(value)
    if not isinstance(parsed, Mapping):
        raise TypeError("--result must be a JSON object")
    return parsed


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--receipt",
        type=Path,
        default=Path(".local/artifacts/release-proof/receipt.json"),
        help="path for the sanitized receipt",
    )
    parser.add_argument(
        "--result",
        action="append",
        default=[],
        help="one JSON scenario result; may be repeated",
    )
    arguments = parser.parse_args(argv)
    write_sanitized_receipt(arguments.receipt, (_parse_result(value) for value in arguments.result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
