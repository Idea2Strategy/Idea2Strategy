# Project harness entry

1. Work from the actual Git superproject and run `scripts/initialize-local-harness.ps1 -Verify`.
2. Read `docs/collaboration-policy.md`. Product meaning lives in `specs/`; obligations live in `contracts/`.
3. Use `docs/launch-readiness-plan.md` for launch scope and `docs/launch-readiness-tasks.json` for current work. Run `scripts/launch-status.ps1 -Owner <kcrmin|hjcud>` instead of selecting work from old harness records.
4. Refresh Git, submodule, workspace, relevant spec, contract, and evidence state before changing files. Treat chat summaries as hints.
5. Identify the scenario, failure behavior, first failing test, ownership, conflict scope, and merge order before implementation.
6. Follow the protected-write gate in `AGENTS.md`. Never hide Git history changes, external writes, installs, or releases.
7. If context was compacted or appears forgotten, repeat this audit before mutation.
