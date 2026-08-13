#!/usr/bin/env python3
"""Resume-safe restore of every S3 version and delete marker into MinIO."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from datetime import datetime
from pathlib import Path
from typing import Any

import boto3
from botocore.exceptions import ClientError


def load_migration_module() -> Any:
    path = Path(__file__).with_name("migrate-legacy-market-data.py")
    spec = importlib.util.spec_from_file_location("i2s_raw_restore_dependency", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load verifier dependency: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def write_json(path: Path, value: Any) -> None:
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.parent.mkdir(parents=True, exist_ok=True)
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")
    temporary.replace(path)


def live_events(client: Any, bucket: str) -> set[tuple[str, str, str]]:
    result: set[tuple[str, str, str]] = set()
    for page in client.get_paginator("list_object_versions").paginate(Bucket=bucket):
        result.update(("version", str(item["Key"]), str(item["VersionId"])) for item in page.get("Versions", []))
        result.update(("delete_marker", str(item["Key"]), str(item["VersionId"])) for item in page.get("DeleteMarkers", []))
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--backup", type=Path, required=True)
    parser.add_argument("--receipt", type=Path, required=True)
    parser.add_argument("--endpoint", default=os.environ.get("MINIO_ENDPOINT"))
    parser.add_argument("--access-key", default=os.environ.get("MINIO_ACCESS_KEY"))
    parser.add_argument("--secret-key", default=os.environ.get("MINIO_SECRET_KEY"))
    parser.add_argument("--bucket", required=True)
    parser.add_argument("--region", default="ap-northeast-2")
    args = parser.parse_args()
    if not all((args.endpoint, args.access_key, args.secret_key)):
        parser.error("MinIO connection variables are required")
    backup = args.backup.expanduser().resolve()
    receipt_path = args.receipt.expanduser().resolve()
    if backup == receipt_path or backup in receipt_path.parents:
        raise RuntimeError("local restore receipt must be outside the immutable backup")
    migration = load_migration_module()
    raw = migration.verify_raw_backup(backup, require_mapping=False)
    manifest_bytes = (backup / "backup-manifest.json").read_bytes()
    manifest_sha256 = hashlib.sha256(manifest_bytes).hexdigest()
    manifest = json.loads(manifest_bytes.decode("utf-8-sig"))

    client = boto3.client(
        "s3",
        endpoint_url=args.endpoint,
        aws_access_key_id=args.access_key,
        aws_secret_access_key=args.secret_key,
        region_name=args.region,
    )
    try:
        client.head_bucket(Bucket=args.bucket)
    except ClientError as error:
        if error.response.get("Error", {}).get("Code") not in {"404", "NoSuchBucket"}:
            raise
        client.create_bucket(Bucket=args.bucket)
    client.put_bucket_versioning(Bucket=args.bucket, VersioningConfiguration={"Status": "Enabled"})

    if receipt_path.is_file():
        receipt = json.loads(receipt_path.read_text(encoding="utf-8-sig"))
        expected = {
            (str(event["kind"]), str(event["key"]), str(event["target_version_id"]))
            for event in receipt["events"]
        }
        if receipt.get("manifest_sha256") != manifest_sha256 or receipt.get("target_bucket") != args.bucket:
            raise RuntimeError("existing restore receipt belongs to another backup or bucket")
        if live_events(client, args.bucket) != expected:
            raise RuntimeError("existing completed receipt differs from live MinIO versions")
        print(json.dumps({"status": "ALREADY_RESTORED", "events": len(expected)}, indent=2))
        return 0

    current = json.loads((backup / str(manifest["s3"]["current_receipts_file"])).read_text(encoding="utf-8-sig"))
    noncurrent = json.loads((backup / str(manifest["s3"]["noncurrent_receipts_file"])).read_text(encoding="utf-8-sig"))
    payloads = {(str(item["key"]), str(item["version_id"])): item for item in current + noncurrent}
    inventory = json.loads((backup / str(manifest["s3"]["version_inventory_file"])).read_text(encoding="utf-8-sig"))
    ordered: list[dict[str, Any]] = []
    for index, item in enumerate(inventory.get("Versions", [])):
        identity = (str(item["Key"]), str(item["VersionId"]))
        receipt = payloads[identity]
        ordered.append({
            "kind": "version", "key": identity[0], "source_version_id": identity[1],
            "last_modified": str(item["LastModified"]), "reverse_order": -index,
            "file": str(receipt["file"]), "size": int(receipt["size"]), "sha256": str(receipt["sha256"]),
        })
    for index, item in enumerate(inventory.get("DeleteMarkers", [])):
        ordered.append({
            "kind": "delete_marker", "key": str(item["Key"]), "source_version_id": str(item["VersionId"]),
            "last_modified": str(item["LastModified"]), "reverse_order": -index,
        })
    ordered.sort(key=lambda event: (event["key"], datetime.fromisoformat(event["last_modified"]), event["reverse_order"]))

    journal_path = receipt_path.with_suffix(receipt_path.suffix + ".journal.jsonl")
    restored: list[dict[str, Any]] = []
    if journal_path.is_file():
        lines = [json.loads(line) for line in journal_path.read_text(encoding="utf-8").splitlines() if line.strip()]
        if not lines or lines[0] != {"kind": "header", "manifest_sha256": manifest_sha256, "target_bucket": args.bucket}:
            raise RuntimeError("resume journal belongs to another backup or bucket")
        restored = lines[1:]
    else:
        if live_events(client, args.bucket):
            raise RuntimeError("target bucket is not empty and has no matching resume journal")
        journal_path.parent.mkdir(parents=True, exist_ok=True)
        journal_path.write_text(
            json.dumps({"kind": "header", "manifest_sha256": manifest_sha256, "target_bucket": args.bucket}) + "\n",
            encoding="utf-8",
        )

    restored_sources = {(str(event["kind"]), str(event["key"]), str(event["source_version_id"])) for event in restored}
    expected_live = {(str(event["kind"]), str(event["key"]), str(event["target_version_id"])) for event in restored}
    if live_events(client, args.bucket) != expected_live:
        raise RuntimeError("live MinIO state differs from the resume journal")

    for index, event in enumerate(ordered, start=1):
        source_identity = (event["kind"], event["key"], event["source_version_id"])
        if source_identity in restored_sources:
            continue
        if event["kind"] == "version":
            payload = (backup / event["file"]).resolve()
            if backup not in payload.parents:
                raise RuntimeError(f"payload escapes backup: {event['file']}")
            with payload.open("rb") as stream:
                response = client.put_object(
                    Bucket=args.bucket,
                    Key=event["key"],
                    Body=stream,
                    Metadata={"sha256": event["sha256"]},
                )
        else:
            response = client.delete_object(Bucket=args.bucket, Key=event["key"])
        target_version = str(response.get("VersionId", ""))
        if not target_version:
            raise RuntimeError(f"MinIO returned no target_version_id for {source_identity!r}")
        recorded = {**event, "target_version_id": target_version}
        with journal_path.open("a", encoding="utf-8") as journal:
            journal.write(json.dumps(recorded, ensure_ascii=False) + "\n")
        restored.append(recorded)
        restored_sources.add(source_identity)
        if index % 500 == 0:
            print(f"[restore] {index}/{len(ordered)} events", flush=True)

    receipt = {
        "schema_version": 1,
        "manifest_sha256": manifest_sha256,
        "source_account": manifest["source_account"],
        "source_bucket": manifest["source_bucket"],
        "target_endpoint": args.endpoint,
        "target_bucket": args.bucket,
        "events": restored,
        "raw_verification": raw,
    }
    write_json(receipt_path, receipt)
    expected = {(event["kind"], event["key"], event["target_version_id"]) for event in restored}
    if live_events(client, args.bucket) != expected:
        raise RuntimeError("completed MinIO restore differs from the generated receipt")
    print(json.dumps({"status": "RESTORED_AND_VERIFIED", "events": len(restored), "receipt": str(receipt_path)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
