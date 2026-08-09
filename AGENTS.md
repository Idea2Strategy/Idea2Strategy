# Agent entry

## Required Idea2Strategy policy

Before any task, run `scripts/initialize-local-harness.ps1 -Verify`, then read `docs/collaboration-policy.md` in addition to the Stackcord entry below. It is the canonical Idea2Strategy-specific Git and collaboration policy. Do not modify it during ordinary work. If a change is needed, stop the affected work and record a separate policy-change request for the authorized policy document owner. Run `scripts/verify-collaboration-policy.ps1` after the local policy baseline exists.

## Product authority canonical-write gate

Before editing `.harness/governance.yaml`, `specs/**`, `contracts/**`, `docs/collaboration-policy.md`, or the files that enforce this gate, run `stackcord governance check --json`. A canonical write is allowed only when a fresh provider observation for the exact repository, head commit, and protected fingerprint reports an approved authority that is one of the configured product authorities: `user:kcrmin`, `user:pjy008008`, `user:Juwon-Na`, or `user:hjcud`. If the result is missing, stale, unknown, unavailable, or names any other subject, you must not edit the canonical protected source; create only a clearly isolated proposal and do not describe it as approved, integrated, or releasable. Git user.name and user.email never prove authority.

### Pre-v1.0.0 development posture

Until a `v1.0.0` release exists, the paragraph above applies with one substitution: a configured product authority's instruction recorded in the change itself takes the place of the fresh provider observation. Name the authority and quote the instruction in the pull request body, then write the canonical source directly in that pull request. Everything else is unchanged — the authority must still be one of the four, and the change must still be a reviewable unit.

This exists because the observation can only be produced by a review approval on a pull request that already touches a protected path, and GitHub does not let a pull request author approve their own. Before a release that circularity has no cost worth paying: there is no published product meaning to protect, and treating an unverifiable local check as a stop sign blocked ordinary development instead of guarding anything. From `v1.0.0` the fresh-provider requirement becomes mandatory again, and this section is removed rather than relaxed further.

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

<!-- stackcord:begin -->
Before changing the project, read `.harness/entry.md` and refresh actual context. Product meaning lives in `specs/`; obligations live in `contracts/`; coordination state lives in `.harness/`. Protected product meaning stays a proposal until `stackcord governance check --json` confirms an assigned product authority through the selected Git review provider; Git user.name and user.email never prove authority.

When `workspace.ui` is declared, recover its exact baseline and root pointer before frontend work. Optional UI tools create inputs; committed service specifications, contracts, and the UI baseline remain authoritative.
<!-- stackcord:end -->
