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
4. Run `scripts/verify-harness-consistency.ps1`, `git status --short --branch`, and `git submodule status`. Inspect the target submodule's branch, upstream, and dirty state without changing them.
5. Resolve the contributor against the `owners` block of `docs/launch-readiness-tasks.json`, which is the current source of truth and assigns **repositories** rather than A–F letters. **Two contributors are active as of 2026-08-09**: `kcrmin` (root, `backend`, `trading-engine`, `data-pipeline` — the platform) and `hjcud` (`backtest-engine`, `ui` — the user journey). `pjy008008` is no longer assigned; their cards moved to `kcrmin`, except `INT07`, which went to `hjcud` because it depends on `INT03` and keeping the chain with one person removes a handoff. If a supplied A–F letter or an older table disagrees, say so and use the ledger's `owners` block — it wins.

   **Then tell the contributor what they may do without waiting for anyone.** This is the part that was costing whole days:
   - They move the **root gitlink for their own submodules** themselves — see `may_move_gitlinks`. They do not wait for another person to publish their merged work. If the gitlink is one the Flyway bundle pins, the same commit must run `scripts/refresh-flyway-ci-bundle.ps1`; the tracked hook refuses the commit otherwise, so this cannot be forgotten.
   - They write their own `docs/evidence/**` files.
   - Only `exclusive_paths` (`db/schema.dbml`, `compose.back.yml`, `compose.front.yml`) belong to one person, because those are the paths that actually collided.

   **And what they must wait for, which is not the same as skipping it.** The `serialized_resources` block lists what two people cannot use at once: the Development release workflow, the BASIC queue and its single backtest worker, the operator account, and the database bootstrap. These are genuine waits — the environment has one of each. Claim one by leaving a line on the root issue named in `claim_location` and leave another line when finished. Never work around a serialized resource by taking a second copy of it.
6. If an issue number or URL was supplied and an authenticated task provider is available, refresh that live issue and its prerequisites. Never treat a cached issue snapshot as live. If no provider is available, clearly say that live assignment state is unverified.
7. Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/launch-status.ps1 -Owner <owner>` and take the task it names. The ledger `docs/launch-readiness-tasks.json` is the dependency graph and its checks are the definition of done, so do not pick by judgment when the script can name the task. If it reports the owner has nothing ready, say who they are waiting on and stop — do not invent work. Refuse anything in the Pro scope (B09, B10, B13, C15, F06) — it is out of v1.0. Do not select a protected canonical change without the required authority.
8. Respond briefly with:
   - confirmed repository and submodule state;
   - the repositories this contributor may change, and the ones they may not;
   - the one recommended next task, cited by its section number in the launch readiness plan;
   - target repository, expected branch name, prerequisites, acceptance evidence, and first test;
   - any blocker that must be resolved before implementation;
   - whether a dedicated worktree is needed. If the target submodule is not at the root gitlink, or another session may share this checkout, say to create one — concurrent sessions share one HEAD and will hijack each other's branches.
9. End by telling the contributor they can say `해줘` to implement that one unit. Implementation must happen in the target repository's feature branch and later go through a pull request to that repository's `develop` branch.

Do not ask again about decisions already settled in approved specifications or contracts. Ask only when a genuinely unresolved choice changes product behavior or the safe Git path.
