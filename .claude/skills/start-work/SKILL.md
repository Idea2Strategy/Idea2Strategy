---
name: start-work
description: Restore Idea2Strategy repository context and identify one dependency-ready task for the named contributor.
argument-hint: <name-or-GitHub-ID> [issue-number-or-goal]
disable-model-invocation: true
---

# Start Idea2Strategy work

Use `$ARGUMENTS` only to identify the contributor and optional issue or goal.
This invocation is orientation-only: do not pull, switch branches, commit,
push, merge, change issues, or move submodule pointers.

1. Locate the root Git superproject.
2. Run `scripts/initialize-local-harness.ps1 -Verify`; stop if workspace
   isolation fails.
3. Read `AGENTS.md`, `docs/collaboration-policy.md`,
   `docs/development-start-guide.md`, `docs/launch-readiness-plan.md`, and
   `docs/launch-readiness-tasks.json`.
4. Inspect `git status --short --branch`, `git worktree list`, `git submodule
   status`, and the target submodule's branch/upstream/dirty state.
5. Resolve the contributor from the ledger's `owners` block. That block wins
   over old A-F assignments. Respect its `exclusive_paths`,
   `may_move_gitlinks`, and `serialized_resources` fields.
6. Refresh a supplied issue through authenticated GitHub access when possible;
   otherwise report live state as unverified.
7. Run `scripts/launch-status.ps1 -Owner <owner>` and select exactly the task it
   names. Do not invent work when the owner is waiting.
8. Report the repository state, allowed repositories, one next task, branch,
   prerequisites, acceptance evidence, first test, blockers, and whether a
   dedicated worktree is required.
9. Tell the contributor they can say `해줘` to implement that one unit.

Do not ask again about decisions already settled in specifications or contracts.
