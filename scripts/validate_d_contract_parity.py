#!/usr/bin/env python3
"""Cross-repository contract parity for the D track.

A schema or fixture that exists in two repositories WILL drift. It already did:
two copies of the COM06 fixture diverged so far that the consumer's validator
rejected the producer's own fixture, and neither repository's CI could see it
because each only had its own copy. Separately, B changed `strategy-bot.v1`
mid-flight - adding a `requiredFeatures` block and re-hashing the plan - while
the backtest engine still carried the pre-change copy.

Only the superproject has every submodule at once, so only the superproject can
check agreement between them.

Comparison is by **git blob object id**, not by reading files off disk. That is
deliberate. These repositories carry different `.gitattributes` rules - some
paths are `-text` to keep hashed bytes portable, others are not - so the same
logical file can land on disk with different line endings in each checkout while
being identical in git. Comparing working-tree bytes reports that as drift and
sends the reader hunting a contract bug that does not exist. A blob id is the
content identity git itself uses, and it does not depend on anyone's
`core.autocrlf`.

This script only reads. It touches no protected canonical path.

    python scripts/validate_d_contract_parity.py
    python scripts/validate_d_contract_parity.py --if-present

`--if-present` is for a job that deliberately does not check out submodules. It
names precisely which checks it could NOT run and exits 0. A missing repository
is never reported as agreement: an unverifiable check is named, not passed.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]

BACKEND = REPO_ROOT / "backend"
BACKTEST = REPO_ROOT / "backtest-engine"
PIPELINE = REPO_ROOT / "data-pipeline"

BACKEND_STRATEGY_BOT = (
    "modules/backend-messaging/src/main/resources/contracts/strategy-bot/v1"
)
ROOT_BUNDLE = "db/flyway-ci-bundle"

problems: list[str] = []
unverifiable: list[str] = []
passed: list[str] = []


def _git(repo: Path, *args: str) -> str | None:
    """Run git in `repo`; None when it fails (missing path, missing rev, no repo)."""
    try:
        done = subprocess.run(
            ["git", "-C", str(repo), *args],
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError:
        return None
    return done.stdout.strip() if done.returncode == 0 else None


def is_repo(repo: Path) -> bool:
    return _git(repo, "rev-parse", "--git-dir") is not None


def blob_oid(repo: Path, rev: str, path: str) -> str | None:
    oid = _git(repo, "rev-parse", f"{rev}:{path}")
    return oid or None


def list_files(repo: Path, rev: str, directory: str) -> list[str] | None:
    out = _git(repo, "ls-tree", "-r", "--name-only", rev, f"{directory}/")
    if out is None:
        return None
    return sorted(line for line in out.splitlines() if line.strip())


def assert_mirrors(
    label: str,
    authority: tuple[Path, str, str],
    mirror: tuple[Path, str, str],
    strip: str = "",
) -> None:
    """Every file in `mirror` must have the same blob id as its namesake in `authority`.

    Extra files in `authority` are fine: a vendored copy may be a subset
    snapshot. A file in `mirror` with no counterpart is not - it means the copy
    carries content its owner never published.
    """
    a_repo, a_rev, a_dir = authority
    m_repo, m_rev, m_dir = mirror

    absent = [r for r in (a_repo, m_repo) if not is_repo(r)]
    if absent:
        names = ", ".join(r.name or str(r) for r in absent)
        unverifiable.append(f"{label}: not checked out ({names})")
        return

    mirrored = list_files(m_repo, m_rev, m_dir)
    if mirrored is None:
        unverifiable.append(f"{label}: cannot read {m_dir} at {m_rev} in {m_repo.name}")
        return
    if not mirrored:
        problems.append(f"{label}: {m_dir} is empty at {m_rev}, nothing to compare")
        return

    compared = 0
    for tracked in mirrored:
        name = tracked.rsplit("/", 1)[-1]
        owned = name[: -len(strip)] if strip and name.endswith(strip) else name
        theirs = blob_oid(a_repo, a_rev, f"{a_dir}/{owned}")
        if theirs is None:
            problems.append(
                f"{label}: {tracked} has no counterpart at {a_dir}/{owned} - "
                "the copy carries content its owner does not publish"
            )
            continue
        mine = blob_oid(m_repo, m_rev, tracked)
        if mine is None:
            problems.append(f"{label}: cannot resolve {tracked} at {m_rev}")
            continue
        if mine != theirs:
            problems.append(
                f"{label}: {name} differs from its owner\n"
                f"    {m_repo.name}/{tracked}  blob {mine}\n"
                f"    {a_repo.name}/{a_dir}/{owned}  blob {theirs}"
            )
            continue
        compared += 1

    passed.append(f"{label}: {compared} file(s) identical to {a_repo.name}/{a_dir}")


def assert_recorded_digests(label: str, repo: Path, rev: str, bundle_dir: str) -> None:
    """The digests a vendored bundle records must name files that exist in it.

    The bytes themselves are verified inside each repository's own CI, which runs
    `sha256sum -c` in a real checkout. What only the superproject can add is that
    the record and the directory have not diverged in membership.
    """
    if not is_repo(repo):
        unverifiable.append(f"{label}: not checked out ({repo.name})")
        return

    recorded_blob = _git(repo, "cat-file", "-p", f"{rev}:{bundle_dir}.sha256")
    if recorded_blob is None:
        problems.append(f"{label}: {bundle_dir}.sha256 is missing at {rev}")
        return

    recorded: set[str] = set()
    for line in recorded_blob.splitlines():
        stripped = line.strip()
        if not stripped:
            continue
        _, _, name = stripped.partition(" ")
        recorded.add(name.strip().lstrip("*"))

    present = list_files(repo, rev, bundle_dir)
    if present is None:
        problems.append(f"{label}: cannot read {bundle_dir} at {rev}")
        return
    present_names = {p.rsplit("/", 1)[-1] for p in present}

    if not recorded:
        problems.append(f"{label}: {bundle_dir}.sha256 records no digests")
        return

    missing = sorted(recorded - present_names)
    unrecorded = sorted(present_names - recorded)
    for name in missing:
        problems.append(f"{label}: {name} is recorded but absent from {bundle_dir}")
    for name in unrecorded:
        problems.append(f"{label}: {name} is present in {bundle_dir} but not recorded")

    if not missing and not unrecorded:
        passed.append(f"{label}: {len(recorded)} vendored file(s) recorded and present")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--if-present",
        action="store_true",
        help="allow checks whose repository is not checked out, naming each one",
    )
    parser.add_argument(
        "--rev",
        default="HEAD",
        help=(
            "revision to inspect in each repository (default HEAD). Because the "
            "comparison reads git objects rather than the working tree, a branch "
            "can be checked without checking it out, e.g. --rev origin/develop."
        ),
    )
    args = parser.parse_args()
    rev = args.rev

    # B owns strategy-bot.v1; the backtest engine vendors a copy so its tests can
    # run without the backend checked out. This is the drift that actually bit us.
    assert_mirrors(
        "strategy-bot.v1 fixtures (B -> backtest-engine)",
        (BACKEND, rev, BACKEND_STRATEGY_BOT),
        (BACKTEST, rev, "tests/fixtures/contracts/strategy-bot/v1"),
    )

    # Membership of each vendored central-migration record. The bytes are checked
    # inside each repository's own CI; what only the superproject sees is whether
    # the two repositories vendor the same set.
    assert_recorded_digests(
        "data-pipeline vendored bundle",
        PIPELINE,
        rev,
        "db/migration-contributions/fixtures/central-migration",
    )
    assert_recorded_digests(
        "backtest-engine vendored bundle",
        BACKTEST,
        rev,
        "db/migration-contributions/fixtures/central-migration",
    )

    for line in passed:
        print(f"ok    {line}")
    for line in unverifiable:
        print(f"skip  {line}")
    for line in problems:
        print(f"FAIL  {line}", file=sys.stderr)

    if problems:
        print(f"\n{len(problems)} contract parity problem(s).", file=sys.stderr)
        return 1

    if unverifiable and not args.if_present:
        print(
            f"\n{len(unverifiable)} check(s) could not run because a repository is not "
            "checked out.\nRun `git submodule update --init`, or pass --if-present to "
            "allow it explicitly.",
            file=sys.stderr,
        )
        return 2

    if not passed:
        print("\nNo check ran at all; that is not agreement.", file=sys.stderr)
        return 2

    tail = f", {len(unverifiable)} not verified." if unverifiable else "."
    print(f"\n{len(passed)} parity check(s) passed{tail}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
