#!/usr/bin/env python3
"""One-command immutable backup, canonical DB, MinIO, and Parquet audit."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from typing import Any

import boto3
import pyarrow.parquet as pq
from sqlalchemy import create_engine, text


def load_migration_module() -> Any:
    path = Path(__file__).with_name("migrate-legacy-market-data.py")
    spec = importlib.util.spec_from_file_location("i2s_legacy_migration", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load verifier dependency: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def query(url: str, statement: str) -> list[tuple[Any, ...]]:
    engine = create_engine(url)
    try:
        with engine.connect() as connection:
            connection.execute(text("SET TRANSACTION READ ONLY"))
            return [tuple(row) for row in connection.execute(text(statement)).all()]
    finally:
        engine.dispose()


def normalise(rows: list[tuple[Any, ...]]) -> set[tuple[str, ...]]:
    return {tuple("" if value is None else str(value) for value in row) for row in rows}


def require_equal(label: str, left: set[tuple[str, ...]], right: set[tuple[str, ...]]) -> None:
    if left != right:
        raise RuntimeError(
            f"{label} differs: source_only={len(left - right)}, target_only={len(right - left)}"
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--backup", type=Path, required=True)
    parser.add_argument("--legacy-database-url", default=os.environ.get("LEGACY_DATABASE_URL"))
    parser.add_argument("--canonical-database-url", default=os.environ.get("CANONICAL_DATABASE_URL"))
    parser.add_argument("--minio-endpoint", default=os.environ.get("MINIO_ENDPOINT"))
    parser.add_argument("--minio-access-key", default=os.environ.get("MINIO_ACCESS_KEY"))
    parser.add_argument("--minio-secret-key", default=os.environ.get("MINIO_SECRET_KEY"))
    parser.add_argument("--minio-receipt", type=Path)
    parser.add_argument("--region", default="ap-northeast-2")
    args = parser.parse_args()
    if not all((args.legacy_database_url, args.canonical_database_url, args.minio_endpoint, args.minio_access_key, args.minio_secret_key)):
        parser.error("database and MinIO connection variables are required")
    backup = args.backup.expanduser().resolve()
    migration = load_migration_module()
    manifest_bytes = (backup / "backup-manifest.json").read_bytes()
    manifest = json.loads(manifest_bytes.decode("utf-8-sig"))
    receipt_path = args.minio_receipt.expanduser().resolve() if args.minio_receipt else backup / "local-minio-import-receipt.json"
    raw = migration.verify_raw_backup(backup, minio_receipt=receipt_path)
    print(f"[verify] raw backup: {raw['s3']['versions']} versions", flush=True)
    mapping = json.loads(receipt_path.read_text(encoding="utf-8-sig"))

    source_storage = query(
        args.legacy_database_url,
        "SELECT id, object_key, provider_version_id, content_sha256, byte_size "
        "FROM storage.objects ORDER BY id",
    )
    target_storage = query(
        args.canonical_database_url,
        "SELECT id, object_key, provider_version_id, content_hash, byte_size, bucket_name "
        "FROM storage.objects ORDER BY id",
    )
    version_map = {
        (str(event["key"]), str(event["source_version_id"])): str(event["target_version_id"])
        for event in mapping["events"]
        if str(event["kind"]).replace("-", "_") == "version"
    }
    expected_storage = set()
    for row in source_storage:
        object_id, object_key, source_version, content_hash, byte_size = map(str, row)
        target_version = version_map.get((object_key, source_version))
        if target_version is None:
            raise RuntimeError(f"logical UUID {object_id} has no MinIO VersionId mapping")
        expected_storage.add(
            (object_id, object_key, target_version, content_hash, byte_size, str(mapping["target_bucket"]))
        )
    require_equal("logical UUID / S3 object key / SHA-256", expected_storage, normalise(target_storage))
    print(f"[verify] storage catalog: {len(source_storage)} logical objects", flush=True)

    require_equal(
        "manifest UUID/hash",
        normalise(query(args.legacy_database_url, "SELECT id, feed_id, instrument_id, manifest_hash FROM market_data.dataset_manifests")),
        normalise(query(args.canonical_database_url, "SELECT id, feed_id, instrument_id, dataset_hash FROM market_data.dataset_manifests")),
    )
    require_equal(
        "manifest/object relation",
        normalise(query(args.legacy_database_url, "SELECT id, dataset_manifest_id, object_id, row_count FROM market_data.dataset_objects")),
        normalise(query(args.canonical_database_url, "SELECT id, dataset_manifest_id, object_id, row_count FROM market_data.dataset_objects")),
    )
    require_equal(
        "lineage",
        normalise(query(args.legacy_database_url, "SELECT dataset_manifest_id, source_manifest_id, relationship_type FROM market_data.dataset_lineage")),
        normalise(query(args.canonical_database_url, "SELECT derived_manifest_id, source_manifest_id, relation_type FROM market_data.dataset_lineage")),
    )
    orphan_counts = query(
        args.canonical_database_url,
        """
        SELECT
          (SELECT count(*) FROM market_data.dataset_objects d LEFT JOIN market_data.dataset_manifests m ON m.id=d.dataset_manifest_id WHERE m.id IS NULL),
          (SELECT count(*) FROM market_data.dataset_objects d LEFT JOIN storage.objects o ON o.id=d.object_id WHERE o.id IS NULL),
          (SELECT count(*) FROM market_data.dataset_lineage l LEFT JOIN market_data.dataset_manifests m ON m.id=l.derived_manifest_id WHERE m.id IS NULL),
          (SELECT count(*) FROM market_data.dataset_lineage l LEFT JOIN market_data.dataset_manifests m ON m.id=l.source_manifest_id WHERE m.id IS NULL)
        """,
    )[0]
    if any(int(value) for value in orphan_counts):
        raise RuntimeError(f"canonical manifest/object/lineage has orphans: {orphan_counts}")
    print("[verify] manifest/object/lineage relations: valid", flush=True)

    client = boto3.client(
        "s3",
        endpoint_url=args.minio_endpoint,
        aws_access_key_id=args.minio_access_key,
        aws_secret_access_key=args.minio_secret_key,
        region_name=args.region,
    )
    live_versions: set[tuple[str, str, str]] = set()
    paginator = client.get_paginator("list_object_versions")
    for page in paginator.paginate(Bucket=str(mapping["target_bucket"])):
        live_versions.update(("version", str(item["Key"]), str(item["VersionId"])) for item in page.get("Versions", []))
        live_versions.update(("delete_marker", str(item["Key"]), str(item["VersionId"])) for item in page.get("DeleteMarkers", []))
    expected_versions = {
        (str(event["kind"]).replace("-", "_"), str(event["key"]), str(event["target_version_id"]))
        for event in mapping["events"]
    }
    require_equal("live MinIO VersionId mapping", expected_versions, live_versions)
    print(f"[verify] MinIO live mapping: {len(live_versions)} events", flush=True)

    current_receipts = json.loads(
        (backup / str(manifest["s3"]["current_receipts_file"])).read_text(encoding="utf-8-sig")
    )
    parquet_receipts = [item for item in current_receipts if str(item["key"]).lower().endswith(".parquet")]
    def read_parquet(receipt: dict[str, Any]) -> None:
        payload = (backup / str(receipt["file"])).resolve()
        if backup not in payload.parents:
            raise RuntimeError(f"Parquet path escapes backup: {receipt['file']}")
        pq.ParquetFile(payload).metadata

    with ThreadPoolExecutor(max_workers=16) as executor:
        for index, _ in enumerate(executor.map(read_parquet, parquet_receipts), start=1):
            if index % 2000 == 0:
                print(f"[verify] Parquet readable: {index}/{len(parquet_receipts)}", flush=True)

    report = {
        "status": "VERIFIED",
        "backup_version": {
            "created_at_utc": manifest["created_at_utc"],
            "manifest_sha256": hashlib.sha256(manifest_bytes).hexdigest(),
            "database_dump_sha256": manifest["database"]["sha256"],
        },
        "database": {
            "logical_storage_objects": len(source_storage),
            "dataset_manifests": len(query(args.canonical_database_url, "SELECT id FROM market_data.dataset_manifests")),
            "dataset_objects": len(query(args.canonical_database_url, "SELECT id FROM market_data.dataset_objects")),
            "lineage": len(query(args.canonical_database_url, "SELECT * FROM market_data.dataset_lineage")),
            "orphans": list(map(int, orphan_counts)),
        },
        "backup": raw,
        "minio": {"mapped_events": len(expected_versions), "live_events": len(live_versions)},
        "parquet_readable": len(parquet_receipts),
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
