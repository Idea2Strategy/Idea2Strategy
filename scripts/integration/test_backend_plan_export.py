"""Platform selection for the backend Gradle wrapper used by the plan export."""

from __future__ import annotations

import backend_plan_export as export


def test_windows_runs_the_batch_wrapper() -> None:
    assert export.gradle_wrapper_command("nt") == [str(export.BACKEND / "gradlew.bat")]


def test_posix_runs_the_shell_wrapper_without_an_executable_bit() -> None:
    assert export.gradle_wrapper_command("posix") == [
        "sh",
        str(export.BACKEND / "gradlew"),
    ]
