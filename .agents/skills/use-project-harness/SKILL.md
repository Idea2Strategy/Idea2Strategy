---
name: use-project-harness
description: Use when starting, continuing, changing, coordinating, recovering, or releasing work in this repository.
---

# Use Project Harness

Treat the user's natural-language request as the entry point. Do not require them to memorize commands or edit `.harness/`.

## Recover current state

1. Resolve the root superproject.
2. Run `scripts/initialize-local-harness.ps1 -Verify`.
3. Read `docs/collaboration-policy.md`, `.harness/entry.md`, and only the specifications and contracts relevant to the request.
4. Inspect `git status --short --branch`, `git submodule status`, and the target repository's branch, upstream, and dirty state.
5. For launch work, run `scripts/launch-status.ps1 -Owner <owner>` and use `docs/launch-readiness-tasks.json` as the dependency ledger. Do not invent a task when the ledger says the owner is waiting.

Repository evidence wins over chat history. `specs/` owns product meaning; `contracts/` owns service commitments, non-goals, failure behavior, interfaces, and data obligations. From a child repository, resolve the actual orchestration root before making service-wide claims.

## Protect canonical meaning

`.harness/product-authorities.yaml` lists the protected paths and authorities: `user:kcrmin`, `user:pjy008008`, `user:Juwon-Na`, and `user:hjcud`. Git user.name and user.email never prove authority.

Before `v1.0.0`, a protected canonical change requires an explicit instruction from one listed authority recorded in the change. From `v1.0.0`, it requires pull-request approval by at least one listed authority. If the requirement is absent, you must not edit the protected source; create a clearly isolated proposal and never present it as approved, integrated, or releasable.

## Execute safely

- Use TDD for behavior, bugs, contracts, migrations, and UI interactions.
- Keep work proportional. Use a dedicated worktree when another session may share a checkout.
- Respect repository and path ownership from the task ledger. Coordinate semantic overlap and merge order before parallel work.
- `db/schema.dbml` is canonical. Applied Flyway migrations are immutable; add a later migration.
- A submodule merge and root gitlink update are separate changes. Refresh the Flyway CI bundle whenever a pinned backend gitlink moves.
- When UI work is in scope, recover the declared UI baseline and exact root pointer first. External design tools are optional inputs, not canonical service state.
- Verify with repository scripts and relevant tests before claiming completion. Report changed files, observed results, and remaining integration work.

If context was compacted or sources disagree, repeat the recovery steps before mutation. Keep coordination internals out of normal user replies.
