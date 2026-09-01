"""Read the pinned local-market object used by the Task 3 runtime proof."""

from __future__ import annotations

import hashlib
import json
import subprocess
import tempfile
from collections.abc import Mapping
from dataclasses import dataclass
from datetime import datetime, timezone
from decimal import Decimal
from functools import lru_cache
from pathlib import Path

import pyarrow.parquet as pq
from backtest_engine.basic_runtime import _instrument_inputs, bar_closed_event
from backtest_engine.elements import InstrumentInput

ROOT = Path(__file__).resolve().parents[2]
CORPUS = ROOT / "contracts/fixtures/basic-strategy/v1/basic-element-conformance.v1.json"
CORPUS_SHA256 = "961c0b76f5638c397851e1e909acd8d495fa554904a0349b4aa799bbb90f9286"
BUCKET = "idea2strategy-local-market-data"
OBJECT_KEY = (
    "historical/provider=alpaca/feed=sip/adjustment=all/session=regular/"
    "resolution=30m/revision=00000004/year=2024/shard=00-of-01/"
    "manifest_id=bb559227-dec3-54bd-876d-167c12c6e355/part-00001.parquet"
)
OBJECT_SHA256 = "fa0cebb4e33275239b8ed4f801bdd137508f68bf2b6411f0ab036df3ec283d08"
DATASET_SHA256 = "1bef63d47c134926e9011c3f3df6dba737fe48588a51d12ae78a0c68876f5e21"
MANIFEST_ID = "bb559227-dec3-54bd-876d-167c12c6e355"
OBJECT_ID = "4b0f38c4-5474-5564-8c64-be1799472082"
OBJECT_VERSION_ID = "0879c1fb-df66-40c6-a955-695c6d531d03"
OBJECT_BYTE_SIZE = 381720
OBJECT_ROW_COUNT = 3258
INSTRUMENT_ID = "03e7e685-d6da-4f1f-9279-91477884aab9"
AS_OF = datetime(2024, 1, 2, 16, 30, tzinfo=timezone.utc)


@dataclass(frozen=True, slots=True)
class StoredMarketSnapshot:
    path: Path
    object_sha256: str
    corpus_sha256: str
    as_of: datetime
    inputs: dict[str, InstrumentInput]
    event_ids: tuple[str, ...]
    manifest_id: str
    dataset_sha256: str
    object_key: str
    object_version_id: str
    byte_size: int
    row_count: int


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


_EXPECTED_MANIFEST = {
    "manifest_id": MANIFEST_ID,
    "dataset_hash": DATASET_SHA256,
    "manifest_status": "AVAILABLE",
    "object_count": 1,
    "dataset_row_count": OBJECT_ROW_COUNT,
    "object_id": OBJECT_ID,
    "object_status": "AVAILABLE",
    "bucket": BUCKET,
    "object_key": OBJECT_KEY,
    "provider_version_id": OBJECT_VERSION_ID,
    "content_hash": OBJECT_SHA256,
    "byte_size": OBJECT_BYTE_SIZE,
    "object_row_count": OBJECT_ROW_COUNT,
    "file_format": "PARQUET",
    "schema_version": "market-bars/1",
}


def validate_pinned_market_manifest(metadata: Mapping[str, object]) -> None:
    """Reject any local DB row that differs from the reviewed immutable object pins."""
    for field, expected in _EXPECTED_MANIFEST.items():
        actual = metadata.get(field)
        if actual != expected:
            raise AssertionError(
                f"stored market manifest {field} mismatch: {actual!r} != {expected!r}"
            )


@lru_cache(maxsize=1)
def _load_manifest_metadata() -> dict[str, object]:
    sql = f"""
        select coalesce(jsonb_agg(jsonb_build_object(
            'manifest_id', m.id,
            'dataset_hash', m.dataset_hash,
            'manifest_status', m.status,
            'object_count', m.object_count,
            'dataset_row_count', d.row_count,
            'object_id', o.id,
            'object_status', o.status,
            'bucket', o.bucket_name,
            'object_key', o.object_key,
            'provider_version_id', o.provider_version_id,
            'content_hash', o.content_hash,
            'byte_size', o.byte_size,
            'object_row_count', o.row_count,
            'file_format', o.file_format,
            'schema_version', o.schema_version
        )), '[]'::jsonb)::text
          from market_data.dataset_manifests m
          join market_data.dataset_objects d on d.dataset_manifest_id = m.id
          join storage.objects o on o.id = d.object_id
         where m.id = '{MANIFEST_ID}'::uuid
    """
    completed = subprocess.run(
        [
            "docker",
            "exec",
            "idea2strategy-postgres",
            "psql",
            "-U",
            "idea2strategy",
            "-d",
            "idea2strategy",
            "-At",
            "-v",
            "ON_ERROR_STOP=1",
            "-c",
            sql,
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    rows = json.loads(completed.stdout)
    if not isinstance(rows, list) or len(rows) != 1 or not isinstance(rows[0], dict):
        raise AssertionError(
            f"stored market manifest must resolve exactly one immutable object, got {len(rows)}"
        )
    metadata = rows[0]
    validate_pinned_market_manifest(metadata)
    return metadata


def _fetch_object(path: Path, metadata: Mapping[str, object]) -> None:
    container_path = "/tmp/release-proof-task3-local-market-object.parquet"
    program = (
        "import boto3; boto3.client('s3', endpoint_url='http://minio:9000')"
        f".download_file({metadata['bucket']!r}, {metadata['object_key']!r}, "
        f"{container_path!r}, ExtraArgs={{'VersionId': {metadata['provider_version_id']!r}}})"
    )
    subprocess.run(
        ["docker", "exec", "idea2strategy-backtest-api", "python", "-c", program],
        check=True,
        capture_output=True,
        text=True,
    )
    subprocess.run(
        ["docker", "cp", f"idea2strategy-backtest-api:{container_path}", str(path)],
        check=True,
        capture_output=True,
        text=True,
    )


def _position_values() -> dict[str, str]:
    if _sha256(CORPUS) != CORPUS_SHA256:
        raise AssertionError("canonical derived-input fixture hash changed")
    fixture = json.loads(CORPUS.read_text(encoding="utf-8"))
    true_inputs = {case["operation"]: case["trueInputs"] for case in fixture["cases"]}
    drawdown = true_inputs["DRAWDOWN_FROM_PEAK"]
    drawdown_percent = (
        (Decimal(str(drawdown["peakPrice"])) - Decimal(str(drawdown["currentPrice"])))
        / Decimal(str(drawdown["peakPrice"]))
        * Decimal(100)
    )
    return {
        "position.returnPercent": str(
            true_inputs["POSITION_RETURN"]["positionReturnPercent"]
        ),
        "position.holdingTradingDays": str(true_inputs["HOLDING_PERIOD"]["heldBars"]),
        "position.peakReturnPercent": str(
            true_inputs["PEAK_RETURN"]["peakReturnPercent"]
        ),
        "position.drawdownPercent": str(drawdown_percent),
    }


@lru_cache(maxsize=1)
def load_stored_market_snapshot() -> StoredMarketSnapshot:
    metadata = _load_manifest_metadata()
    path = (
        Path(tempfile.gettempdir()) / "release-proof-task3-local-market-object.parquet"
    )
    if not path.is_file() or _sha256(path) != OBJECT_SHA256:
        _fetch_object(path, metadata)
    if path.stat().st_size != metadata["byte_size"]:
        raise AssertionError(
            f"stored market object byte_size mismatch: {path.stat().st_size}"
        )
    actual_hash = _sha256(path)
    if actual_hash != metadata["content_hash"]:
        raise AssertionError(f"stored market object hash mismatch: {actual_hash}")

    table = pq.read_table(
        path, columns=["instrument_id", "bar_start_at", "close", "volume"]
    )
    if (
        table.num_rows != metadata["object_row_count"]
        or table.num_rows != metadata["dataset_row_count"]
    ):
        raise AssertionError(
            f"stored market object row_count mismatch: {table.num_rows}"
        )
    rows = table.to_pylist()
    selected = [row for row in rows if row["bar_start_at"] < AS_OF]
    if not selected or {row["instrument_id"] for row in selected} != {INSTRUMENT_ID}:
        raise AssertionError(
            "stored object does not contain the pinned instrument history"
        )
    events = tuple(
        bar_closed_event(
            event_id=f"{MANIFEST_ID}:{index}",
            instrument_id=row["instrument_id"],
            data_kind="ADJUSTED_BAR",
            resolution="30m",
            starts_at=row["bar_start_at"],
            close=Decimal(str(row["close"])),
            volume=Decimal(str(row["volume"])),
            source_sequence=index,
        )
        for index, row in enumerate(selected, start=1)
    )
    inputs = _instrument_inputs(
        events,
        AS_OF,
        runtime_values={INSTRUMENT_ID: _position_values()},
    )
    return StoredMarketSnapshot(
        path=path,
        object_sha256=actual_hash,
        corpus_sha256=CORPUS_SHA256,
        as_of=AS_OF,
        inputs=inputs,
        event_ids=tuple(event.event_id for event in events),
        manifest_id=str(metadata["manifest_id"]),
        dataset_sha256=str(metadata["dataset_hash"]),
        object_key=str(metadata["object_key"]),
        object_version_id=str(metadata["provider_version_id"]),
        byte_size=int(metadata["byte_size"]),
        row_count=int(metadata["object_row_count"]),
    )
