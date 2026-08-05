"""Reuse the backtest service's canonical PostgreSQL/LocalStack fixtures.

The root integration suite deliberately owns no database DDL.  Loading the child
fixture module here means the same ordered central Flyway fixture and the same
PostgreSQL 16 + LocalStack setup used by the service CI are used by the
cross-repository release proof.
"""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BACKTEST = ROOT / "backtest-engine"
sys.path[:0] = [str(BACKTEST / "src"), str(BACKTEST / "tests")]

spec = importlib.util.spec_from_file_location(
    "idea2strategy_backtest_conftest", BACKTEST / "tests" / "conftest.py"
)
if spec is None or spec.loader is None:  # pragma: no cover - checkout corruption
    raise RuntimeError("cannot load the pinned backtest integration fixtures")
shared = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = shared
spec.loader.exec_module(shared)

# Pytest discovers these decorated fixture definitions through this module.
postgres_url = shared.postgres_url
admin_engine = shared.admin_engine
runtime_engine = shared.runtime_engine
persistence = shared.persistence
localstack = shared.localstack
sqs = shared.sqs
s3 = shared.s3
bucket = shared.bucket
_empty_backtest_tables = shared._empty_backtest_tables
