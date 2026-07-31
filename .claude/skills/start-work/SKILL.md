---
name: start-work
description: Restore Idea2Strategy repository context and identify one dependency-ready task for the named team member after clone or pull.
argument-hint: <A-F> <name> <GitHub-ID> [issue-number-or-goal]
disable-model-invocation: true
---

# Start Idea2Strategy work

The contributor supplied these arguments:

`$ARGUMENTS`

Perform an orientation pass only. Do not implement, create or switch branches, pull, commit, push, merge, change external issues, or move submodule pointers during this invocation.

1. Find the root Git superproject. If the session started inside a submodule, move only the command working directory to the root for inspection.
2. Run `scripts/initialize-local-harness.ps1 -Verify` from the root.
3. Read `AGENTS.md`, `.harness/entry.md`, `docs/collaboration-policy.md`, `docs/development-start-guide.md`, `docs/backend-team-allocation.md`, and the relevant section of `docs/backend-implementation-master-checklist.md`.
4. Run `stackcord status --json`, `git status --short --branch`, and `git submodule status`. Inspect the target submodule's branch, upstream, and dirty state without changing them.
5. Match the supplied letter, name, and GitHub ID against the committed team ownership table. If they conflict, stop and report the mismatch.
6. If an issue number or URL was supplied and an authenticated task provider is available, refresh that live issue and its prerequisites. Never treat a cached issue snapshot as live. If no provider is available, clearly say that live assignment state is unverified.
7. Identify exactly one task that belongs to the contributor, has satisfied hard prerequisites, and can be completed as one reviewable child issue in one repository. Do not select a protected canonical change without the required authority.
8. Respond briefly with:
   - confirmed repository and submodule state;
   - the contributor's ownership area;
   - the one recommended next child issue or checklist unit;
   - target repository, expected branch name, prerequisites, acceptance evidence, and first test;
   - any blocker that must be resolved before implementation.
9. End by telling the contributor they can say `해줘` to implement that one unit. Implementation must happen in the target repository's feature branch and later go through a pull request to that repository's `develop` branch.

Do not ask again about decisions already settled in approved specifications or contracts. Ask only when a genuinely unresolved choice changes product behavior or the safe Git path.
