from __future__ import annotations

import argparse
import json
import os
import sys
import uuid
from collections.abc import Mapping, Sequence
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any

import psycopg

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(
    0,
    os.environ.get("BACKTEST_ENGINE_SRC", str(ROOT / "backtest-engine" / "src")),
)

from backtest_engine.legacy_market_data import legacy_dataset_hash

COMPOSITE_MANIFEST_ID = str(
    uuid.uuid5(uuid.NAMESPACE_URL, "idea2strategy.local/market-data/adjusted/30m/2016-2026")
)
PERIOD_START = "2016-01-01T00:00:00Z"
PERIOD_END = "2026-07-30T00:00:00Z"
EXPECTED_SOURCE_PERIODS = tuple(
    [(date(year, 1, 1), date(year + 1, 1, 1)) for year in range(2016, 2026)]
    + [(date(2026, 1, 1), date(2026, 7, 30))]
)


def _text(value: object) -> str:
    if isinstance(value, datetime):
        return value.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    if isinstance(value, date):
        return value.isoformat()
    return str(value)


def build_composite_manifest(
    rows: Sequence[Mapping[str, object]],
    *,
    period_start: str = PERIOD_START,
    period_end: str = PERIOD_END,
) -> dict[str, Any]:
    if not rows:
        raise ValueError("full-range manifest requires source objects")
    objects = []
    for row in rows:
        content_hash = _text(row["content_hash"]).removeprefix("sha256:")
        objects.append(
            {
                "storage_object_id": _text(row["storage_object_id"]),
                "object_key": _text(row["object_key"]),
                "content_hash": content_hash,
                "object_kind": "MARKET_BARS",
                "partition_granularity": "YEAR",
                "partition_start": _text(row["partition_start"]),
                "partition_end": _text(row["partition_end"]),
                "period_start": _text(row["period_start"]),
                "period_end": _text(row["period_end"]),
                "shard_key": _text(row["shard_key"]),
                "part_number": int(row["part_number"]),
                "row_count": int(row["row_count"]),
                "schema_version": _text(row["schema_version"]),
            }
        )
    objects.sort(key=lambda item: (item["partition_start"], item["shard_key"], item["part_number"]))
    manifest: dict[str, Any] = {
        "contract_id": "com06.dataset-manifest",
        "schema_version": 1,
        "manifest_id": COMPOSITE_MANIFEST_ID,
        "dataset_id": COMPOSITE_MANIFEST_ID,
        "revision": 1,
        "status": "AVAILABLE",
        "dataset_hash": "",
        "schema_id": "market-bars/1",
        "provider_code": "ALPACA",
        "feed_code": "ALPACA_SIP_ALL_30M",
        "data_layer": "ADJUSTED",
        "resolution": "30m",
        "period_start": period_start,
        "period_end": period_end,
        "available_at": "2026-08-25T00:00:00Z",
        "composite": True,
        "objects": objects,
    }
    manifest["dataset_hash"] = legacy_dataset_hash(manifest)
    return manifest


def _database_url() -> str:
    value = os.environ.get("LOCAL_FEATURE_DATABASE_URL") or os.environ.get("DATABASE_URL")
    if not value:
        raise RuntimeError("LOCAL_FEATURE_DATABASE_URL or DATABASE_URL is required")
    return value.replace("postgresql+psycopg://", "postgresql://", 1)


def register(connection: psycopg.Connection[Any]) -> dict[str, Any]:
    rows = connection.execute(
        """
        select m.id as source_manifest_id, d.id as source_relation_id,
               d.object_id as storage_object_id, o.object_key, o.content_hash,
               d.row_count, d.partition_start, d.partition_end,
               d.period_start, d.period_end, d.shard_key, d.part_number,
               o.schema_version, m.feed_id
          from market_data.dataset_manifests m
          join market_data.feeds f on f.id = m.feed_id
          join market_data.dataset_objects d on d.dataset_manifest_id = m.id
          join storage.objects o on o.id = d.object_id
         where f.code = 'ALPACA_SIP_ALL_30M'
           and m.status = 'AVAILABLE'
           and (m.period_start::date, m.period_end::date) in (
               select starts_at, ends_at from unnest(%s::date[], %s::date[]) periods(starts_at, ends_at)
           )
         order by d.partition_start, d.shard_key, d.part_number
        """,
        ([item[0] for item in EXPECTED_SOURCE_PERIODS], [item[1] for item in EXPECTED_SOURCE_PERIODS]),
    ).fetchall()
    mappings = [dict(row) if isinstance(row, Mapping) else {} for row in rows]
    if not mappings:
        raise RuntimeError("no full-range adjusted 30m source objects were found")
    manifest = build_composite_manifest(mappings)
    source_periods = {
        (date.fromisoformat(item["partition_start"]), date.fromisoformat(item["partition_end"]))
        for item in manifest["objects"]
    }
    if source_periods != set(EXPECTED_SOURCE_PERIODS):
        raise RuntimeError("adjusted 30m sources do not cover every required partition")
    source_ids = sorted({_text(row["source_manifest_id"]) for row in mappings})
    feed_ids = {_text(row["feed_id"]) for row in mappings}
    if len(source_ids) != 11 or len(feed_ids) != 1 or len(mappings) != 88:
        raise RuntimeError("full-range adjusted 30m input must be 11 manifests and 88 objects")
    feed_id = next(iter(feed_ids))

    with connection.transaction():
        connection.execute(
            """
            insert into market_data.dataset_manifests
              (id,feed_id,instrument_id,data_layer,resolution,revision_number,status,
               period_start,period_end,schema_version,dataset_hash,created_at,available_at,object_count)
            values (%s,%s,null,'ADJUSTED','30m',1,'AVAILABLE',%s,%s,'market-bars/1',%s,%s,%s,%s)
            on conflict (id) do nothing
            """,
            (
                COMPOSITE_MANIFEST_ID,
                feed_id,
                PERIOD_START,
                PERIOD_END,
                manifest["dataset_hash"],
                manifest["available_at"],
                manifest["available_at"],
                len(mappings),
            ),
        )
        for row in mappings:
            relation_id = str(uuid.uuid5(uuid.UUID(COMPOSITE_MANIFEST_ID), _text(row["source_relation_id"])))
            connection.execute(
                """
                insert into market_data.dataset_objects
                  (id,dataset_manifest_id,object_id,object_kind,partition_granularity,
                   partition_start,partition_end,period_start,period_end,shard_key,
                   part_number,row_count,min_instrument_id,max_instrument_id)
                values (%s,%s,%s,'MARKET_BARS','YEAR',%s,%s,%s,%s,%s,%s,%s,null,null)
                on conflict (id) do nothing
                """,
                (
                    relation_id,
                    COMPOSITE_MANIFEST_ID,
                    row["storage_object_id"],
                    row["partition_start"],
                    row["partition_end"],
                    row["period_start"],
                    row["period_end"],
                    row["shard_key"],
                    row["part_number"],
                    row["row_count"],
                ),
            )
        for source_id in source_ids:
            connection.execute(
                """
                insert into market_data.dataset_lineage
                  (derived_manifest_id,source_manifest_id,relation_type)
                values (%s,%s,'COMPOSED_FROM') on conflict do nothing
                """,
                (COMPOSITE_MANIFEST_ID, source_id),
            )
        evidence = connection.execute(
            """
            select m.dataset_hash, count(d.id) as object_count
              from market_data.dataset_manifests m
              join market_data.dataset_objects d on d.dataset_manifest_id=m.id
             where m.id=%s group by m.dataset_hash
            """,
            (COMPOSITE_MANIFEST_ID,),
        ).fetchone()
        if (
            evidence is None
            or evidence["dataset_hash"] != manifest["dataset_hash"]
            or evidence["object_count"] != 88
        ):
            raise RuntimeError("registered full-range manifest does not match computed evidence")
    instrument_evidence = connection.execute(
        "select count(*) as instrument_count from market_data.instruments"
    ).fetchone()
    if instrument_evidence is None:
        raise RuntimeError("instrument catalog count is unavailable")
    return {
        "status": "registered",
        "manifest_id": COMPOSITE_MANIFEST_ID,
        "dataset_hash": manifest["dataset_hash"],
        "object_count": 88,
        "row_count": sum(int(row["row_count"]) for row in mappings),
        "instrument_count": int(instrument_evidence["instrument_count"]),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.parse_args()
    with psycopg.connect(_database_url(), row_factory=psycopg.rows.dict_row) as connection:
        print(json.dumps(register(connection), sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
