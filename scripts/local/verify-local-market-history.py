from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from datetime import UTC, datetime
from decimal import Decimal
from pathlib import Path

import boto3
import pyarrow as pa
import pyarrow.parquet as pq
import redis
from sqlalchemy import create_engine, text

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, os.environ.get("DATA_PIPELINE_SRC", str(ROOT / "data-pipeline")))

from apps.pipeline_worker.sync_market_history import _scoped_manifest_covers
from market_pipeline_lib.catalog import PostgresCatalog, StorageObjectsPolicy
from market_pipeline_lib.storage import S3ObjectStore


def _number(value: object) -> int | float:
    number = float(value) if isinstance(value, Decimal) else value
    if isinstance(number, float) and number.is_integer():
        return int(number)
    if not isinstance(number, (int, float)):
        raise TypeError(f"OHLCV value is not numeric: {type(value).__name__}")
    return number


def _manifest_applies_to_instrument(
    manifest: dict[str, object],
    instrument_id: str,
) -> bool:
    scoped_instrument = manifest.get("instrument_id")
    return scoped_instrument is None or str(scoped_instrument) == instrument_id


def _read_instrument_rows(
    source_bytes: bytes,
    instrument_id: str,
) -> tuple[int, pa.Table]:
    total_rows = pq.ParquetFile(pa.BufferReader(source_bytes)).metadata.num_rows
    selected = pq.read_table(
        pa.BufferReader(source_bytes),
        columns=[
            "instrument_id", "bar_start_at", "open", "high", "low", "close", "volume",
        ],
        filters=[("instrument_id", "=", instrument_id)],
    )
    return total_rows, selected


def _shared_row_is_shadowed(
    manifest: dict[str, object],
    scoped_manifests: list[dict[str, object]],
    instrument_id: str,
    at: object,
) -> bool:
    return (
        manifest.get("instrument_id") is None
        and isinstance(at, datetime)
        and _scoped_manifest_covers(scoped_manifests, instrument_id, at)
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Compare a local Redis projection with its exact Parquet sources.")
    parser.add_argument("symbol")
    parser.add_argument("timeframe", choices=("30m", "1h", "4h", "1d"))
    parser.add_argument(
        "--backfill-physical-ranges",
        action="store_true",
        help="Persist hash-verified Parquet min/max timestamps into the catalog.",
    )
    parser.add_argument(
        "--full-history",
        action="store_true",
        help="Verify every available adjusted yearly manifest instead of the preview projection.",
    )
    args = parser.parse_args()

    catalog = PostgresCatalog.connect(
        os.environ["LOCAL_HISTORY_DATABASE_URL"],
        artifact_root=Path(os.environ["LOCAL_HISTORY_STATE_ROOT"]) / "verification-catalog",
        storage_objects=StorageObjectsPolicy.READ_ONLY,
    )
    store = S3ObjectStore(
        os.environ["LOCAL_HISTORY_S3_BUCKET"],
        client=boto3.client("s3", endpoint_url=os.environ["LOCAL_HISTORY_S3_ENDPOINT"]),
    )
    redis_client = redis.Redis.from_url(os.environ["LOCAL_HISTORY_REDIS_URI"], decode_responses=True)
    try:
        symbol_record = next(
            row for row in catalog.records("market_data.instrument_symbols")
            if str(row["symbol"]).upper() == args.symbol.upper() and row.get("effective_to") is None
        )
        instrument = next(
            row for row in catalog.records("market_data.instruments")
            if str(row["id"]) == str(symbol_record["instrument_id"])
        )
        key = f"{{i2s:market}}:history:bars:{instrument['id']}:{args.timeframe}"
        raw = redis_client.get(key)
        if not raw:
            raise RuntimeError(f"missing projection for {args.symbol} {args.timeframe}")
        projection = json.loads(raw)
        if args.full_history:
            feed_codes = {
                str(row["id"]): str(row["code"])
                for row in catalog.records("market_data.feeds")
            }
            expected_feed = f"ALPACA_SIP_ALL_{args.timeframe.upper()}"
            manifests = {
                str(row["id"]): row for row in catalog.records("market_data.dataset_manifests")
                if row["status"] == "AVAILABLE"
                and row["data_layer"] == "ADJUSTED"
                and row["resolution"] == args.timeframe
                and feed_codes.get(str(row["feed_id"])) == expected_feed
                and _manifest_applies_to_instrument(row, str(instrument["id"]))
            }
        else:
            manifests = {
                str(row["id"]): row for row in catalog.records("market_data.dataset_manifests")
                if str(row["id"]) in projection["manifestIds"]
            }
            if set(manifests) != set(projection["manifestIds"]):
                raise RuntimeError("projection references an unknown manifest")

        candidates: dict[str, tuple[tuple[int, int], dict[str, object]]] = {}
        scoped_manifests = [
            row for row in manifests.values() if row.get("instrument_id") is not None
        ]
        verified_hashes: set[str] = set()
        relation_bounds: dict[str, tuple[object, object]] = {}
        manifest_bounds: dict[str, list[object]] = {}
        for manifest_id, manifest in manifests.items():
            for relation in catalog.objects_for_manifest(manifest_id):
                storage = relation["storage"]
                content_hash = str(storage["content_hash"])
                if not args.full_history and content_hash not in projection["objectHashes"]:
                    continue
                verification = store.verify_version(
                    str(storage["object_key"]),
                    str(storage["provider_version_id"]),
                    content_hash,
                    int(storage["byte_size"]),
                )
                if not verification.ok:
                    raise RuntimeError(f"object verification failed: {verification.message}")
                verified_hashes.add(content_hash)
                with store.open_version(str(storage["object_key"]), str(storage["provider_version_id"])) as stream:
                    source_bytes = stream.read()
                    if hashlib.sha256(source_bytes).hexdigest() != content_hash:
                        raise RuntimeError("downloaded Parquet bytes do not match the catalog hash")
                    total_rows, table = _read_instrument_rows(
                        source_bytes,
                        str(instrument["id"]),
                    )
                if int(relation["row_count"]) != total_rows:
                    raise RuntimeError("catalog relation row count differs from verified Parquet")
                if table.num_rows == 0:
                    continue
                timestamps = table.column("bar_start_at").to_pylist()
                if args.backfill_physical_ranges:
                    all_timestamps = pq.read_table(
                        pa.BufferReader(source_bytes),
                        columns=["bar_start_at"],
                    ).column("bar_start_at").to_pylist()
                else:
                    all_timestamps = timestamps
                object_start, object_end = min(all_timestamps), max(all_timestamps)
                relation_bounds[str(relation["id"])] = (object_start, object_end)
                manifest_bounds.setdefault(manifest_id, []).extend((object_start, object_end))
                for row in table.to_pylist():
                    if str(row["instrument_id"]) != str(instrument["id"]):
                        continue
                    if _shared_row_is_shadowed(
                        manifest,
                        scoped_manifests,
                        str(instrument["id"]),
                        row["bar_start_at"],
                    ):
                        continue
                    timestamp = row["bar_start_at"].astimezone(UTC).isoformat().replace("+00:00", "Z")
                    priority = (
                        1 if str(manifest.get("instrument_id")) == str(instrument["id"]) else 0,
                        int(manifest["revision_number"]),
                    )
                    normalized = {
                        "t": timestamp,
                        "o": _number(row["open"]),
                        "h": _number(row["high"]),
                        "l": _number(row["low"]),
                        "c": _number(row["close"]),
                        "v": _number(row["volume"]),
                    }
                    current = candidates.get(timestamp)
                    if current is None or priority > current[0]:
                        candidates[timestamp] = (priority, normalized)

        all_expected = [candidates[at][1] for at in sorted(candidates)]
        expected = all_expected if args.full_history else all_expected[-int(projection["rowCount"]):]
        if not args.full_history and expected != projection["bars"]:
            for index, (source, cached) in enumerate(zip(expected, projection["bars"], strict=False)):
                if source != cached:
                    raise RuntimeError(f"OHLCV mismatch at row {index}: {source['t']}")
            raise RuntimeError("projection and Parquet row counts differ")
        if not args.full_history and verified_hashes != set(projection["objectHashes"]):
            raise RuntimeError("not every projected object hash was independently verified")
        if args.backfill_physical_ranges:
            engine = create_engine(os.environ["LOCAL_HISTORY_DATABASE_URL"], future=True)
            try:
                with engine.begin() as connection:
                    for relation_id, (actual_start, actual_end) in relation_bounds.items():
                        connection.execute(text("""
                            update market_data.dataset_objects
                               set actual_start_at = :actual_start,
                                   actual_end_at = :actual_end
                             where id = cast(:relation_id as uuid)
                        """), {
                            "relation_id": relation_id,
                            "actual_start": actual_start,
                            "actual_end": actual_end,
                        })
                    for manifest_id, bounds in manifest_bounds.items():
                        connection.execute(text("""
                            update market_data.dataset_manifests
                               set actual_start_at = :actual_start,
                                   actual_end_at = :actual_end
                             where id = cast(:manifest_id as uuid)
                        """), {
                            "manifest_id": manifest_id,
                            "actual_start": min(bounds),
                            "actual_end": max(bounds),
                        })
            finally:
                engine.dispose()
        print(json.dumps({
            "status": "verified",
            "symbol": args.symbol.upper(),
            "timeframe": args.timeframe,
            "rows": len(expected),
            "first": expected[0]["t"],
            "last": expected[-1]["t"],
            "lastOhlcv": {key: expected[-1][key] for key in ("o", "h", "l", "c", "v")},
            "manifestCount": len(manifests),
            "objectCount": len(verified_hashes),
            "physicalRangesBackfilled": args.backfill_physical_ranges,
            "fullHistory": args.full_history,
        }, sort_keys=True, separators=(",", ":")))
    finally:
        redis_client.close()
        catalog.close()


if __name__ == "__main__":
    main()
