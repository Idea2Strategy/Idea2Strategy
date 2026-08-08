---
name: start-work
description: Restore Idea2Strategy repository context and identify one dependency-ready task for the named contributor after clone or pull.
argument-hint: <name-or-GitHub-ID> [issue-number-or-goal]
disable-model-invocation: true
---

# Start Idea2Strategy work

The contributor supplied these arguments:

`$ARGUMENTS`

Perform an orientation pass only. Do not implement, create or switch branches, pull, commit, push, merge, change external issues, or move submodule pointers during this invocation.

1. Find the root Git superproject. If the session started inside a submodule, move only the command working directory to the root for inspection.
2. Run `scripts/initialize-local-harness.ps1 -Verify` from the root. It attaches the tracked git hooks, installs the Codex prompt, and runs `scripts/verify-workspace-isolation.ps1`. **If the isolation check reports a finding, stop and report it before anything else** — a stale copy of this project above the checkout shadows the repository's own skills and instruction files, so the procedure you are reading may not be the current one, and `git pull` cannot fix it because the shadowing files belong to a different repository. Give the contributor the remedy command the check printed.
3. Read `AGENTS.md`, `.harness/entry.md`, `docs/collaboration-policy.md`, `docs/development-start-guide.md`, `docs/backend-team-allocation.md` §0, and **`docs/launch-readiness-plan.md`**. The launch readiness plan is the current plan of record: take the next task from it, and use `docs/backend-implementation-master-checklist.md` only for the A90/A91 and INT01~INT12 wording it references.
4. Run `stackcord status --json`, `git status --short --branch`, and `git submodule status`. Inspect the target submodule's branch, upstream, and dirty state without changing them.
5. Resolve the contributor against `docs/backend-team-allocation.md` §0, which assigns **repositories** rather than A–F letters. Three contributors are active: `kcrmin` (root + `backend`), `pjy008008` (`data-pipeline`, `trading-engine`), `hjcud` (`backtest-engine`, `ui`). If the contributor is one of the inactive names, or a supplied A–F letter disagrees with the repository table, say so and continue using the repository table — it wins.
6. If an issue number or URL was supplied and an authenticated task provider is available, refresh that live issue and its prerequisites. Never treat a cached issue snapshot as live. If no provider is available, clearly say that live assignment state is unverified.
7. Run `pwsh scripts/launch-status.ps1 -Owner <owner>` and take the task it names. The ledger `docs/launch-readiness-tasks.json` is the dependency graph and its checks are the definition of done, so do not pick by judgment when the script can name the task. If it reports the owner has nothing ready, say who they are waiting on and stop — do not invent work. Refuse anything in the Pro scope (B09, B10, B13, C15, F06) — it is out of v1.0. Do not select a protected canonical change without the required authority.
8. Respond briefly with:
   - confirmed repository and submodule state;
   - the repositories this contributor may change, and the ones they may not;
   - the one recommended next task, cited by its section number in the launch readiness plan;
   - target repository, expected branch name, prerequisites, acceptance evidence, and first test;
   - any blocker that must be resolved before implementation;
   - whether a dedicated worktree is needed. If the target submodule is not at the root gitlink, or another session may share this checkout, say to create one — concurrent sessions share one HEAD and will hijack each other's branches.
9. End by telling the contributor they can say `해줘` to implement that one unit. Implementation must happen in the target repository's feature branch and later go through a pull request to that repository's `develop` branch.

Do not ask again about decisions already settled in approved specifications or contracts. Ask only when a genuinely unresolved choice changes product behavior or the safe Git path.
