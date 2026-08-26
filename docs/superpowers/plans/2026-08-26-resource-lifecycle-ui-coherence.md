# Resource Lifecycle and UI Coherence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Separate strategy drafts from released bots, replace append-only lists with real pagination, standardize core resource UI states, and leave a minimal intelligible local demonstration dataset.

**Architecture:** Extend the existing cursor API with a resource-kind constraint and keep cursor snapshots opaque. StrategyHome owns a small page cache and renders exactly one page; shared visual/state primitives and Signal Studio tokens provide a centered, responsive surface without changing strategy semantics.

**Tech Stack:** Java 21, Spring Boot, jOOQ, PostgreSQL, React 19, TypeScript, Vitest, Testing Library, Vite, Docker Compose.

**Spec:** `docs/superpowers/specs/2026-08-26-resource-lifecycle-ui-coherence-design.md`

## Global Constraints

- Never change immutable released strategy meaning or compiled plans.
- Never fabricate strategy, bot, backtest, or market data.
- PRO remains unavailable.
- Destructive local cleanup must target the developer account and exact retained IDs only.
- Every behavior change follows red-green-refactor.

---

### Task 1: Draft-only strategy library contract

**Files:**
- Modify: `backend/apps/backend-api/src/main/java/com/idea2strategy/backend/api/strategy/StrategyLibraryController.java`
- Modify: `backend/modules/backend-application/src/main/java/com/idea2strategy/backend/application/strategy/StrategyLibraryQueryService.java`
- Modify: `backend/modules/backend-application/src/main/java/com/idea2strategy/backend/application/strategy/StrategyLibraryQueryPort.java`
- Modify: `backend/modules/backend-persistence/src/main/java/com/idea2strategy/backend/persistence/strategy/StrategyLibraryJooqQueryAdapter.java`
- Test: existing strategy library controller, service, and persistence tests

**Interfaces:**
- Consumes: optional wire value `kind=draft|released|package|template`.
- Produces: cursor-stable `StrategyLibraryPage` containing only the requested kind.

- [x] Add failing controller/service/persistence tests for `kind=draft`, invalid kind, and page-two cursor stability.
- [x] Run focused tests and confirm failures describe the absent filter.
- [x] Thread the kind constraint through controller, service, port, and adapter.
- [x] Run focused and backend module tests.
- [x] Commit the backend change.

### Task 2: Strategy resource presentation and pagination

**Files:**
- Modify: `ui/src/api/strategies.ts`
- Modify: `ui/src/views/StrategyViews.tsx`
- Modify: `ui/src/App.tsx`
- Test: `ui/src/StrategyApiView.test.tsx`
- Test: `ui/src/App.test.tsx`

**Interfaces:**
- Consumes: `StrategyLibraryClient.list(limit, cursor, signal, kind)`.
- Produces: draft-only strategy home and `이전 / N페이지 / 다음` navigation with cached previous pages.

- [x] Replace the append-only test with failing one-page-at-a-time pagination tests.
- [x] Add failing tests for draft filter requests and truthful released-item fallback behavior.
- [x] Implement cursor page caching, page replacement, accessible pagination, and resource-kind presentation.
- [x] Wire released fallback rows to bot operations by immutable bot ID.
- [x] Run focused UI tests and refactor only after green.
- [x] Commit the UI behavior change.

### Task 3: Core visual and remote-state consistency

**Files:**
- Modify: `ui/src/styles/base.css`
- Modify: `ui/src/styles/balanced.css`
- Modify: `ui/src/views/StrategyViews.tsx`
- Modify only where audit proves inconsistency: `ui/src/views/BotsView.tsx`, `ui/src/views/BacktestLiveView.tsx`, shared state components
- Test: existing App, Strategy, Bots, Backtest, Competition, Account, and Operator view tests

**Interfaces:**
- Consumes: existing tokens and shared `LoadingState`, `EmptyState`, `ErrorState`, `PageHeading` components.
- Produces: centered responsive pages and consistent loading, first-use empty, filtered empty, stale-error, forbidden, and retryable-error presentation.

- [x] Add failing structural tests for centered width, responsive controls, and state-specific actions.
- [x] Consolidate the final Signal Studio overrides so later duplicate rules cannot reintroduce left alignment.
- [x] Improve strategy list hierarchy, row affordances, pagination, and narrow layout.
- [x] Audit bots/backtests and apply only missing shared-state/layout rules.
- [x] Run the complete UI suite, typecheck, and production build.
- [x] Commit the visual/state change.

Product-judgment additions:

- [x] Remove duplicate primary actions and move secondary/destructive strategy actions into an overflow menu.
- [x] Replace narrow horizontal-scroll navigation with fixed five-destination navigation.
- [x] Remove unsourced bot row fields and opaque backtest run identifiers from primary labels.
- [x] Give no-performance and empty-competition states a valid next action.
- [x] Separate the operator top bar from the customer product boundary.
- [x] Keep unavailable email delivery visible but truthfully disabled.

### Task 4: Minimal local demonstration dataset

**Files:**
- Create: `local/evidence/resource-cleanup-before.txt` (gitignored)
- Create: `local/evidence/resource-cleanup-after.txt` (gitignored)
- Modify data only: local PostgreSQL developer-account rows

**Interfaces:**
- Consumes: exact developer account, strategy, bot, and run IDs established by read-only queries.
- Produces: the four named lifecycle examples from the design, with unrelated domains untouched.

- [x] Create a PostgreSQL custom-format backup before cleanup and retain the exact target/count guard used by the transaction.
- [x] Inspect foreign-key dependencies and prepare a transaction that fails closed on unexpected counts.
- [x] Rename retained resources and delete only duplicate runs/bots/strategies plus their dependent execution artifacts.
- [x] Create the incomplete draft through the product API, not by inventing a document row.
- [x] Query final counts, names, statuses, and relationships after cleanup.

### Task 5: Full-stack verification and delivery

**Files:**
- Modify only if verification exposes a reproducible defect, always with a failing test first.

**Interfaces:**
- Consumes: rebuilt Docker services and retained real local data.
- Produces: browser evidence, clean tests, secret scan, commits, and pushed component/root branches.

- [x] Rebuild affected Docker services and wait on health checks.
- [x] Verify strategy loading, empty/filter/error state tests, draft opening, next/previous pagination, bot selection, and backtest details in the actual browser.
- [x] Run backend focused tests and the full UI suite, typecheck, and build.
- [x] Run repository secret scanning and inspect staged diff for credentials.
- [ ] Commit/push submodules, update root pointers/docs, commit/push the root branch.
- [ ] Confirm remote branch hashes match local hashes and report the URL and test account.
