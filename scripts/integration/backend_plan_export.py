"""Invoke the production backend export boundary once for the complete Basic matrix."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
from functools import lru_cache
from pathlib import Path

import basic_strategy_cases as matrix

ROOT = Path(__file__).resolve().parents[2]
BACKEND = ROOT / "backend"
EXPORT_TEST = (
    "*BasicStrategyArtifactExporterPersistenceIntegrationTest."
    "exportsTheRootCompatibilityBundleThroughTheProductionBoundary"
)


@lru_cache(maxsize=1)
def compiled_plans() -> dict[str, dict[str, object]]:
    request = {
        "cases": [
            {
                "name": case.name,
                "partitions": list(matrix.semantic_partitions(case)),
            }
            for case in matrix.generated_cases()
        ]
    }
    directory = Path(tempfile.gettempdir()) / "idea2strategy-release-proof-task3"
    directory.mkdir(parents=True, exist_ok=True)
    input_path = directory / "backend-export-input.json"
    output_path = directory / "backend-export-output.json"
    input_path.write_text(
        json.dumps(request, sort_keys=True, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    output_path.unlink(missing_ok=True)
    environment = os.environ.copy()
    environment["TASK3_BACKEND_EXPORT_INPUT"] = str(input_path)
    environment["TASK3_BACKEND_EXPORT_OUTPUT"] = str(output_path)
    completed = subprocess.run(
        [
            str(BACKEND / "gradlew.bat"),
            ":modules:backend-persistence:test",
            "--rerun-tasks",
            "--tests",
            EXPORT_TEST,
        ],
        cwd=BACKEND,
        env=environment,
        capture_output=True,
        text=True,
        timeout=180,
        check=False,
    )
    if completed.returncode != 0 or not output_path.is_file():
        raise AssertionError(
            "production backend export failed\n"
            + completed.stdout[-4000:]
            + completed.stderr[-4000:]
        )
    response = json.loads(output_path.read_text(encoding="utf-8"))
    plans = {
        item["name"]: json.loads(item["planDocument"]) for item in response["cases"]
    }
    expected = {case.name for case in matrix.generated_cases()}
    if set(plans) != expected:
        raise AssertionError(
            "production backend export returned the wrong case identities"
        )
    return plans
