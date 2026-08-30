from __future__ import annotations

import hashlib
import importlib.util
import io
from pathlib import Path
from typing import ClassVar

ROOT = Path(__file__).resolve().parents[3]
SCRIPT = ROOT / "scripts" / "local" / "materialize-local-strategy-features.py"


def _load_module():
    spec = importlib.util.spec_from_file_location(
        "local_feature_materialization", SCRIPT
    )
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class _Rows:
    def __init__(self, rows):
        self._rows = rows

    def fetchall(self):
        return self._rows

    def fetchone(self):
        return self._rows[0]


class _InstrumentConnection:
    ids: ClassVar = {
        "AAPL": "aa268aa6-9401-49d0-a2d4-a2a490df7d84",
        "AMZN": "a67d0c5c-c4e5-4562-a35c-c3be736f4d49",
        "META": "7233ce25-2963-4f55-91cd-907f405c4518",
        "MSFT": "35ca27e4-8d72-4fe3-a54c-5066b4c15dcd",
        "NVDA": "5a214db8-9b32-4534-9b5b-95df27bde5a4",
    }

    def execute(self, _query, parameters):
        requested = parameters[0]
        return _Rows([(symbol, self.ids[symbol]) for symbol in requested])


def test_materializer_prepares_every_instrument_used_by_the_full_catalog_sample() -> (
    None
):
    """Removing any mixed-resolution sample symbol must break local release preparation."""
    module = _load_module()

    instruments = module._instrument_ids(_InstrumentConnection())

    assert instruments == _InstrumentConnection.ids


class _ReferencedFeatureConnection:
    def execute(self, _query):
        return _Rows([("feature-output/referenced.parquet",)])


class _FeaturePage:
    def paginate(self, **_parameters):
        return [
            {
                "Contents": [
                    {"Key": "feature-output/referenced.parquet"},
                    {"Key": "feature-output/orphan.parquet"},
                    {"Key": "market-data/not-in-prefix.parquet"},
                ]
            }
        ]


class _FeatureClient:
    def __init__(self):
        self.deleted = []

    def get_paginator(self, operation):
        assert operation == "list_objects_v2"
        return _FeaturePage()

    def delete_objects(self, **parameters):
        self.deleted.append(parameters)


def test_local_materializer_removes_only_unreferenced_feature_outputs() -> None:
    """A referenced immutable result must never be pruned while repairing local state."""
    module = _load_module()
    client = _FeatureClient()

    removed = module._prune_orphan_feature_outputs(
        _ReferencedFeatureConnection(),
        client,
        "market-data",
    )

    assert removed == 1
    assert client.deleted == [
        {
            "Bucket": "market-data",
            "Delete": {
                "Objects": [{"Key": "feature-output/orphan.parquet"}],
                "Quiet": True,
            },
        }
    ]


class _NormalizedSourceConnection:
    payload = b"canonical-market-object"

    def __init__(self):
        self.updates = []

    def execute(self, query, parameters):
        if query.startswith("select storage.id"):
            return _Rows(
                [
                    (
                        "storage-1",
                        "market-data",
                        "bars.parquet",
                        "version-1",
                        hashlib.sha256(self.payload).hexdigest(),
                        len(self.payload),
                    )
                ]
            )
        self.updates.append((query, parameters))
        return _Rows([])


class _AlreadyImmutableClient:
    def head_object(self, **parameters):
        assert parameters == {
            "Bucket": "market-data",
            "Key": "bars.parquet",
            "VersionId": "version-1",
        }
        return {
            "Metadata": {"sha256": hashlib.sha256(_NormalizedSourceConnection.payload).hexdigest()},
            "ServerSideEncryption": "AES256",
            "VersionId": "version-1",
            "ContentLength": len(_NormalizedSourceConnection.payload),
        }

    def get_object(self, **parameters):
        assert parameters == {
            "Bucket": "market-data",
            "Key": "bars.parquet",
            "VersionId": "version-1",
        }
        return {"Body": io.BytesIO(_NormalizedSourceConnection.payload)}


def test_normalize_sources_records_s3_provider_even_when_object_is_already_immutable(
    monkeypatch,
) -> None:
    module = _load_module()
    connection = _NormalizedSourceConnection()
    client = _AlreadyImmutableClient()
    monkeypatch.setenv("LOCAL_FEATURE_S3_ENDPOINT", "http://minio")
    monkeypatch.setenv("LOCAL_FEATURE_S3_BUCKET", "market-data")
    monkeypatch.setattr(module.boto3, "client", lambda *_args, **_kwargs: client)

    assert module._normalize_sources(connection, {"relation-1"}) == 1
    assert connection.updates == [
        (
            (
                "update storage.objects set storage_provider = 'S3', bucket_name = %s, "
                "provider_version_id = %s where id = %s"
            ),
            ("market-data", "version-1", "storage-1"),
        )
    ]


def test_normalize_sources_rejects_a_spoofed_metadata_hash() -> None:
    module = _load_module()
    connection = _NormalizedSourceConnection()

    class SpoofedClient(_AlreadyImmutableClient):
        def get_object(self, **_parameters):
            return {"Body": io.BytesIO(b"x" * len(connection.payload))}

    module.boto3.client = lambda *_args, **_kwargs: SpoofedClient()
    module.os.environ["LOCAL_FEATURE_S3_ENDPOINT"] = "http://minio"
    module.os.environ["LOCAL_FEATURE_S3_BUCKET"] = "market-data"

    try:
        module._normalize_sources(connection, {"relation-1"})
    except RuntimeError as error:
        assert "integrity mismatch" in str(error)
    else:
        raise AssertionError("spoofed object bytes must not be trusted")
    assert connection.updates == []


def test_normalize_sources_rejects_a_wrong_head_size() -> None:
    module = _load_module()
    connection = _NormalizedSourceConnection()

    class WrongSizeClient(_AlreadyImmutableClient):
        def head_object(self, **parameters):
            result = super().head_object(**parameters)
            result["ContentLength"] += 1
            return result

    module.boto3.client = lambda *_args, **_kwargs: WrongSizeClient()
    module.os.environ["LOCAL_FEATURE_S3_ENDPOINT"] = "http://minio"
    module.os.environ["LOCAL_FEATURE_S3_BUCKET"] = "market-data"

    try:
        module._normalize_sources(connection, {"relation-1"})
    except RuntimeError as error:
        assert "integrity mismatch" in str(error)
    else:
        raise AssertionError("wrong object size must be rejected")
    assert connection.updates == []


def test_normalize_sources_copies_a_verified_fallback_object_into_the_target_bucket() -> None:
    module = _load_module()
    connection = _NormalizedSourceConnection()

    class FallbackClient:
        def __init__(self):
            self.puts = []

        def head_object(self, **parameters):
            if parameters["Bucket"] == "market-data":
                from botocore.exceptions import ClientError

                raise ClientError(
                    {"Error": {"Code": "404"}, "ResponseMetadata": {"HTTPStatusCode": 404}},
                    "HeadObject",
                )
            return {
                "Metadata": {"sha256": hashlib.sha256(connection.payload).hexdigest()},
                "ServerSideEncryption": "AES256",
                "VersionId": "fallback-version",
                "ContentLength": len(connection.payload),
            }

        def list_buckets(self):
            return {"Buckets": [{"Name": "market-data"}, {"Name": "legacy-bucket"}]}

        def get_object(self, **parameters):
            assert parameters["Bucket"] == "legacy-bucket"
            return {"Body": io.BytesIO(connection.payload)}

        def put_object(self, **parameters):
            self.puts.append(parameters)
            return {"VersionId": "target-version"}

    client = FallbackClient()
    module.boto3.client = lambda *_args, **_kwargs: client
    module.os.environ["LOCAL_FEATURE_S3_ENDPOINT"] = "http://minio"
    module.os.environ["LOCAL_FEATURE_S3_BUCKET"] = "market-data"

    assert module._normalize_sources(connection, {"relation-1"}) == 1
    assert len(client.puts) == 1
    assert client.puts[0]["Bucket"] == "market-data"
    assert connection.updates[0][1] == ("market-data", "target-version", "storage-1")
