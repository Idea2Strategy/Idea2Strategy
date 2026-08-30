"""Prepare the small, deterministic feature set used by local strategy backtests."""

from __future__ import annotations

import base64
import hashlib
import json
import os
import sys
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo

import boto3
import psycopg
from botocore.exceptions import ClientError

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "data-pipeline"))

from apps.pipeline_worker.commands import Command, PipelineCommandExecutor
from apps.pipeline_worker.config import WorkerConfig
from market_pipeline_lib.catalog import (
    PostgresCatalog,
    StorageObjectsPolicy,
)
from market_pipeline_lib.features.backfill import plan_feature_backfill
from market_pipeline_lib.features.definitions import (
    PRODUCTION_RSI_14_RESOLUTIONS,
    production_rsi_14_definition,
)

SYMBOLS = ("AAPL", "AMZN", "META", "MSFT", "NVDA")
REQUIRED_OBSERVATIONS = 14
FEATURE_OUTPUT_PREFIX = "feature-output/"
FEATURE_OUTPUT_SCHEMA = "feature-series.parquet.v1"


def _psycopg_url(url: str) -> str:
    return url.replace("postgresql+psycopg:", "postgresql:", 1)


def _evaluation_window(connection: psycopg.Connection) -> tuple[datetime, datetime]:
    document = connection.execute(
        "select policy_document from backtest.execution_policy_versions "
        "where retired_at is null and policy_document->>'marketDataSchemaVersion' = 'market-bars/1' "
        "order by locked_at desc limit 1"
    ).fetchone()
    if document is None:
        raise RuntimeError("local market-bars/1 execution policy is missing")
    policy = document[0]
    timezone = ZoneInfo(policy["timezone"])
    start_date = (
        datetime.fromisoformat(policy["periodStart"].replace("Z", "+00:00"))
        .astimezone(timezone)
        .date()
    )
    end_date = (
        datetime.fromisoformat(policy["periodEnd"].replace("Z", "+00:00"))
        .astimezone(timezone)
        .date()
    )
    return (
        datetime.combine(start_date, datetime.min.time(), tzinfo=UTC),
        datetime.combine(end_date + timedelta(days=1), datetime.min.time(), tzinfo=UTC),
    )


def _instrument_ids(connection: psycopg.Connection) -> dict[str, str]:
    rows = connection.execute(
        "select symbol, instrument_id from market_data.instrument_symbols "
        "where symbol = any(%s) and effective_to is null",
        (list(SYMBOLS),),
    ).fetchall()
    found = {row[0]: str(row[1]) for row in rows}
    missing = sorted(set(SYMBOLS) - found.keys())
    if missing:
        raise RuntimeError(
            f"local strategy instruments are missing: {', '.join(missing)}"
        )
    return found


def _official_source_ids(
    connection: psycopg.Connection, evaluation_start: datetime, evaluation_end: datetime
) -> set[str]:
    earliest_start = evaluation_start - timedelta(days=REQUIRED_OBSERVATIONS)
    rows = connection.execute(
        "select relation.id from market_data.dataset_manifests manifest "
        "join market_data.feeds feed on feed.id = manifest.feed_id "
        "join market_data.dataset_objects relation on relation.dataset_manifest_id = manifest.id "
        "where manifest.status = 'AVAILABLE' and feed.code = any(%s) "
        "and manifest.period_start < %s and manifest.period_end > %s",
        (
            [
                f"ALPACA_SIP_ALL_{item.upper()}"
                for item in PRODUCTION_RSI_14_RESOLUTIONS
            ],
            evaluation_end,
            earliest_start,
        ),
    ).fetchall()
    return {str(row[0]) for row in rows}


def _prune_orphan_feature_outputs(
    connection: psycopg.Connection,
    client: Any,
    bucket: str,
) -> int:
    """Remove local immutable outputs that no canonical storage receipt references."""
    referenced = {
        str(row[0])
        for row in connection.execute(
            "select object_key from storage.objects where object_key like 'feature-output/%'"
        ).fetchall()
    }
    orphaned = sorted(
        item["Key"]
        for page in client.get_paginator("list_objects_v2").paginate(
            Bucket=bucket,
            Prefix=FEATURE_OUTPUT_PREFIX,
        )
        for item in page.get("Contents", [])
        if str(item["Key"]).startswith(FEATURE_OUTPUT_PREFIX)
        and str(item["Key"]) not in referenced
    )
    for offset in range(0, len(orphaned), 1000):
        client.delete_objects(
            Bucket=bucket,
            Delete={
                "Objects": [{"Key": key} for key in orphaned[offset : offset + 1000]],
                "Quiet": True,
            },
        )
    return len(orphaned)


def _retire_incompatible_feature_outputs(connection: psycopg.Connection) -> int:
    """Retire legacy outputs whose keys cannot bind the immutable manifest identity."""
    rows = connection.execute(
        "update market_data.dataset_manifests manifest set status = 'SUPERSEDED' "
        "where manifest.status = 'AVAILABLE' and manifest.schema_version = %s "
        "and exists (select 1 from market_data.dataset_objects relation "
        "join storage.objects storage on storage.id = relation.object_id "
        "where relation.dataset_manifest_id = manifest.id "
        "and position('/manifest_id=' || manifest.id::text || '/' in storage.object_key) = 0) "
        "returning manifest.id",
        (FEATURE_OUTPUT_SCHEMA,),
    ).fetchall()
    return len(rows)


def _feature_output_ids(
    connection: psycopg.Connection, instrument_ids: list[str]
) -> set[str]:
    rows = connection.execute(
        "select relation.id from market_data.feature_materializations materialization "
        "join market_data.dataset_manifests manifest "
        "on manifest.id = materialization.output_dataset_manifest_id "
        "join market_data.dataset_objects relation "
        "on relation.dataset_manifest_id = manifest.id "
        "where materialization.status = 'SUCCEEDED' and manifest.status = 'AVAILABLE' "
        "and manifest.schema_version = %s and materialization.instrument_id = any(%s)",
        (FEATURE_OUTPUT_SCHEMA, instrument_ids),
    ).fetchall()
    return {str(row[0]) for row in rows}


def _normalize_sources(connection: psycopg.Connection, object_ids: set[str]) -> int:
    client = boto3.client("s3", endpoint_url=os.environ["LOCAL_FEATURE_S3_ENDPOINT"])
    target_bucket = os.environ["LOCAL_FEATURE_S3_BUCKET"]
    for object_id in sorted(object_ids):
        storage_id, bucket, key, version_id, expected_hash, expected_size = (
            connection.execute(
                "select storage.id, storage.bucket_name, storage.object_key, storage.provider_version_id, "
                "storage.content_hash, storage.byte_size from market_data.dataset_objects relation "
                "join storage.objects storage on storage.id = relation.object_id where relation.id = %s",
                (object_id,),
            ).fetchone()
        )
        try:
            current = client.head_object(Bucket=bucket, Key=key, VersionId=version_id)
            read_version = version_id
            source_bucket = bucket
        except ClientError as error:
            if error.response.get("ResponseMetadata", {}).get("HTTPStatusCode") not in {
                404
            }:
                raise
            current = None
            for candidate in [
                bucket,
                *(
                    item["Name"]
                    for item in client.list_buckets()["Buckets"]
                    if item["Name"] != bucket
                ),
            ]:
                try:
                    current = client.head_object(Bucket=candidate, Key=key)
                    source_bucket = candidate
                    break
                except ClientError as candidate_error:
                    if candidate_error.response.get("ResponseMetadata", {}).get(
                        "HTTPStatusCode"
                    ) not in {404}:
                        raise
            if current is None:
                raise RuntimeError(
                    f"source object is absent from every local bucket: {object_id}"
                ) from error
            read_version = current.get("VersionId")
        if int(current.get("ContentLength", -1)) != int(expected_size):
            raise RuntimeError(f"source object integrity mismatch: {object_id}")
        get_parameters = {"Bucket": source_bucket, "Key": key}
        if read_version:
            get_parameters["VersionId"] = read_version
        body = client.get_object(**get_parameters)["Body"].read()
        actual_hash = hashlib.sha256(body).hexdigest()
        if actual_hash != expected_hash or len(body) != expected_size:
            raise RuntimeError(f"source object integrity mismatch: {object_id}")
        if (
            source_bucket == target_bucket
            and current.get("Metadata", {}).get("sha256") == actual_hash
            and current.get("ServerSideEncryption") == "AES256"
        ):
            connection.execute(
                "update storage.objects set storage_provider = 'S3', bucket_name = %s, "
                "provider_version_id = %s where id = %s",
                (source_bucket, read_version, storage_id),
            )
            continue
        written = client.put_object(
            Bucket=target_bucket,
            Key=key,
            Body=body,
            Metadata={"sha256": actual_hash},
            ServerSideEncryption="AES256",
            ChecksumAlgorithm="SHA256",
            ChecksumSHA256=base64.b64encode(hashlib.sha256(body).digest()).decode(),
        )
        connection.execute(
            "update storage.objects set storage_provider = 'S3', bucket_name = %s, provider_version_id = %s "
            "where id = %s",
            (target_bucket, written["VersionId"], storage_id),
        )
    return len(object_ids)


def main() -> None:
    database_url = os.environ["LOCAL_FEATURE_DATABASE_URL"]
    work_root = Path(os.environ["LOCAL_FEATURE_ROOT"]).resolve()
    work_root.mkdir(parents=True, exist_ok=True)
    client = boto3.client("s3", endpoint_url=os.environ["LOCAL_FEATURE_S3_ENDPOINT"])
    with psycopg.connect(_psycopg_url(database_url)) as connection:
        evaluation_start, evaluation_end = _evaluation_window(connection)
        instruments = _instrument_ids(connection)
        official_source_ids = _official_source_ids(
            connection, evaluation_start, evaluation_end
        )
        pruned = _prune_orphan_feature_outputs(
            connection,
            client,
            os.environ["LOCAL_FEATURE_S3_BUCKET"],
        )
        retired = _retire_incompatible_feature_outputs(connection)

    catalog = PostgresCatalog.connect(
        database_url,
        artifact_root=work_root / "catalog",
        storage_objects=StorageObjectsPolicy.READ_ONLY,
    )
    messages: list[dict[str, object]] = []
    satisfied = 0
    for resolution in PRODUCTION_RSI_14_RESOLUTIONS:
        seconds = {"30m": 1800, "1h": 3600, "4h": 14400, "1d": 86400}[resolution]
        period_start = evaluation_start - timedelta(
            seconds=seconds * REQUIRED_OBSERVATIONS
        )
        for instrument_id in instruments.values():
            plan = plan_feature_backfill(
                catalog,
                [production_rsi_14_definition(resolution)],
                instrument_ids=[instrument_id],
                period_start=period_start,
                period_end=evaluation_end,
            )
            if plan.has_holes or plan.warnings:
                raise RuntimeError(
                    f"feature backfill is incomplete for {instrument_id}/{resolution}: {plan.warnings}"
                )
            messages.extend(command.message() for command in plan.commands)
            satisfied += len(plan.satisfied)

    source_ids = official_source_ids | {
        str(object_id)
        for message in messages
        for object_id in message["payload"]["source_dataset_object_ids"]
    }
    with psycopg.connect(_psycopg_url(database_url)) as connection:
        normalized = _normalize_sources(connection, source_ids)

    environment = {
        "PIPELINE_WORKER_ENVIRONMENT": "local",
        "PIPELINE_WORKER_MESSAGE_SOURCE": "inprocess",
        "PIPELINE_WORKER_CATALOG_ROOT": str(work_root / "catalog"),
        "PIPELINE_WORKER_OBJECT_STORE_ROOT": str(work_root / "objects"),
        "PIPELINE_WORKER_DATABASE_URL": database_url,
        "PIPELINE_WORKER_AWS_ENDPOINT_URL": os.environ["LOCAL_FEATURE_S3_ENDPOINT"],
        "PIPELINE_WORKER_AWS_REGION": os.environ.get("AWS_REGION", "ap-northeast-2"),
        "PIPELINE_WORKER_FEATURE_OUTPUT": json.dumps(
            {
                "object_bucket": os.environ["LOCAL_FEATURE_S3_BUCKET"],
                "object_prefix": "feature-output",
                "staging_root": str(work_root / "staging"),
            }
        ),
    }
    executor = PipelineCommandExecutor(WorkerConfig.from_environment(environment))
    executor.prepare()
    results = [
        executor.execute(Command.parse(message, fallback_command_id="local-feature"))
        for message in messages
    ]
    with psycopg.connect(_psycopg_url(database_url)) as connection:
        normalized_outputs = _normalize_sources(
            connection,
            _feature_output_ids(connection, list(instruments.values())),
        )
    print(
        json.dumps(
            {
                "status": "prepared",
                "symbols": list(instruments),
                "materialized": len(results),
                "alreadyMaterialized": satisfied,
                "normalizedSources": normalized,
                "normalizedFeatureOutputs": normalized_outputs,
                "prunedOrphanOutputs": pruned,
                "retiredIncompatibleOutputs": retired,
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
