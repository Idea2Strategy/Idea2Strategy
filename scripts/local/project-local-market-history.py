from __future__ import annotations

import json
import os
import sys
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import boto3
import redis


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(
    0,
    os.environ.get("DATA_PIPELINE_SRC", str(ROOT / "data-pipeline")),
)

from apps.pipeline_worker.sync_market_history import HistorySyncConfig, _project_history
from market_pipeline_lib.catalog import PostgresCatalog, StorageObjectsPolicy
from market_pipeline_lib.storage import S3ObjectStore


def _local_backup_manifests(catalog: Any, timeframe: str, _layer: str) -> list[dict[str, Any]]:
    feed_codes = {
        str(row["id"]): str(row["code"])
        for row in catalog.records("market_data.feeds")
    }
    expected_feed = f"ALPACA_SIP_ALL_{timeframe.upper()}"
    return sorted(
        (
            row
            for row in catalog.records("market_data.dataset_manifests")
            if row["status"] == "AVAILABLE"
            and feed_codes.get(str(row["feed_id"])) == expected_feed
            and row["data_layer"] == "ADJUSTED"
            and row["resolution"] == timeframe
        ),
        key=lambda row: (str(row["period_start"]), int(row["revision_number"])),
    )


def main() -> None:
    database_url = os.environ["LOCAL_HISTORY_DATABASE_URL"]
    bucket = os.environ["LOCAL_HISTORY_S3_BUCKET"]
    redis_uri = os.environ["LOCAL_HISTORY_REDIS_URI"]
    endpoint = os.environ["LOCAL_HISTORY_S3_ENDPOINT"]
    state_root = Path(os.environ["LOCAL_HISTORY_STATE_ROOT"]).resolve()
    config = HistorySyncConfig(
        database_url=database_url,
        bucket=bucket,
        redis_uri=redis_uri,
        redis_key_prefix="i2s",
        limit=1000,
        api_key="local-projection-does-not-publish",
        api_secret="local-projection-does-not-publish",
        state_root=state_root,
    )
    catalog = PostgresCatalog.connect(
        database_url,
        artifact_root=state_root / "catalog-artifacts",
        storage_objects=StorageObjectsPolicy.READ_ONLY,
    )
    object_store = S3ObjectStore(
        bucket,
        client=boto3.client("s3", endpoint_url=endpoint),
    )
    redis_client = redis.Redis.from_url(redis_uri, decode_responses=True)
    try:
        result = _project_history(
            catalog,
            object_store,
            redis_client,
            config,
            datetime.now(UTC),
            manifest_selector=_local_backup_manifests,
            require_storage_metadata=False,
        )
    finally:
        redis_client.close()
        catalog.close()
    print(json.dumps({"status": "projected", **result}, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
