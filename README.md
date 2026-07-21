# Idea2Strategy

Idea2Strategy is an early-stage virtual trading bot SaaS project. Product discovery is still in progress, so repository contents should not be treated as a finalized specification.

## Repository structure

- `ui/`: reference UI prototype maintained as the `Idea2Strategy/Idea2Strategy-ui` Git submodule
- Root repository: product context, contracts, orchestration, and cross-repository coordination

The current UI is exploratory. Its UX, copy, visual design, and implementation architecture may be substantially revised or replaced.

## Clone with the UI

```bash
git clone --recurse-submodules https://github.com/Idea2Strategy/Idea2Strategy.git
```

For an existing clone:

```bash
git submodule update --init --recursive
```

Initialize and verify the per-user local harness workspace:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/initialize-local-harness.ps1 -Verify
```

The shared skeleton lives under `.harness/local/`; generated artifacts, temporary files, caches, logs, dbdiagram proposals, and user-specific project records stored there are never committed.

<!-- stackcord:begin -->
## Project harness

Ask your AI assistant what to do next. It will read `.harness/entry.md`, inspect actual Git state, and continue from canonical specs and contracts.

If the project uses an independent editable UI baseline, it lives in a declared `ui/` directory or submodule. External mockups can be inspected, brought into that workspace, edited normally, and committed before frontend implementation is bound to the exact baseline.
<!-- stackcord:end -->

## Collaboration policy

Before contributing, read [`docs/collaboration-policy.md`](docs/collaboration-policy.md). It defines the Idea2Strategy-specific GitHub/GitLab boundaries, policy ownership, local Jira record, dbdiagram operation, and remote distribution rules. Stackcord remains the source of truth for its common recovery, coordination, planning, and verification procedures.
