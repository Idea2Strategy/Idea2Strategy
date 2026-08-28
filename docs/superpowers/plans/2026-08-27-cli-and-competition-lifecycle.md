# CLI and Competition Lifecycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver domain-complete strategy, bot, backtest, and competition CLI commands while repairing local competition creation and replacing schedule text fields with a three-milestone calendar.

**Architecture:** Keep the CLI as an authenticated HTTP client over existing service ownership: Backend owns strategies, bots, backtest creation, and competitions; Backtest API owns run queries/cancellation/deletion. Add evidence-preserving backtest soft deletion, reuse competition cancellation for room deletion, and seed the reviewed scoring catalog identically in local and AWS development environments.

**Tech Stack:** Java 21, Spring Boot, Jackson, Gradle, Python 3.12, FastAPI, SQLAlchemy/PostgreSQL, React 19, TypeScript, Vitest, Testing Library, PowerShell, Docker.

**Spec:** `docs/superpowers/specs/2026-08-27-cli-and-competition-lifecycle-design.md`

## Global Constraints

- Bot configuration is immutable after creation; CLI exposes read and stop only.
- Competition CLI has no update command.
- Deletes preserve audit and reproducibility evidence.
- No direct SQL from CLI, direct orders, external data fetching, arbitrary code, or secret output.
- Existing Flyway migrations are immutable; database changes use a new migration.
- Every production behavior starts with a failing test that names the regression it catches.

---

### Task 1: Restore the local scoring-policy catalog

**Files:**
- Modify: `scripts/dev.ps1`
- Modify: `scripts/test-development-database-bootstrap.ps1`
- Create: `scripts/test-local-scoring-seed-wiring.ps1`

**Interfaces:**
- Consumes: `proposals/development-scoring-template/artifacts/scoring-template-seed.sql`
- Produces: `Initialize-LocalStrategyData` that applies policy and scoring seeds idempotently before local use.

- [ ] Write a failing PowerShell behavior test that runs the local initialization against a temporary migrated PostgreSQL database and expects four selectable `development-2026-q3-v1` templates after two invocations.
- [ ] Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-local-scoring-seed-wiring.ps1` and verify it fails because `dev.ps1` never applies the scoring seed.
- [ ] Add the scoring seed as a required input, copy it into the local PostgreSQL container, and execute it with `ON_ERROR_STOP=1` before market manifest preparation.
- [ ] Re-run the new test and `node --test scripts/validate-development-scoring-seed.test.mjs`; verify both pass.

### Task 2: Add reviewed strategy instrument replacement

**Files:**
- Modify: `backend/modules/backend-application/src/test/java/com/idea2strategy/backend/application/strategy/DelegatedBasicStrategyEditServiceTest.java`
- Modify: `backend/modules/backend-application/src/main/java/com/idea2strategy/backend/application/strategy/DelegatedBasicStrategyEditService.java`
- Modify: `backend/apps/idea2strategy-cli/src/main/resources/idea2strategy-ai-tool-contract.json`

**Interfaces:**
- Consumes: `SET_GROUP_INSTRUMENTS { groupId, instrumentIds[] }`
- Produces: reviewed preview/apply support with full catalog validation and a human-readable diff.

- [ ] Add failing tests for replacing AAPL with AAPL+META, rejecting an empty set, rejecting duplicates, rejecting unknown IDs, and leaving other groups unchanged.
- [ ] Run the focused application test and verify failures name the unsupported operation.
- [ ] Implement replacement using the existing group lookup and catalog instrument identities, then pass the assembly validator.
- [ ] Re-run application tests and update the published tool contract vocabulary.

### Task 3: Expand CLI strategy and bot commands

**Files:**
- Modify: `backend/apps/idea2strategy-cli/src/test/java/com/idea2strategy/cli/Idea2StrategyCliTest.java`
- Modify: `backend/apps/idea2strategy-cli/src/main/java/com/idea2strategy/cli/Idea2StrategyCli.java`
- Modify: `backend/apps/idea2strategy-cli/src/main/java/com/idea2strategy/cli/ApiClient.java`
- Modify: `backend/apps/idea2strategy-cli/src/main/resources/idea2strategy-ai-tool-contract.json`
- Modify: `backend/apps/idea2strategy-cli/README.md`

**Interfaces:**
- Produces: `strategy get/delete`, `bot list/get/stop`; `stop/delete` require `--yes`.

- [ ] Add failing HTTP-boundary tests for exact routes, bearer propagation, URL encoding, confirmation before network access, list bounds, and stable JSON envelopes.
- [ ] Run `:apps:idea2strategy-cli:test` and verify only the new command tests fail as unknown commands.
- [ ] Implement dispatch, route methods, confirmation validation, and bot lookup from the owned operations projection without adding any bot mutation command.
- [ ] Re-run CLI tests and update contract/README examples.

### Task 4: Add evidence-preserving backtest soft deletion

**Files:**
- Modify: `db/schema.dbml`
- Create: `backend/db-migration/src/main/resources/db/migration/V20260827000000__backtest_owner_soft_delete.sql`
- Modify: `backtest-engine/src/backtest_engine/persistence/models.py`
- Modify: `backtest-engine/src/backtest_engine/persistence/gateway.py`
- Modify: `backtest-engine/src/backtest_engine/lifecycle.py`
- Modify: `backtest-engine/src/backtest_engine/api.py`
- Modify: `backtest-engine/tests/test_lifecycle.py`
- Modify: `backtest-engine/tests/test_backtest_api.py`
- Modify: `backtest-engine/tests/persistence/test_roundtrip.py`

**Interfaces:**
- Produces: `DELETE /api/v1/backtests/{runId}` with terminal immediate deletion and active cancel-then-delete semantics.

- [ ] Add failing schema/migration and Python tests for owner-only deletion, idempotency, terminal deletion, queued cancellation, running deletion intent, terminal finalization, and exclusion from customer queries.
- [ ] Run focused migration and Python tests and verify they fail on missing fields/route.
- [ ] Add `deletion_requested_at` and `deleted_at`, persistence transitions, lifecycle rules, and the DELETE endpoint while keeping internal worker lookup available.
- [ ] Re-run focused tests, refresh the canonical Flyway CI bundle, and run migration policy verification.

### Task 5: Expand CLI backtest and competition commands

**Files:**
- Modify: `backend/apps/idea2strategy-cli/src/test/java/com/idea2strategy/cli/Idea2StrategyCliTest.java`
- Modify: `backend/apps/idea2strategy-cli/src/main/java/com/idea2strategy/cli/Idea2StrategyCli.java`
- Modify: `backend/apps/idea2strategy-cli/src/main/java/com/idea2strategy/cli/ApiClient.java`
- Modify: `backend/apps/idea2strategy-cli/src/main/resources/idea2strategy-ai-tool-contract.json`
- Modify: `backend/apps/idea2strategy-cli/README.md`

**Interfaces:**
- Produces: `backtest create/list/get/cancel/delete` and `competition create/list/get/delete`.

- [ ] Add failing tests for separate Backend/Backtest origins, create idempotency key, period validation, list pagination, cancel/delete confirmation, competition payload-file parsing, owned/public reads, and cancellation-based delete.
- [ ] Run CLI tests and verify the new commands fail before implementation.
- [ ] Implement the commands using the server-owned routes and stable error envelope; do not add competition update or bot mutation.
- [ ] Re-run tests and publish the exact workflows in tool contract and README.

### Task 6: Replace room schedule fields with a three-milestone calendar

**Files:**
- Create: `ui/src/components/CompetitionSchedulePicker.tsx`
- Create: `ui/src/components/CompetitionSchedulePicker.test.tsx`
- Modify: `ui/src/components/CompetitionApiWorkspace.tsx`
- Modify: `ui/src/CompetitionApiWorkspace.test.tsx`
- Modify: `ui/src/styles/balanced.css`
- Modify: `ui/src/lib/i18n.tsx`

**Interfaces:**
- Produces: `{ recruitmentOpensAt, evaluationStartsAt, evaluationEndsAt }` local wall-clock values plus timezone.

- [ ] Add failing component tests for three sequential calendar clicks, milestone reselection, month navigation, range styling, independent time controls, chronological validation, keyboard labels, and timezone-stable payload conversion.
- [ ] Run the two focused UI test files and verify failures come from the missing calendar component.
- [ ] Implement the calendar grid and milestone controls with one accent hierarchy, 8px spacing rhythm, responsive layout, and no new dependency.
- [ ] Integrate it into creation, preserve derived participation/finalization timestamps, and map API problem details to specific actionable messages.
- [ ] Re-run focused UI tests, typecheck, and build.

### Task 7: End-to-end proof and delivery

**Files:**
- Modify only when a failing integration assertion demonstrates an uncovered defect.

**Interfaces:**
- Consumes: built CLI, local Docker services, real test account, real strategy and competition data.
- Produces: pushed commits and reproducible verification evidence.

- [ ] Rebuild/restart affected local services and run local initialization twice to prove scoring seed idempotency.
- [ ] Use CLI only to resolve META, preview/apply `SET_GROUP_INSTRUMENTS` to the target strategy's last group, and read back the stored document.
- [ ] Exercise strategy, bot, backtest, and competition CLI commands against local services, including refusal/ownership/destructive confirmation cases.
- [ ] In the browser, create a real competition by three calendar clicks and time selections; verify it appears in the owned list and API readback.
- [ ] Run backend, backtest, UI, Docker E2E, collaboration-policy, and secret-scanning checks; inspect every failure before fixing.
- [ ] Commit each submodule, update root pointers/Flyway bundle, commit root, and push the current feature branches without force.
