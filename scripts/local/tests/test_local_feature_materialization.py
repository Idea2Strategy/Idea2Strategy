from __future__ import annotations

import importlib.util
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


class _InstrumentConnection:
    ids: ClassVar = {
        "AAPL": "aa268aa6-9401-49d0-a2d4-a2a490df7d84",
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
