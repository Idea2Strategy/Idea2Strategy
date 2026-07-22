# Idea2Strategy

Idea2Strategy is an early-stage virtual trading bot SaaS project. Product discovery is still in progress, so repository contents should not be treated as a finalized specification.

## Repository structure

- `ui/`: reference UI prototype maintained as the `Idea2Strategy/Idea2Strategy-ui` Git submodule
- Root repository: product context, contracts, orchestration, and cross-repository coordination

The current UI is exploratory. Its UX, copy, visual design, and implementation architecture may be substantially revised or replaced.

## Prerequisites

- Git
- PowerShell 5.1 or later on Windows
- Stackcord CLI 1.0.0 available as `stackcord`
- Access to the selected GitHub or GitLab repository

Both remotes use `develop` as their default collaboration branch. `main` is reserved for complete releases beginning with `v1.0.0`.

## Clone from GitHub with the UI submodule

```bash
git clone --recurse-submodules https://github.com/Idea2Strategy/Idea2Strategy.git
cd Idea2Strategy
```

For an existing clone:

```bash
git submodule update --init --recursive
```

## Clone from the monolithic GitLab mirror

```bash
git clone https://lab.ssafy.com/s15-webmobile2-sub1/S15P11B205.git
cd S15P11B205
```

The GitLab checkout contains `ui/` as ordinary tracked files and must not contain a nested `ui/.git` directory.

## Initialize collaboration

Run these commands from the cloned repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/initialize-local-harness.ps1 -Verify
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-collaboration-policy.ps1
stackcord context audit --root . --json
git status --short --branch
stackcord status --json
```

The initializer creates the ignored local workspace, policy-integrity baseline, and a non-secret reference to the configured product authority. It does not authenticate the current user and never overwrites an existing local owner record.

The shared skeleton lives under `.harness/local/`; generated artifacts, temporary files, caches, logs, dbdiagram proposals, and user-specific project records stored there are never committed. A fresh clone must remain clean after initialization.

`stackcord status` can report governance as `unknown` with a nonzero exit code until a fresh GitHub approval by the configured product authority is observed. This is the intended fail-closed state: ordinary unprotected work can proceed, but protected product, policy, business, contract, and governance changes remain blocked.

<!-- stackcord:begin -->
## Project harness

Ask your AI assistant what to do next. It will read `.harness/entry.md`, inspect actual Git state, and continue from canonical specs and contracts.

If the project uses an independent editable UI baseline, it lives in a declared `ui/` directory or submodule. External mockups can be inspected, brought into that workspace, edited normally, and committed before frontend implementation is bound to the exact baseline.
<!-- stackcord:end -->

## Collaboration policy

Before contributing, read [`docs/collaboration-policy.md`](docs/collaboration-policy.md). It defines the Idea2Strategy-specific GitHub/GitLab boundaries, policy ownership, local Jira record, dbdiagram operation, and remote distribution rules. Stackcord remains the source of truth for its common recovery, coordination, planning, and verification procedures.
