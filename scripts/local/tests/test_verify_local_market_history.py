from __future__ import annotations

import importlib.util
from datetime import UTC, datetime
from io import BytesIO
from pathlib import Path

import pyarrow as pa
import pyarrow.parquet as pq

SCRIPT = Path(__file__).resolve().parents[1] / "verify-local-market-history.py"
SPEC = importlib.util.spec_from_file_location("verify_local_market_history", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def test_full_history_uses_shared_and_requested_instrument_manifests_only() -> None:
    requested = "70000000-0000-4000-8000-000000000001"

    assert MODULE._manifest_applies_to_instrument({"instrument_id": None}, requested)
    assert MODULE._manifest_applies_to_instrument({"instrument_id": requested}, requested)
    assert not MODULE._manifest_applies_to_instrument(
        {"instrument_id": "70000000-0000-4000-8000-000000000002"},
        requested,
    )


def test_parquet_verifier_counts_all_rows_but_materializes_only_requested_instrument() -> None:
    requested = "70000000-0000-4000-8000-000000000001"
    other = "70000000-0000-4000-8000-000000000002"
    buffer = BytesIO()
    pq.write_table(
        pa.table({
            "instrument_id": [requested, other],
            "bar_start_at": [
                datetime(2026, 8, 28, 13, 30, tzinfo=UTC),
                datetime(2026, 8, 28, 13, 30, tzinfo=UTC),
            ],
            "open": [100.0, 200.0],
            "high": [101.0, 201.0],
            "low": [99.0, 199.0],
            "close": [100.5, 200.5],
            "volume": [1000, 2000],
        }),
        buffer,
    )

    total_rows, selected = MODULE._read_instrument_rows(buffer.getvalue(), requested)

    assert total_rows == 2
    assert selected.num_rows == 1
    assert selected.column("instrument_id").to_pylist() == [requested]


def test_shared_row_is_shadowed_by_scoped_manifest_covering_the_same_period() -> None:
    requested = "70000000-0000-4000-8000-000000000001"
    shared = {"instrument_id": None}
    scoped = [{
        "instrument_id": requested,
        "period_start": "2026-01-01T00:00:00Z",
        "period_end": "2027-01-01T00:00:00Z",
    }]

    assert MODULE._shared_row_is_shadowed(
        shared,
        scoped,
        requested,
        datetime(2026, 6, 1, tzinfo=UTC),
    )
