"""Seed deterministic, versioned local inputs for the real Basic strategy journey."""

from __future__ import annotations

import hashlib
import json
import os
import sys
import uuid
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal
from pathlib import Path

import boto3
import psycopg
import pyarrow as pa
import pyarrow.parquet as pq


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "backtest-engine" / "src"))

from backtest_engine.feature_outputs import FEATURE_SERIES_SCHEMA  # noqa: E402
from backtest_engine.legacy_market_data import legacy_dataset_hash  # noqa: E402


ALPACA_PROVIDER_ID = uuid.UUID("51000000-0000-4000-8000-000000000001")
MARKET_FEED_ID = uuid.UUID("51000000-0000-4000-8000-000000000002")
MARKET_MANIFEST_ID = uuid.UUID("51000000-0000-4000-8000-000000000003")
MARKET_OBJECT_ID = uuid.UUID("51000000-0000-4000-8000-000000000004")
MARKET_RELATION_ID = uuid.UUID("51000000-0000-4000-8000-000000000005")
RSI_DEFINITION_ID = uuid.UUID("4b1c6801-0259-5176-a857-0e5ea923d898")
RSI_DEFINITION_HASH = "363f534dc77c6af0ebfe58f35be4fd2aa208906b1eaa36b550b17e9acb8692e4"
RSI_FEED_ID = uuid.UUID("57794d8c-2254-53e4-966e-44f97edd9e6a")
INPUT_HASH = "2" * 64
PERIOD_START = datetime(2023, 12, 31, 17, tzinfo=UTC)
PERIOD_END = datetime(2024, 2, 2, tzinfo=UTC)
VISIBLE_AT = datetime(2026, 8, 1, tzinfo=UTC)
INSTRUMENTS = (
    (uuid.UUID("52000000-0000-4000-8000-000000000001"), uuid.UUID("53000000-0000-4000-8000-000000000001"), "AAPL", "STOCK"),
    (uuid.UUID("52000000-0000-4000-8000-000000000002"), uuid.UUID("53000000-0000-4000-8000-000000000002"), "MSFT", "STOCK"),
    (uuid.UUID("52000000-0000-4000-8000-000000000003"), uuid.UUID("53000000-0000-4000-8000-000000000003"), "SPY", "ETF"),
)


def _market_rows() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    sessions = (date(2024, 1, 2), date(2024, 1, 3), date(2024, 1, 4), date(2024, 1, 5))
    for instrument_index, (instrument_id, _symbol_id, symbol, _asset_type) in enumerate(INSTRUMENTS):
        previous = Decimal(100 + instrument_index * 25)
        for session in sessions:
            opening = datetime.combine(session, datetime.min.time(), UTC) + timedelta(hours=14, minutes=30)
            for bar_index in range(13):
                at = opening + timedelta(minutes=30 * bar_index)
                close = previous + Decimal("0.75")
                rows.append({
                    "instrument_id": str(instrument_id), "provider_symbol": symbol,
                    "bar_start_at": at, "session_date_et": session,
                    "open": float(previous), "high": float(close + Decimal("0.25")),
                    "low": float(previous - Decimal("0.25")), "close": float(close),
                    "volume": 10_000 + bar_index * 100,
                })
                previous = close
    return sorted(rows, key=lambda row: (str(row["instrument_id"]), row["bar_start_at"]))


def _parquet(schema: pa.Schema, rows: list[dict[str, object]]) -> bytes:
    sink = pa.BufferOutputStream()
    pq.write_table(
        pa.Table.from_pylist(rows, schema=schema), sink, compression="zstd",
        use_dictionary=False, write_statistics=True, version="2.6",
    )
    return sink.getvalue().to_pybytes()


def _market_bytes() -> tuple[bytes, list[dict[str, object]]]:
    schema = pa.schema([
        pa.field("instrument_id", pa.string(), nullable=False),
        pa.field("provider_symbol", pa.string(), nullable=False),
        pa.field("bar_start_at", pa.timestamp("us", tz="UTC"), nullable=False),
        pa.field("session_date_et", pa.date32(), nullable=False),
        pa.field("open", pa.float64(), nullable=False), pa.field("high", pa.float64(), nullable=False),
        pa.field("low", pa.float64(), nullable=False), pa.field("close", pa.float64(), nullable=False),
        pa.field("volume", pa.int64(), nullable=False),
    ], metadata={b"schema_version": b"market-bars/1", b"processing_version": b"market-loader/1.0.0"})
    rows = _market_rows()
    return _parquet(schema, rows), rows


def _feature_rows(instrument_id: uuid.UUID) -> list[dict[str, str]]:
    bars = [row for row in _market_rows() if row["instrument_id"] == str(instrument_id)]
    return [{"at": row["bar_start_at"].isoformat().replace("+00:00", "Z"),
             "value": f"{20 + (index % 30):.8f}"} for index, row in enumerate(bars)]


def _feature_bytes(rows: list[dict[str, str]]) -> bytes:
    table = pa.Table.from_arrays([
        pa.array([datetime.fromisoformat(row["at"].replace("Z", "+00:00")) for row in rows], type=FEATURE_SERIES_SCHEMA.field(0).type),
        pa.array([Decimal(row["value"]) for row in rows], type=FEATURE_SERIES_SCHEMA.field(1).type),
    ], schema=FEATURE_SERIES_SCHEMA)
    sink = pa.BufferOutputStream()
    pq.write_table(table, sink, compression="zstd", use_dictionary=False, write_statistics=False)
    return sink.getvalue().to_pybytes()


def _feature_result_hash(instrument_id: uuid.UUID, rows: list[dict[str, str]]) -> str:
    payload = {
        "definition_hash": RSI_DEFINITION_HASH, "input_dataset_set_hash": INPUT_HASH,
        "instrument_id": str(instrument_id), "period_start": PERIOD_START.isoformat().replace("+00:00", "Z"),
        "period_end": PERIOD_END.isoformat().replace("+00:00", "Z"), "result_schema_version": 1, "rows": rows,
    }
    return hashlib.sha256(json.dumps(payload, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode()).hexdigest()


def _put_versioned(client: object, bucket: str, key: str, body: bytes) -> str:
    digest = hashlib.sha256(body).hexdigest()
    try:
        current = client.head_object(Bucket=bucket, Key=key)
        if current.get("Metadata", {}).get("sha256") == digest and current.get("VersionId"):
            return str(current["VersionId"])
    except client.exceptions.ClientError as error:
        if error.response.get("ResponseMetadata", {}).get("HTTPStatusCode") != 404:
            raise
    written = client.put_object(
        Bucket=bucket, Key=key, Body=body, Metadata={"sha256": digest}, ServerSideEncryption="AES256",
    )
    return str(written["VersionId"])


def _seed_reference_rows(connection: psycopg.Connection) -> None:
    connection.execute("""
        insert into market_data.providers (id,code,display_name,rights_version,status,created_at)
        values (%s,'ALPACA','Alpaca local fixture','local-fixture-v1','ACTIVE',%s)
        on conflict (id) do nothing
        """, (ALPACA_PROVIDER_ID, VISIBLE_AT))
    connection.execute("""
        insert into market_data.feeds (id,provider_id,code,data_kind,resolution,timezone_name,feed_version,created_at)
        values (%s,%s,'ALPACA_SIP_ALL_30M','BARS','30m','America/New_York','market-loader-1.0.0',%s)
        on conflict (id) do nothing
        """, (MARKET_FEED_ID, ALPACA_PROVIDER_ID, VISIBLE_AT))
    for instrument_id, symbol_id, symbol, asset_type in INSTRUMENTS:
        connection.execute("""
            insert into market_data.instruments
            (id,asset_type,primary_exchange_mic,currency_code,provider_reference,listed_at,created_at)
            values (%s,%s::market_data.asset_type,'XNAS','USD',%s,'2000-01-01',%s)
            on conflict (id) do nothing
            """, (instrument_id, asset_type, f"local-{symbol}", VISIBLE_AT))
        connection.execute("""
            insert into market_data.instrument_symbols
            (id,instrument_id,exchange_mic,symbol,effective_from)
            values (%s,%s,'XNAS',%s,'2000-01-01T00:00:00Z') on conflict (id) do nothing
            """, (symbol_id, instrument_id, symbol))


def _seed_market(connection: psycopg.Connection, client: object, bucket: str) -> str:
    body, rows = _market_bytes()
    key = ("historical/provider=alpaca/feed=sip/adjustment=all/session=regular/resolution=30m/"
           f"revision=00000001/year=2024/shard=00-of-01/manifest_id={MARKET_MANIFEST_ID}/part-00001.parquet")
    version = _put_versioned(client, bucket, key, body)
    metadata = {
        "storage_object_id": str(MARKET_OBJECT_ID), "object_key": key,
        "content_hash": hashlib.sha256(body).hexdigest(), "object_kind": "MARKET_BARS",
        "partition_granularity": "YEAR", "partition_start": "2024-01-01", "partition_end": "2024-02-01",
        "period_start": "2024-01-01T00:00:00Z", "period_end": "2024-02-01T00:00:00Z",
        "shard_key": "s00-of-1", "part_number": 1, "row_count": len(rows), "schema_version": "market-bars/1",
    }
    manifest = {
        "contract_id": "com06.dataset-manifest", "schema_version": 1,
        "manifest_id": str(MARKET_MANIFEST_ID), "dataset_id": str(MARKET_MANIFEST_ID),
        "revision": 1, "status": "AVAILABLE", "dataset_hash": "", "schema_id": "market-bars/1",
        "provider_code": "ALPACA", "feed_code": "ALPACA_SIP_ALL_30M", "data_layer": "ADJUSTED",
        "resolution": "30m", "period_start": "2024-01-01T00:00:00Z", "period_end": "2024-02-01T00:00:00Z",
        "available_at": VISIBLE_AT.isoformat().replace("+00:00", "Z"), "objects": [metadata],
    }
    manifest["dataset_hash"] = legacy_dataset_hash(manifest)
    digest = hashlib.sha256(body).hexdigest()
    connection.execute("""
        insert into storage.objects
        (id,status,storage_provider,bucket_name,object_key,provider_version_id,content_hash,byte_size,file_format,
         compression_codec,media_type,schema_version,row_count,period_start,period_end,retention_policy_version,
         legal_hold,created_at,verified_at)
        values (%s,'AVAILABLE','S3',%s,%s,%s,%s,%s,'PARQUET','ZSTD','application/vnd.apache.parquet',
                'market-bars/1',%s,'2024-01-01T00:00:00Z','2024-02-01T00:00:00Z','local-fixture-v1',false,%s,%s)
        on conflict (id) do update set provider_version_id=excluded.provider_version_id,
          content_hash=excluded.content_hash, byte_size=excluded.byte_size, verified_at=excluded.verified_at
        """, (MARKET_OBJECT_ID, bucket, key, version, digest, len(body), len(rows), VISIBLE_AT, VISIBLE_AT))
    connection.execute("""
        insert into market_data.dataset_manifests
        (id,feed_id,data_layer,resolution,revision_number,status,period_start,period_end,schema_version,dataset_hash,created_at,available_at)
        values (%s,%s,'ADJUSTED','30m',1,'AVAILABLE','2024-01-01T00:00:00Z','2024-02-01T00:00:00Z',
                'market-bars/1',%s,%s,%s) on conflict (id) do nothing
        """, (MARKET_MANIFEST_ID, MARKET_FEED_ID, manifest["dataset_hash"], VISIBLE_AT, VISIBLE_AT))
    connection.execute("""
        insert into market_data.dataset_objects
        (id,dataset_manifest_id,object_id,object_kind,partition_granularity,partition_start,partition_end,
         period_start,period_end,shard_key,part_number,row_count)
        values (%s,%s,%s,'MARKET_BARS','YEAR','2024-01-01','2024-02-01','2024-01-01T00:00:00Z',
                '2024-02-01T00:00:00Z','s00-of-1',1,%s) on conflict (id) do nothing
        """, (MARKET_RELATION_ID, MARKET_MANIFEST_ID, MARKET_OBJECT_ID, len(rows)))
    return str(manifest["dataset_hash"])


def _derived_id(kind: str, instrument_id: uuid.UUID) -> uuid.UUID:
    return uuid.uuid5(uuid.UUID("05a27d5a-75d8-4d57-bc9a-31cedf90d791"), f"local-basic-e2e|{kind}|{instrument_id}")


def _seed_feature(connection: psycopg.Connection, client: object, bucket: str, instrument_id: uuid.UUID) -> None:
    rows = _feature_rows(instrument_id)
    body = _feature_bytes(rows)
    result_hash = _feature_result_hash(instrument_id, rows)
    object_id = _derived_id("feature-object", instrument_id)
    manifest_id = _derived_id("feature-manifest", instrument_id)
    relation_id = _derived_id("feature-relation", instrument_id)
    pipeline_id = _derived_id("feature-pipeline", instrument_id)
    materialization_id = _derived_id("feature-materialization", instrument_id)
    key = f"feature-output/local-basic-e2e/instrument={instrument_id}/rsi-14-30m.parquet"
    version = _put_versioned(client, bucket, key, body)
    content_hash = hashlib.sha256(body).hexdigest()
    dataset_hash = hashlib.sha256(f"{instrument_id}|{content_hash}".encode()).hexdigest()
    connection.execute("""
        insert into storage.objects
        (id,status,storage_provider,bucket_name,object_key,provider_version_id,content_hash,byte_size,file_format,
         compression_codec,media_type,schema_version,row_count,period_start,period_end,retention_policy_version,
         legal_hold,created_at,verified_at)
        values (%s,'AVAILABLE','S3_COMPATIBLE',%s,%s,%s,%s,%s,'PARQUET','ZSTD','application/vnd.apache.parquet',
                'feature-series.parquet.v1',%s,%s,%s,'local-fixture-v1',false,%s,%s)
        on conflict (id) do update set provider_version_id=excluded.provider_version_id,
          content_hash=excluded.content_hash, byte_size=excluded.byte_size, verified_at=excluded.verified_at
        """, (object_id, bucket, key, version, content_hash, len(body), len(rows), PERIOD_START, PERIOD_END, VISIBLE_AT, VISIBLE_AT))
    connection.execute("""
        insert into market_data.dataset_manifests
        (id,feed_id,instrument_id,data_layer,resolution,revision_number,status,period_start,period_end,schema_version,
         dataset_hash,created_at,available_at)
        values (%s,%s,%s,'DERIVED','30m',1,'AVAILABLE',%s,%s,'feature-series.parquet.v1',%s,%s,%s)
        on conflict (id) do nothing
        """, (manifest_id, RSI_FEED_ID, instrument_id, PERIOD_START, PERIOD_END, dataset_hash, VISIBLE_AT, VISIBLE_AT))
    connection.execute("""
        insert into market_data.dataset_objects
        (id,dataset_manifest_id,object_id,object_kind,partition_granularity,partition_start,partition_end,
         period_start,period_end,shard_key,part_number,row_count,min_instrument_id,max_instrument_id)
        values (%s,%s,%s,'FEATURE_SERIES','YEAR','2023-12-31','2024-02-02',%s,%s,'s00-of-1',1,%s,%s,%s)
        on conflict (id) do nothing
        """, (relation_id, manifest_id, object_id, PERIOD_START, PERIOD_END, len(rows), instrument_id, instrument_id))
    connection.execute("""
        insert into market_data.pipeline_runs
        (id,pipeline_code,pipeline_version,idempotency_key,status,input_hash,output_hash,started_at,completed_at)
        values (%s,'MATERIALIZE_FEATURE_OUTPUT','feature-series.parquet.v1',%s,'SUCCEEDED',%s,%s,%s,%s)
        on conflict (id) do nothing
        """, (pipeline_id, f"local-basic-e2e:{instrument_id}:rsi-30m", INPUT_HASH, result_hash, VISIBLE_AT, VISIBLE_AT))
    connection.execute("""
        insert into market_data.feature_materializations
        (id,feature_definition_id,instrument_id,pipeline_run_id,input_dataset_set_hash,period_start,period_end,
         source_watermark,output_dataset_manifest_id,result_hash,status,available_at,created_at)
        values (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,'SUCCEEDED',%s,%s) on conflict (id) do nothing
        """, (materialization_id, RSI_DEFINITION_ID, instrument_id, pipeline_id, INPUT_HASH,
                PERIOD_START, PERIOD_END, MARKET_MANIFEST_ID.hex, manifest_id, result_hash, VISIBLE_AT, VISIBLE_AT))


def main() -> None:
    database_url = os.environ["LOCAL_SEED_DATABASE_URL"]
    bucket = os.environ["LOCAL_SEED_S3_BUCKET"]
    client = boto3.client("s3", endpoint_url=os.environ["LOCAL_SEED_S3_ENDPOINT"], region_name=os.environ.get("AWS_REGION", "ap-northeast-2"))
    with psycopg.connect(database_url) as connection:
        _seed_reference_rows(connection)
        market_hash = _seed_market(connection, client, bucket)
        for instrument_id, _symbol_id, _symbol, _asset_type in INSTRUMENTS[:2]:
            _seed_feature(connection, client, bucket, instrument_id)
    print(json.dumps({"status": "prepared", "instruments": [row[2] for row in INSTRUMENTS],
                      "marketDatasetHash": market_hash, "featureMaterializations": 2}, sort_keys=True))


if __name__ == "__main__":
    main()
