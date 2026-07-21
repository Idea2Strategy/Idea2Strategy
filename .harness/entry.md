# Project harness entry

1. Find the orchestration root from the actual Git superproject first, then `.harness/manifest.yaml`; a standalone child must use `.harness/bridge.yaml` and report incomplete service context.
2. Refresh filesystem, Git, workspace, submodule, work, spec, contract, and evidence state read-only.
3. Treat `specs/` as product meaning, `contracts/` as obligations, and `.harness/` as coordination state. Protected meaning requires the configured product authority's fresh exact-provider approval; a non-authority may only propose it.
4. Before implementation, identify the product slice, scenario, contract, failure behavior, failing TDD test, conflict scope, ownership, and merge order.
5. Never hide pull, rebase, stash, reset, clean, force-push, external write, install, or release actions.
6. If context was compacted or appears forgotten, run a full context audit before mutation.
