# Uncommitted Integration and Backtest Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve, verify, push, and merge every repository-owned uncommitted change, then reproduce the user's exact backtest and prevent the same failure classification or execution defect from recurring.

**Architecture:** Treat each Git submodule as an independent review unit based on its current `origin/develop`, merge those first, and then integrate the root cleanup with the merged gitlinks. Reproduction uses the immutable stored strategy release and run configuration from the local database/API; prevention is added only after the failure boundary is proven and is locked by focused and end-to-end tests.

**Tech Stack:** Git/GitHub CLI, PowerShell, Java 21/Gradle, Python 3.12/pytest, TypeScript/React/Vitest, Docker Compose, PostgreSQL

**Spec:** User request in the active Codex task; canonical behavior remains under `specs/`, `contracts/`, and `db/schema.dbml`.

## Global Constraints

- Preserve all repository-owned local changes and do not reset, stash, or discard them.
- Do not commit personal application PDFs, rendered pages, or generated `.harness/local/tmp` command payloads.
- Base merge candidates on the latest `origin/develop`; never merge the August 13 branches wholesale over newer work.
- Merge submodule repositories before updating and merging root gitlinks.
- Reproduce the backtest from immutable stored inputs before changing behavior.
- A valid no-signal run completes with zero trades; `FAILED` is reserved for technical execution failure.

---

### Task 1: Classify and preserve local changes

**Files:**
- Inspect: root and `backend/`, `backtest-engine/`, `data-pipeline/`, `trading-engine/`, `ui/`
- Exclude: `.harness/local/tmp/**`, `tmp/pdfs/**`

**Interfaces:**
- Consumes: Git index, working tree, current remote refs
- Produces: exact per-repository commit sets with no unclassified repository-owned file

- [ ] **Step 1:** Fetch and prune every repository remote.
- [ ] **Step 2:** Record staged, unstaged, and untracked paths in every repository.
- [ ] **Step 3:** Inspect every diff and separate source/docs from local generated artifacts.
- [ ] **Step 4:** Run secret scanning over the selected commit content.

### Task 2: Integrate submodule changes

**Files:**
- Modify: `backend/modules/backend-persistence/src/main/java/com/idea2strategy/backend/persistence/strategy/BacktestDataCoverageJooqQueryAdapter.java`
- Modify: `backend/scripts/test-container-contracts.sh`
- Delete: `backend/proposals/backtest-lane-producers.md`
- Modify: `backtest-engine/conformance/README.md`
- Delete: `backtest-engine/db/migration-contributions/change-requests/2026-08-02-backtest-run-input-pins.md`
- Modify: five `data-pipeline` package/docstring files currently reported by Git
- Modify: `ui/docs/RUNTIME_DATA_READINESS.md`, `ui/index.html`, `ui/src/App.test.tsx`
- Delete: `ui/docs/evidence/INT10.md`

**Interfaces:**
- Consumes: classified local diffs from Task 1 and latest child `origin/develop`
- Produces: one tested, pushed, merged pull request per affected submodule

- [ ] **Step 1:** Commit the exact preserved diff on the existing local branch so no work remains only in a worktree.
- [ ] **Step 2:** Create an integration branch from current `origin/develop` and cherry-pick the preserved commit.
- [ ] **Step 3:** Resolve conflicts by retaining current product behavior and applying only the intended cleanup.
- [ ] **Step 4:** Run each repository's focused tests, then its required build/static checks.
- [ ] **Step 5:** Push, open a pull request to `develop`, wait for checks, and merge.

### Task 3: Integrate the root cleanup

**Files:**
- Modify/Delete: all currently tracked root changes reported by `git status`
- Add: `docs/project-decisions.md`
- Add: `docs/evidence/INT04-release-31323280012-readonly-check.md`
- Add: this plan
- Update: affected submodule gitlinks to their merged `develop` commits

**Interfaces:**
- Consumes: merged submodule commits from Task 2
- Produces: one root pull request based on latest `origin/develop`

- [ ] **Step 1:** Stage all repository-owned root paths while leaving excluded local artifacts untracked.
- [ ] **Step 2:** Commit the preserved root diff on the existing local branch.
- [ ] **Step 3:** Create a branch from latest `origin/develop` and cherry-pick the cleanup commit.
- [ ] **Step 4:** Resolve conflicts without reverting newer backtest/product work; refresh generated manifests only through repository scripts.
- [ ] **Step 5:** Run root contract, Flyway, Docker configuration, and secret-scan checks.
- [ ] **Step 6:** Push, open a pull request to `develop`, wait for checks, and merge.

### Task 4: Reproduce the exact backtest

**Files:**
- Inspect: PostgreSQL backtest/strategy/bot records and service logs
- Test: existing local integration scripts and backtest-engine focused tests

**Interfaces:**
- Consumes: stored strategy release, compiled plan, run period, capital, fee policy, execution policy, and pinned datasets
- Produces: a repeat run whose immutable input fingerprint and result metrics can be compared to the user's run

- [ ] **Step 1:** Locate the user's run named `THE ULTIMATE STRATEGY` and export its immutable input identifiers.
- [ ] **Step 2:** Confirm the exact release document, date range, initial capital, costs, execution limits, and dataset hashes.
- [ ] **Step 3:** Submit the same request on merged `develop` without changing the stored strategy.
- [ ] **Step 4:** Compare status transitions, trade count, fees, return, warnings, and worker logs field by field.
- [ ] **Step 5:** Trace the first divergent or erroneous boundary from API request through persistence, queue, engine, and result projection.

### Task 5: Prevent recurrence and merge the fix

**Files:**
- Modify/Test: exact owning repository identified by Task 4

**Interfaces:**
- Consumes: proven root cause and minimal failing fixture from Task 4
- Produces: merged regression protection that preserves valid zero-trade completion semantics

- [ ] **Step 1:** Add a focused test that reproduces the proven defect and verify it fails for the expected reason.
- [ ] **Step 2:** Implement the smallest correction at the owning boundary.
- [ ] **Step 3:** Verify the focused test, related suite, and real repeat backtest.
- [ ] **Step 4:** Push, open a pull request, wait for checks, merge, and update the root gitlink if required.
- [ ] **Step 5:** Report exact run IDs, before/after evidence, commits, pull requests, and any intentionally untracked local artifacts.
