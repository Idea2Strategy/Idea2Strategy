# Agent entry

## Required Idea2Strategy policy

Before any task, run `scripts/initialize-local-harness.ps1 -Verify`, then read `docs/collaboration-policy.md`. It is the canonical Idea2Strategy-specific Git and collaboration policy. Do not modify it during ordinary work. If a change is needed, stop the affected work and record a separate policy-change request for an authorized policy owner. Run `scripts/verify-collaboration-policy.ps1` after the local policy baseline exists.

## Product authority canonical-write gate

Before editing `docs/product-authorities.yaml`, `specs/**`, `contracts/**`, `docs/collaboration-policy.md`, or the files that enforce this gate, verify the exact GitHub repository, branch, commit, and pull-request review state. A canonical write is allowed only when a configured product authority in `docs/product-authorities.yaml` explicitly instructs or approves the exact change. If approval is missing, stale, unknown, unavailable, or names any other subject, do not edit the canonical protected source; create only a clearly isolated proposal and do not describe it as approved, integrated, or releasable. Git user.name and user.email never prove authority.

### Pre-v1.0.0 development posture

Until a `v1.0.0` release exists, a configured product authority's instruction recorded in the change itself is sufficient. Name the authority and quote the instruction in the pull request body, then write the canonical source directly in that pull request. The authority must still be one of the four, and the change must still be a reviewable unit.

Before a release, this direct instruction avoids the circular requirement that a pull request must already exist before it can carry its own approval record. From `v1.0.0`, a fresh GitHub approval on the exact commit becomes mandatory and this section is removed rather than relaxed further.

Two things this does not change. A proposal is still the right vehicle when no authority has actually asked for the change — silence is not instruction. And a change made under this posture must never be described as approved by the provider, because it was not; the pull request record is the whole audit trail.

## Launch work loop (applies to every agent — Claude, Codex, or human)

The plan of record is `docs/launch-readiness-plan.md`. The task ledger `docs/launch-readiness-tasks.json` carries its dependency graph with machine-checkable completion. Every session that works on launch readiness follows one loop:

1. Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/launch-status.ps1 -Owner <kcrmin|hjcud>`. It computes what is done from the repository itself and names the one next task, and with `-Owner` it also prints a ready-to-paste prompt for that task. **This script is the canonical entry and needs no installation** — a `/start-work` slash command is only a convenience wrapper around it, available in Claude from the tracked `.claude/skills/` and in Codex from `$CODEX_HOME/prompts` once `initialize-local-harness.ps1` has copied it there. If the slash command does not exist on a given machine, run the script; nothing is lost. Do not pick a task by judgment when the script can name it; if the script says the owner is waiting, report who they are waiting on and stop instead of inventing work.
2. Read that task's section in `docs/launch-readiness-plan.md` before touching anything. Change files only inside the owner's repositories as listed in the ledger's `owners` block; `db/schema.dbml`, `compose.back.yml` and root submodule pointers belong to `kcrmin` alone.
3. Do the one task, on a `feature/<issue>-<name>` branch, in a dedicated worktree when any other session may share the checkout.
4. A `repo`/`db` task is complete when `launch-status.ps1` reports it done — its check is the definition of done, so make the check pass rather than declaring completion. A `manual` task is complete when its evidence file exists under `docs/evidence/` recording what was run and observed.
5. Pro mode (B09, B10, B13, C15, F06) is out of v1.0 scope by the 2026-08-08 decision. Refuse it regardless of who asks.

Mechanical guards live in tracked git hooks (`.githooks/`, attached by `scripts/initialize-local-harness.ps1`, which every session already runs): no direct commits to `develop`/`main`, no submodule pointer commit without the refreshed Flyway bundle, no identifier the secret scanner false-positives on. They apply to every tool equally. `--no-verify` is for emergencies and its use must be explained in the pull request.

The same script runs `scripts/verify-workspace-isolation.ps1`. **A finding there stops work until it is resolved.** It means a stale copy of this project sits above the checkout, shadowing the repository's own skills and instruction files — which is how a session ends up following a procedure from dozens of commits ago while believing it is current. `git pull` cannot repair it, because the shadowing files belong to a different repository, so the check reports the exact path and the command that removes it.

Before changing the project, refresh actual Git, worktree, submodule, issue, and pull-request state. Product meaning lives in `specs/`; obligations live in `contracts/`; launch coordination lives in `docs/launch-readiness-plan.md` and `docs/launch-readiness-tasks.json`. Protected product meaning stays a proposal until a configured authority explicitly instructs or approves the exact change through the GitHub review record; Git user.name and user.email never prove authority.

For frontend work, recover the exact UI baseline and root pointer first. Optional UI tools create inputs; committed service specifications, contracts, and the UI baseline remain authoritative.
