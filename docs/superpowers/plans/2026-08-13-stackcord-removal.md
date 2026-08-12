# Stackcord Removal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove Stackcord from the repository and this workstation while preserving project-owned collaboration and product-authority safeguards.

**Architecture:** Active project rules use Git, GitHub review, launch-status, and repository tests directly. Stackcord-only state is deleted; generic local workspace and UI baseline data remain. Codex registration is removed before cache and CLI deletion so Stackcord cannot be reloaded.

**Tech Stack:** PowerShell, Git, GitHub Actions, YAML, Codex TOML configuration.

## Global Constraints

- Preserve historical plans, proposals, evidence, and session history.
- Do not mix this change with PR #508 or its worktree.
- Preserve `.harness/local/` ignored operational data and `.harness/ui/baselines/`.
- Preserve the four configured product authorities and protected-kind rules.

---

### Task 1: Repository removal contract

**Files:**
- Create: `scripts/test-external-coordination-removal.ps1`
- Modify: `.github/workflows/ci.yml`

- [ ] Write a test that rejects Stackcord references in active paths and rejects Stackcord-only state files.
- [ ] Run it and verify that the current repository fails.
- [ ] Add the test to the schema-and-coordination CI job.

### Task 2: Replace active repository integration

**Files:**
- Modify: `AGENTS.md`, `CLAUDE.md`, `README.md`
- Modify: `docs/collaboration-policy.md`, `docs/development-start-guide.md`, `docs/launch-readiness-plan.md`
- Modify: `.agents/skills/use-project-harness/SKILL.md`, `.agents/skills/use-project-harness/references/fallback.md`
- Modify: `scripts/initialize-local-harness.ps1`, `scripts/test-local-harness.ps1`, `scripts/verify-collaboration-policy.ps1`, `scripts/verify-foundation-evidence.mjs`, `scripts/validate-proposal-boundary.mjs`
- Create: `docs/product-authorities.yaml`
- Delete: Stackcord-only active `.harness` files and `scripts/test-completed-work-recovery.ps1`

- [ ] Replace Stackcord runtime rules with direct Git/GitHub rules.
- [ ] Move authority configuration to `docs/product-authorities.yaml`.
- [ ] Delete Stackcord-only active state.
- [ ] Run removal and collaboration tests.

### Task 3: Remove workstation installation

**Files:**
- Modify: `C:/Users/SSAFY/.codex/config.toml`
- Delete: `C:/Users/SSAFY/.codex/plugins/cache/stackcord/`
- Delete: `C:/Users/SSAFY/.local/bin/stackcord.exe`

- [ ] Remove marketplace, plugin, and hook records from Codex configuration.
- [ ] Remove plugin cache and standalone CLI.
- [ ] Verify no active registration or executable remains.

### Task 4: Publish independently

**Files:** repository changes from Tasks 1-2.

- [ ] Run the complete relevant verification suite and `git diff --check`.
- [ ] Commit and push `chore/remove-stackcord`.
- [ ] Open a separate draft PR that quotes the product-authority instruction.
