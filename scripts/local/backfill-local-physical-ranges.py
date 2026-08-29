from __future__ import annotations

import hashlib
import json
import os
from collections import defaultdict

import boto3
import pyarrow as pa
import pyarrow.parquet as pq
from sqlalchemy import create_engine, text


def main() -> None:
    engine = create_engine(os.environ["LOCAL_HISTORY_DATABASE_URL"], future=True)
    client = boto3.client("s3", endpoint_url=os.environ["LOCAL_HISTORY_S3_ENDPOINT"])
    bucket = os.environ["LOCAL_HISTORY_S3_BUCKET"]
    with engine.connect() as connection:
        rows = connection.execute(text("""
            select m.id manifest_id, d.id relation_id, d.row_count,
                   o.object_key, o.provider_version_id, o.content_hash, o.byte_size
              from market_data.dataset_manifests m
              join market_data.dataset_objects d on d.dataset_manifest_id = m.id
              join storage.objects o on o.id = d.object_id
              join market_data.feeds f on f.id = m.feed_id
              left join market_data.instrument_symbols s on s.instrument_id = m.instrument_id
             where m.status = 'AVAILABLE'
               and (f.code like 'ALPACA_SIP_ALL_%'
                    or s.symbol in ('AAPL', 'MSFT', 'META', 'AMZN', 'NVDA', 'SPX', 'NDX'))
               and (m.actual_start_at is null or m.actual_end_at is null
                    or d.actual_start_at is null or d.actual_end_at is null)
             order by m.id, d.id
        """)).mappings().all()

    relation_bounds: dict[str, tuple[object, object]] = {}
    manifest_bounds: defaultdict[str, list[object]] = defaultdict(list)
    empty_objects = 0
    for row in rows:
        response = client.get_object(
            Bucket=bucket,
            Key=row["object_key"],
            VersionId=row["provider_version_id"],
        )
        payload = response["Body"].read()
        if len(payload) != int(row["byte_size"]):
            raise RuntimeError("catalog byte size differs from the stored object")
        if hashlib.sha256(payload).hexdigest() != str(row["content_hash"]):
            raise RuntimeError("catalog hash differs from the stored object")
        parquet = pq.ParquetFile(pa.BufferReader(payload))
        timestamp_column = next(
            (name for name in ("bar_start_at", "occurred_at", "event_time", "timestamp")
             if name in parquet.schema_arrow.names),
            None,
        )
        if timestamp_column is None:
            raise RuntimeError(f"{row['object_key']} has no supported physical timestamp column")
        table = parquet.read(columns=[timestamp_column])
        if table.num_rows != int(row["row_count"]):
            raise RuntimeError("catalog relation row count differs from the stored object")
        if table.num_rows == 0:
            empty_objects += 1
            continue
        values = table.column(timestamp_column).to_pylist()
        actual_start, actual_end = min(values), max(values)
        relation_bounds[str(row["relation_id"])] = (actual_start, actual_end)
        manifest_bounds[str(row["manifest_id"])].extend((actual_start, actual_end))

    with engine.begin() as connection:
        for relation_id, (actual_start, actual_end) in relation_bounds.items():
            connection.execute(text("""
                update market_data.dataset_objects
                   set actual_start_at = :actual_start, actual_end_at = :actual_end
                 where id = cast(:id as uuid)
            """), {"id": relation_id, "actual_start": actual_start, "actual_end": actual_end})
        for manifest_id, bounds in manifest_bounds.items():
            connection.execute(text("""
                update market_data.dataset_manifests
                   set actual_start_at = :actual_start, actual_end_at = :actual_end
                 where id = cast(:id as uuid)
            """), {"id": manifest_id, "actual_start": min(bounds), "actual_end": max(bounds)})
    engine.dispose()
    print(json.dumps({
        "status": "backfilled",
        "manifests": len(manifest_bounds),
        "objects": len(relation_bounds),
        "emptyObjects": empty_objects,
    }, separators=(",", ":"), sort_keys=True))


if __name__ == "__main__":
    main()
