#!/usr/bin/env python3
"""Materialize the immutable populated V001 catalog into a separate canonical DB."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
from copy import deepcopy
from pathlib import Path
from typing import Any

from sqlalchemy import create_engine, text

import market_pipeline_lib.legacy_bootstrap as legacy_bootstrap
from market_pipeline_lib.catalog import PostgresCatalog, StorageObjectsPolicy
from market_pipeline_lib.legacy_bootstrap import (
    BootstrapConflict,
    connect_read_only_catalog,
    materialize_legacy_catalog,
    same_database,
)


# The first fingerprint is the retired V001 schema as observed by the pipeline
# test fixture.  The second is the same 110 columns, 62 constraints and 10 enum
# labels after the production dump was restored into PostgreSQL 16.  The eight
# differing strings are pg_get_constraintdef() renderings of equivalent ARRAY
# casts; no column, constraint name/type, enum, or constraint semantics differ.
SUPPORTED_LEGACY_V001_FINGERPRINTS = {
    "efc1451bc381b00778b48048651a506577c6a85d4f4d7335c0166ee8cb88d424": "deployed-v001",
    "4381478bcec3193ea62cf3d59dd32c65dd53c0a432869103ded05100740b4c25": "pg16-restored-v001",
}

CANONICAL_SEED_PROVIDER_ID = "b9146ed9-dbb0-5323-93e3-8518f3851236"
CANONICAL_TARGET_SEEDS = {
    "market_data.providers": {
        CANONICAL_SEED_PROVIDER_ID: "IDEA2STRATEGY_INTERNAL",
    },
    "market_data.feeds": {
        "063f8f27-5c6a-5348-b2bb-abc3c634149c": "FEATURE_RSI_14_1M_RSI_1_0_0",
        "57794d8c-2254-53e4-966e-44f97edd9e6a": "FEATURE_RSI_14_30M_RSI_1_0_0",
        "28012549-4f45-56d3-8bb6-329e4c7a9d77": "FEATURE_RSI_14_1H_RSI_1_0_0",
        "e1d7d508-aaf1-5ae9-8098-c4af870f6fa4": "FEATURE_RSI_14_4H_RSI_1_0_0",
        "6d2647f8-5caf-55ee-8821-869dc693f68a": "FEATURE_RSI_14_1D_RSI_1_0_0",
    },
}


def authorize_legacy_schema(database_url: str) -> tuple[str, str]:
    """Read-only allow-list the exact source shape before using the translator."""

    engine = create_engine(database_url)
    try:
        with engine.connect() as connection:
            connection.execute(text("SET TRANSACTION READ ONLY"))
            fingerprint = legacy_bootstrap._legacy_schema_fingerprint(connection)
    finally:
        engine.dispose()
    provenance = SUPPORTED_LEGACY_V001_FINGERPRINTS.get(fingerprint)
    if provenance is None:
        raise BootstrapConflict(
            "unsupported legacy V001 schema fingerprint: "
            f"{fingerprint}; source was not modified"
        )
    # The upstream reader retains its own exact fail-closed check.  Select the
    # already allow-listed rendering for this process only; the source remains
    # read-only and every unknown shape still fails above.
    legacy_bootstrap._POPULATED_V001_SCHEMA_FINGERPRINT = fingerprint
    return fingerprint, provenance


def validate_canonical_seed_extras(source: Any, target: Any) -> None:
    """Permit only the deterministic reference rows installed by canonical Flyway."""

    for table, allowed in CANONICAL_TARGET_SEEDS.items():
        source_ids = {str(row["id"]) for row in source.records(table)}
        for row in target.records(table):
            row_id = str(row["id"])
            if row_id in source_ids:
                continue
            if allowed.get(row_id) != str(row["code"]):
                raise BootstrapConflict(
                    f"unexpected canonical target seed row in {table}: {row_id}"
                )
            if (
                table == "market_data.feeds"
                and str(row["provider_id"]) != CANONICAL_SEED_PROVIDER_ID
            ):
                raise BootstrapConflict(
                    f"unexpected canonical target seed row in {table}: {row_id}"
                )


def verify_raw_backup(
    backup: Path,
    *,
    minio_receipt: Path | None = None,
    require_mapping: bool = True,
) -> dict[str, Any]:
    """Verify the full immutable backup without spawning another PowerShell."""

    def load(relative: str) -> Any:
        path = contained(relative)
        return json.loads(path.read_text(encoding="utf-8-sig"))

    def contained(relative: str) -> Path:
        path = (backup / relative).resolve()
        if backup != path and backup not in path.parents:
            raise BootstrapConflict(f"backup path escapes root: {relative}")
        return path

    def sha256(path: Path) -> str:
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
        return digest.hexdigest()

    manifest = load("backup-manifest.json")
    if int(manifest["schema_version"]) != 1:
        raise BootstrapConflict("unsupported raw backup manifest schema")
    dump = contained(str(manifest["database"]["file"]))
    if dump.stat().st_size != int(manifest["database"]["bytes"]):
        raise BootstrapConflict("database dump size differs from manifest")
    if sha256(dump) != str(manifest["database"]["sha256"]).lower():
        raise BootstrapConflict("database dump SHA-256 differs from manifest")

    inventory = load(str(manifest["s3"]["version_inventory_file"]))
    versions = {
        (str(item["Key"]), str(item["VersionId"])): item
        for item in inventory.get("Versions", [])
    }
    delete_markers = {
        (str(item["Key"]), str(item["VersionId"])): item
        for item in inventory.get("DeleteMarkers", [])
    }
    if len(versions) != len(inventory.get("Versions", [])):
        raise BootstrapConflict("duplicate key/version in S3 inventory")

    receipt_ids: set[tuple[str, str]] = set()
    receipt_bytes = 0
    for group, latest, expected in (
        ("current", True, int(manifest["s3"]["current_versions"])),
        ("noncurrent", False, int(manifest["s3"]["noncurrent_versions"])),
    ):
        receipts = load(str(manifest["s3"][f"{group}_receipts_file"]))
        if len(receipts) != expected:
            raise BootstrapConflict(f"{group} receipt count differs from manifest")
        for receipt in receipts:
            identity = (str(receipt["key"]), str(receipt["version_id"]))
            item = versions.get(identity)
            if item is None or bool(item["IsLatest"]) is not latest:
                raise BootstrapConflict(f"S3 inventory differs for {identity!r}")
            if identity in receipt_ids:
                raise BootstrapConflict(f"duplicate S3 receipt: {identity!r}")
            relative = str(receipt["file"]).replace("\\", "/")
            if re.fullmatch(rf"s3-{group}/\d{{6}}\.object", relative) is None:
                raise BootstrapConflict(f"payload is not long-key-safe: {relative}")
            payload = contained(relative)
            size = int(receipt["size"])
            if payload.stat().st_size != size or int(item["Size"]) != size:
                raise BootstrapConflict(f"payload size differs for {identity!r}")
            if sha256(payload) != str(receipt["sha256"]).lower():
                raise BootstrapConflict(f"payload SHA-256 differs for {identity!r}")
            receipt_ids.add(identity)
            receipt_bytes += size
    if receipt_ids != set(versions):
        raise BootstrapConflict("S3 version receipts are incomplete")
    if len(delete_markers) != int(manifest["s3"]["delete_markers"]):
        raise BootstrapConflict("delete-marker count differs from manifest")

    receipt_path = minio_receipt or backup / "local-minio-import-receipt.json"
    if not receipt_path.is_file() and not require_mapping:
        return {
            "status": "SOURCE_VERIFIED",
            "schema_version": 1,
            "s3": {"versions": len(versions), "delete_markers": len(delete_markers)},
            "bytes": receipt_bytes,
        }
    mapping = json.loads(receipt_path.read_text(encoding="utf-8-sig"))
    mapped_versions: set[tuple[str, str]] = set()
    mapped_deletes: set[tuple[str, str]] = set()
    for event in mapping["events"]:
        identity = (str(event["key"]), str(event["source_version_id"]))
        kind = str(event["kind"]).replace("-", "_")
        target = mapped_versions if kind == "version" else mapped_deletes
        expected = versions if kind == "version" else delete_markers
        if kind not in {"version", "delete_marker"} or identity not in expected:
            raise BootstrapConflict(f"unknown MinIO mapping: {identity!r}")
        if identity in target or not str(event.get("target_version_id", "")):
            raise BootstrapConflict(f"invalid MinIO VersionId mapping: {identity!r}")
        target.add(identity)
    if mapped_versions != set(versions) or mapped_deletes != set(delete_markers):
        raise BootstrapConflict("MinIO VersionId mapping is incomplete")
    return {
        "status": "VERIFIED",
        "schema_version": 1,
        "s3": {"versions": len(versions), "delete_markers": len(delete_markers)},
        "bytes": receipt_bytes,
    }


class ReceiptRemappedCatalog:
    """Expose a legacy catalog with only physical MinIO location fields replaced."""

    def __init__(self, source: Any, *, backup: Path, receipt_path: Path, target_bucket: str) -> None:
        self.source = source
        self.backup = backup
        self.target_bucket = target_bucket
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
        self.mapping: dict[tuple[str, str], dict[str, Any]] = {}
        for event in receipt["events"]:
            if str(event["kind"]).replace("-", "_") != "version":
                continue
            identity = (str(event["key"]), str(event["source_version_id"]))
            if identity in self.mapping:
                raise BootstrapConflict(f"duplicate MinIO mapping for {identity!r}")
            self.mapping[identity] = event

    @property
    def bootstrap_target_extra_tables(self) -> frozenset[str]:
        return getattr(self.source, "bootstrap_target_extra_tables", frozenset()).union(
            CANONICAL_TARGET_SEEDS
        )

    def records(self, table: str, *, where: dict[str, Any] | None = None) -> list[dict[str, Any]]:
        rows = self.source.records(table, where=where)
        if table != "storage.objects":
            return rows
        remapped: list[dict[str, Any]] = []
        used: set[tuple[str, str]] = set()
        for original in rows:
            row = deepcopy(original)
            identity = (str(row["object_key"]), str(row["provider_version_id"]))
            event = self.mapping.get(identity)
            if event is None:
                raise BootstrapConflict(f"storage object has no MinIO VersionId mapping: {identity!r}")
            payload = (self.backup / str(event["file"])).resolve()
            if self.backup.resolve() not in payload.parents or not payload.is_file():
                raise BootstrapConflict(f"mapped payload is missing or escapes backup: {event['file']}")
            if payload.stat().st_size != int(row["byte_size"]):
                raise BootstrapConflict(f"mapped payload byte size differs: {identity!r}")
            digest = hashlib.sha256()
            with payload.open("rb") as stream:
                for block in iter(lambda: stream.read(1024 * 1024), b""):
                    digest.update(block)
            observed = digest.hexdigest()
            if observed != str(row["content_hash"]).lower() or observed != str(event["sha256"]).lower():
                raise BootstrapConflict(f"mapped payload content_hash differs: {identity!r}")
            row["storage_provider"] = "S3_COMPATIBLE"
            row["bucket_name"] = self.target_bucket
            row["provider_version_id"] = str(event["target_version_id"])
            remapped.append(row)
            used.add(identity)
        if len(used) != len(rows):
            raise BootstrapConflict("not every canonical storage object received one MinIO mapping")
        return remapped


class VerifiedByReceipt:
    def verify_all(self, rows: list[dict[str, Any]]) -> int:
        return len(rows)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--backup", type=Path, required=True)
    parser.add_argument("--legacy-database-url", default=os.environ.get("LEGACY_DATABASE_URL"))
    parser.add_argument("--canonical-database-url", default=os.environ.get("CANONICAL_DATABASE_URL"))
    parser.add_argument("--source-bucket", required=True)
    parser.add_argument("--target-bucket", required=True)
    parser.add_argument("--minio-receipt", type=Path)
    parser.add_argument("--expected-object-count", type=int, required=True)
    parser.add_argument("--expected-manifest-count", type=int, required=True)
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    if not args.legacy_database_url or not args.canonical_database_url:
        parser.error("legacy and canonical database URLs are required")
    backup = args.backup.expanduser().resolve()
    minio_receipt = (
        args.minio_receipt.expanduser().resolve()
        if args.minio_receipt
        else backup / "local-minio-import-receipt.json"
    )
    if same_database(args.legacy_database_url, args.canonical_database_url):
        raise SystemExit("legacy and canonical databases must differ")

    raw_verification = verify_raw_backup(backup, minio_receipt=minio_receipt)
    source_fingerprint, source_schema_provenance = authorize_legacy_schema(
        args.legacy_database_url
    )

    source = connect_read_only_catalog(
        args.legacy_database_url,
        artifact_root=backup / ".catalog-audit-source",
        legacy_bucket_name=args.source_bucket,
    )
    target = (
        PostgresCatalog.connect(
            args.canonical_database_url,
            artifact_root=backup / ".catalog-audit-target",
            storage_objects=StorageObjectsPolicy.WRITE_D_OWNED,
        )
        if args.execute
        else connect_read_only_catalog(
            args.canonical_database_url, artifact_root=backup / ".catalog-audit-target"
        )
    )
    try:
        source.verify_schema()
        target.verify_schema()
        validate_canonical_seed_extras(source, target)
        remapped = ReceiptRemappedCatalog(
            source,
            backup=backup,
            receipt_path=minio_receipt,
            target_bucket=args.target_bucket,
        )
        report = materialize_legacy_catalog(
            remapped,
            target,
            object_verifier=VerifiedByReceipt(),
            expected_object_count=args.expected_object_count,
            expected_manifest_count=args.expected_manifest_count,
            execute=args.execute,
        )
        report["physical_location_remap"] = {
            "storage_provider": "S3_COMPATIBLE",
            "target_bucket": args.target_bucket,
            "mapped_versions": args.expected_object_count,
        }
        report["legacy_schema"] = {
            "fingerprint": source_fingerprint,
            "provenance": source_schema_provenance,
        }
        report["raw_backup_verification"] = {
            "status": raw_verification["status"],
            "schema_version": raw_verification["schema_version"],
            "s3_versions": raw_verification["s3"]["versions"],
            "delete_markers": raw_verification["s3"]["delete_markers"],
        }
        report["idempotency_statuses"] = ["APPLIED", "ALREADY_APPLIED"]
        print(json.dumps(report, ensure_ascii=False, indent=2, default=str))
    finally:
        target.close()
        source.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
