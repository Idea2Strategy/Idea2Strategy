"""Create deterministic, credential-free release-proof receipts."""

from __future__ import annotations

import argparse
import json
import math
import os
import re
import tempfile
from collections.abc import Iterable, Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path
from types import MappingProxyType
from typing import Any

TERMINAL_STATES = frozenset({"COMPLETED", "FAILED", "CANCELLED", "UNAVAILABLE"})
REQUIRED_RESULT_FIELDS = (
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
)
_SECRET_FIELD = re.compile(
    r"(?:password|secret|token|credential|api[-_]?key|cookie|authorization)",
    re.IGNORECASE,
)
_SECRET_VALUE = re.compile(
    r"(?:\b(?:bearer|basic)\s+[A-Za-z0-9._~-]{8,}|"
    r"\b(?:password|secret|token|credential|api[-_]?key|cookie|authorization)\s*[:=]\s*\S+|"
    r"\b(?:ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|"
    r"xox[baprs]-[A-Za-z0-9-]{8,}|(?:sk|rk)_(?:test|live)_[A-Za-z0-9_-]{8,}|"
    r"sk-proj-[A-Za-z0-9_-]{12,}|AKIA[A-Z0-9]{16}|"
    r"eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}))",
    re.IGNORECASE,
)
_INVALID_RECEIPT = "invalid release-proof receipt"


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
    run_id: str
    attempt_lineage: tuple[str, ...]
    result_hash: str
    trade_kind_counts: Mapping[str, int]
    failure_reason: str | None
    resource_peak: Mapping[str, float]

    def __post_init__(self) -> None:
        object.__setattr__(self, "attempt_lineage", tuple(self.attempt_lineage))
        object.__setattr__(self, "trade_kind_counts", MappingProxyType(dict(self.trade_kind_counts)))
        object.__setattr__(self, "resource_peak", MappingProxyType(dict(self.resource_peak)))


def _invalid_receipt() -> ValueError:
    return ValueError(_INVALID_RECEIPT)


def _contains_secret_like_value(value: Any) -> bool:
    if isinstance(value, str):
        return bool(_SECRET_VALUE.search(value))
    if isinstance(value, Mapping):
        return any(
            _contains_secret_like_value(key) or _contains_secret_like_value(item)
            for key, item in value.items()
        )
    if isinstance(value, (list, tuple)):
        return any(_contains_secret_like_value(item) for item in value)
    return False


def _is_nonempty_text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _result_as_dict(result: ScenarioResult) -> dict[str, Any]:
    return {
        "scenario": result.scenario,
        "seed": result.seed,
        "input_fingerprint": result.input_fingerprint,
        "terminal_state": result.terminal_state,
        "duration_seconds": result.duration_seconds,
        "run_id": result.run_id,
        "attempt_lineage": list(result.attempt_lineage),
        "result_hash": result.result_hash,
        "trade_kind_counts": dict(result.trade_kind_counts),
        "failure_reason": result.failure_reason,
        "resource_peak": dict(result.resource_peak),
    }


def _validated_result(raw_result: ScenarioResult | Mapping[str, Any]) -> ScenarioResult:
    if isinstance(raw_result, ScenarioResult):
        raw: dict[str, Any] = _result_as_dict(raw_result)
    elif isinstance(raw_result, Mapping):
        raw = dict(raw_result)
    else:
        raise _invalid_receipt()

    if any(_SECRET_FIELD.search(str(field_name)) for field_name in raw):
        raise _invalid_receipt()
    if _contains_secret_like_value(raw):
        raise _invalid_receipt()

    if any(field not in raw for field in REQUIRED_RESULT_FIELDS):
        raise _invalid_receipt()

    unexpected_fields = set(raw).difference(REQUIRED_RESULT_FIELDS)
    if unexpected_fields:
        raise _invalid_receipt()

    for field in ("scenario", "seed", "input_fingerprint", "terminal_state", "run_id", "result_hash"):
        if not _is_nonempty_text(raw[field]):
            raise _invalid_receipt()

    duration = raw["duration_seconds"]
    if (
        isinstance(duration, bool)
        or not isinstance(duration, (int, float))
        or not math.isfinite(duration)
        or duration < 0
    ):
        raise _invalid_receipt()

    attempt_lineage = raw["attempt_lineage"]
    if not isinstance(attempt_lineage, (list, tuple)) or not attempt_lineage:
        raise _invalid_receipt()
    if not all(_is_nonempty_text(attempt) for attempt in attempt_lineage):
        raise _invalid_receipt()

    trade_kind_counts = raw["trade_kind_counts"]
    if not isinstance(trade_kind_counts, Mapping):
        raise _invalid_receipt()
    if not all(
        _is_nonempty_text(kind)
        and isinstance(count, int)
        and not isinstance(count, bool)
        and count >= 0
        for kind, count in trade_kind_counts.items()
    ):
        raise _invalid_receipt()

    resource_peak = raw["resource_peak"]
    if not isinstance(resource_peak, Mapping):
        raise _invalid_receipt()
    if not all(
        _is_nonempty_text(resource)
        and isinstance(peak, (int, float))
        and not isinstance(peak, bool)
        and math.isfinite(peak)
        and peak >= 0
        for resource, peak in resource_peak.items()
    ):
        raise _invalid_receipt()

    failure_reason = raw["failure_reason"]
    if failure_reason is not None and not _is_nonempty_text(failure_reason):
        raise _invalid_receipt()
    if raw["terminal_state"] == "COMPLETED" and failure_reason is not None:
        raise _invalid_receipt()
    if raw["terminal_state"] in {"FAILED", "CANCELLED", "UNAVAILABLE"} and failure_reason is None:
        raise _invalid_receipt()

    return ScenarioResult(
        scenario=raw["scenario"],
        seed=raw["seed"],
        input_fingerprint=raw["input_fingerprint"],
        terminal_state=raw["terminal_state"],
        duration_seconds=float(duration),
        run_id=raw["run_id"],
        attempt_lineage=tuple(attempt_lineage),
        result_hash=raw["result_hash"],
        trade_kind_counts=dict(trade_kind_counts),
        failure_reason=failure_reason,
        resource_peak={resource: float(peak) for resource, peak in resource_peak.items()},
    )


def assert_terminal_runs(
    results: Iterable[ScenarioResult | Mapping[str, Any]],
) -> tuple[ScenarioResult, ...]:
    """Validate and return results only when every async outcome is terminal."""

    validated = tuple(_validated_result(result) for result in results)
    if not validated:
        raise _invalid_receipt()
    for result in validated:
        if result.terminal_state not in TERMINAL_STATES:
            raise _invalid_receipt()
    return validated


def write_sanitized_receipt(
    receipt_path: Path | str,
    results: Iterable[ScenarioResult | Mapping[str, Any]],
) -> Path:
    """Atomically write a deterministic receipt containing only safe evidence."""

    validated = assert_terminal_runs(results)
    ordered_results = sorted(
        (_result_as_dict(result) for result in validated),
        key=lambda result: json.dumps(result, sort_keys=True, separators=(",", ":")),
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
        raise _invalid_receipt()
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
    try:
        write_sanitized_receipt(arguments.receipt, (_parse_result(value) for value in arguments.result))
    except (OSError, TypeError, ValueError, json.JSONDecodeError):
        parser.error(_INVALID_RECEIPT)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
