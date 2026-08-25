from __future__ import annotations

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "scripts" / "local"))
sys.path.insert(
    0,
    os.environ.get("BACKTEST_ENGINE_SRC", str(ROOT / "backtest-engine" / "src")),
)

from full_range_manifest import (
    COMPOSITE_MANIFEST_ID,
    build_composite_manifest,
)


def _row(year: int, source_id: str, storage_id: str) -> dict[str, object]:
    return {
        "source_manifest_id": source_id,
        "source_relation_id": f"00000000-0000-4000-8000-{year:012d}",
        "storage_object_id": storage_id,
        "object_key": (
            "historical/provider=alpaca/feed=sip/adjustment=all/session=regular/"
            f"resolution=30m/revision=00000001/year={year}/shard=00-of-01/"
            f"manifest_id={source_id}/part-00001.parquet"
        ),
        "content_hash": f"{year % 10}" * 64,
        "row_count": 10,
        "partition_start": f"{year}-01-01",
        "partition_end": f"{year + 1}-01-01",
        "period_start": f"{year}-01-01T00:00:00Z",
        "period_end": f"{year + 1}-01-01T00:00:00Z",
        "shard_key": "s00-of-1",
        "part_number": 1,
        "schema_version": "market-bars/1",
    }


def test_build_composite_manifest_is_deterministic_and_preserves_source_objects() -> None:
    rows = [
        _row(2016, "11111111-1111-4111-8111-111111111111", "aaaaaaaa-0000-4000-8000-000000000001"),
        _row(2017, "22222222-2222-4222-8222-222222222222", "aaaaaaaa-0000-4000-8000-000000000002"),
    ]

    first = build_composite_manifest(rows, period_end="2018-01-01T00:00:00Z")
    second = build_composite_manifest(list(reversed(rows)), period_end="2018-01-01T00:00:00Z")

    assert first == second
    assert first["manifest_id"] == COMPOSITE_MANIFEST_ID
    assert first["composite"] is True
    assert first["dataset_id"] == COMPOSITE_MANIFEST_ID
    assert len(first["objects"]) == 2
    assert len(first["dataset_hash"]) == 64
    assert {item["storage_object_id"] for item in first["objects"]} == {
        row["storage_object_id"] for row in rows
    }
