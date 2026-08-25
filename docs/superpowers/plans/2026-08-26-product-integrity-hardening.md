# Product Integrity Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a coherent, secure, beginner-friendly and professional customer/operator product whose visible controls execute real authorized backend behavior.

**Architecture:** Integrate the known-good market/backtest work with current identity code, then harden ID ownership and room admission at transaction boundaries. Move policy selection to backend-owned catalogs, derive empty/onboarding states from server facts, and verify every UI/API boundary with contract and browser tests.

**Tech Stack:** React 19, TypeScript, Vitest, Testing Library, Playwright, Java 21, Spring Boot, jOOQ, PostgreSQL, Redis, Docker Compose.

**Spec:** `docs/superpowers/specs/2026-08-26-product-integrity-hardening-design.md`

## Global Constraints

- Preserve all existing immutable strategy releases and results.
- Do not implement PRO authoring.
- Do not restore SES or require customer email verification.
- Do not generate market data.
- Do not expose internal policy version selection to customers.
- Preserve operator RBAC, audit behavior, and GitHub Actions to AWS OIDC.
- Add later Flyway migrations only; never edit an applied migration in this baseline.

---

### Task 1: Integrate the current authentication UI with market/backtest fixes

**Files:**
- Modify: `ui/src/api/account.ts`
- Modify: `ui/src/views/AuthViews.tsx`
- Modify: `ui/src/main.tsx`
- Modify: `ui/src/App.tsx`
- Test: `ui/src/AuthRoutes.test.tsx`
- Test: `ui/src/api/account.test.ts`
- Test: `ui/src/OperatorRbacRoute.test.tsx`

**Interfaces:**
- Consumes: backend immediate-signup response `{accountId, verificationRequired:false, verificationExpiresAt:null}` and operator cookie-session endpoints.
- Produces: direct post-signup login path and isolated `/operations/*` session routing.

- [ ] Add a signup contract test asserting `verificationExpiresAt:null` is accepted and no verification step is rendered.
- [ ] Run `pnpm test --run src/api/account.test.ts src/AuthRoutes.test.tsx` and verify the new assertion fails on the fixed UI baseline.
- [ ] Integrate the current develop authentication changes with the two fixed preview/backtest commits, resolving behavior by the design contract.
- [ ] Run the focused tests, `pnpm typecheck`, and operator route tests until green.
- [ ] Commit the UI authentication integration.

### Task 2: Prevent wrong-bot actions and preserve entity identity through navigation

**Files:**
- Modify: `ui/src/views/BotsView.tsx`
- Modify: `ui/src/views/DashboardView.tsx`
- Modify: `ui/src/views/StrategyViews.tsx`
- Test: `ui/src/BotTradingTabs.test.tsx`
- Test: `ui/src/DeletionFlows.test.tsx`
- Test: `ui/src/ProductScreens.test.tsx`

**Interfaces:**
- Consumes: existing `botId`, `strategyId`, and release response identifiers.
- Produces: ID-keyed selection, URL drill-down, and exact destructive targets.

- [ ] Add failing tests with two same-name bots and assert stop/delete/detail actions use the selected bot ID.
- [ ] Replace all name-keyed selection, React keys, icons, and navigation with immutable IDs.
- [ ] Add failing release-receipt and dashboard drill-down tests, then retain returned IDs in navigation.
- [ ] Run focused tests and commit.

### Task 3: Bind secret invitations to accounts and enforce admission policy atomically

**Files:**
- Modify: `backend/modules/backend-application/src/main/java/com/idea2strategy/backend/application/competition/RoomInvitationPort.java`
- Modify: `backend/modules/backend-application/src/main/java/com/idea2strategy/backend/application/competition/RoomInvitationService.java`
- Modify: `backend/modules/backend-application/src/main/java/com/idea2strategy/backend/application/competition/RoomParticipationAdmissionRequest.java`
- Modify: `backend/modules/backend-persistence/src/main/java/com/idea2strategy/backend/persistence/competition/RoomInvitationJooqAdapter.java`
- Modify: `backend/modules/backend-persistence/src/main/java/com/idea2strategy/backend/persistence/competition/RoomParticipationAdmissionJooqAdapter.java`
- Modify: `backend/apps/backend-api/src/main/java/com/idea2strategy/backend/api/competition/RoomInvitationController.java`
- Test: `backend/modules/backend-persistence/src/test/java/com/idea2strategy/backend/persistence/competition/RoomParticipationAdmissionPersistenceIntegrationTest.java`
- Test: `backend/apps/backend-api/src/test/java/com/idea2strategy/backend/api/competition/RoomParticipationControllerTest.java`

**Interfaces:**
- Produces: an account-bound invitation grant consumed in the admission transaction.

- [ ] Add a failing integration test proving a secret-room UUID cannot be joined without a grant.
- [ ] Add failing tests for another account's grant, replay, expiry, and concurrent admission.
- [ ] Add the minimal schema migration and transactional adapter behavior required by those tests.
- [ ] Enforce eligibility, instrument scope, room phase, capacity, and stopped-bot slot policy in the same locked admission path.
- [ ] Run competition application, API, migration, and persistence tests; commit.

### Task 4: Make server policy resolution authoritative

**Files:**
- Modify: `backend/apps/backend-api/src/main/java/com/idea2strategy/backend/api/strategy/StrategyReleaseController.java`
- Modify: `backend/modules/backend-application/src/main/java/com/idea2strategy/backend/application/strategy/ImmutableStrategyReleaseCommandService.java`
- Modify: `backend/apps/backend-api/src/main/java/com/idea2strategy/backend/api/competition/RoomParticipationController.java`
- Modify: `ui/src/views/StrategyViews.tsx`
- Modify: `ui/src/components/CompetitionApiWorkspace.tsx`
- Test: `backend/apps/backend-api/src/test/java/com/idea2strategy/backend/api/strategy/StrategyReleaseControllerTest.java`
- Test: `ui/src/StrategyApiView.test.tsx`
- Test: `ui/src/CompetitionApiWorkspace.test.tsx`

**Interfaces:**
- Produces: product-intent commands resolved to an immutable active policy bundle by the backend.

- [ ] Add failing API tests showing customer-supplied conflict/policy versions are ignored or rejected and the active catalog is applied.
- [ ] Resolve policy inside the application service and include the applied human-readable policy summary in receipts.
- [ ] Remove raw policy/version controls and hardcoded `FIRST_WINS` from customer UI requests.
- [ ] Run focused backend/UI tests and commit.

### Task 5: Make backtest lifecycle and results actionable

**Files:**
- Modify: `ui/src/views/BacktestLiveView.tsx`
- Modify: `ui/src/api/backtests.ts`
- Modify: `ui/src/App.tsx`
- Test: `ui/src/BacktestLiveView.test.tsx`
- Test: `ui/src/BacktestView.test.tsx`

**Interfaces:**
- Consumes: run status, attempt count, failure reason, bot/strategy identity, coverage, trades, and cancellation endpoint.
- Produces: finite polling while active, named records, retry/cancel actions, and distinct terminal state panels.

- [ ] Add failing fake-clock tests for queued/running polling, cancellation, terminal stop, and retryable refresh failure.
- [ ] Add failing presentation tests for bot/strategy names, coverage, attempt count, failure reason, and empty trade explanation.
- [ ] Implement bounded polling with visibility-aware refresh and accessible status announcements.
- [ ] Remove customer-facing internal policy selection and commit after focused tests pass.

### Task 6: Build a truthful empty-account onboarding journey

**Files:**
- Modify: `ui/src/views/DashboardView.tsx`
- Modify: `ui/src/views/StrategyViews.tsx`
- Modify: `ui/src/views/BotsView.tsx`
- Modify: `ui/src/views/BacktestLiveView.tsx`
- Modify: `ui/src/components/CompetitionApiWorkspace.tsx`
- Modify: `ui/src/styles.css`
- Test: `ui/src/ProductScreens.test.tsx`
- Test: `ui/src/RuntimeHonesty.test.tsx`
- Test: `ui/e2e/real-api.spec.ts`

**Interfaces:**
- Produces: server-fact onboarding steps and one primary CTA per genuine empty state.

- [ ] Add failing tests for a fresh account on home, strategies, bots, backtests, and competition.
- [ ] Implement progress and CTAs without fabricated performance or sample entities.
- [ ] Add filtered-empty, unavailable, forbidden, and retry states for each surface.
- [ ] Verify keyboard order, responsive widths, and Korean/English copy; commit.

### Task 7: Complete competition customer and operator journeys

**Files:**
- Modify: `ui/src/components/CompetitionApiWorkspace.tsx`
- Modify: `ui/src/components/OperatorCompetitionWorkspace.tsx`
- Modify: `ui/src/api/competitionRooms.ts`
- Modify: `backend/apps/backend-api/src/main/java/com/idea2strategy/backend/api/competition/CompetitionRoomController.java`
- Test: `ui/src/CompetitionApiWorkspace.test.tsx`
- Test: `ui/src/components/OperatorCompetitionWorkspace.test.tsx`
- Test: `backend/modules/backend-persistence/src/test/java/com/idea2strategy/backend/persistence/competition/CompetitionJourneyPersistenceE2ETest.java`

**Interfaces:**
- Produces: reachable public/secret/joined room details across all phases and operator-only official BACKTEST setup.

- [ ] Add failing lifecycle tests for recruiting, submission, waiting, evaluating, ended, cancelled, and invalidated rooms.
- [ ] Replace raw customer schedule/policy inputs with product-level presets and clear explanations.
- [ ] Add operator official BACKTEST creation, finalization deadline enforcement, and idempotency receipts.
- [ ] Prohibit withdrawal after official evaluation begins and expose post-evaluation choices safely.
- [ ] Run focused tests and commit.

### Task 8: Rebuild the operator workspace around permissions and evidence

**Files:**
- Modify: `ui/src/components/CaseApiPanels.tsx`
- Modify: `ui/src/components/OperatorRbacViews.tsx`
- Modify: `ui/src/api/accountOperations.ts`
- Modify: `backend/modules/backend-application/src/main/java/com/idea2strategy/backend/application/caseoperations/OperatorCaseDetail.java`
- Modify: `backend/modules/backend-persistence/src/main/java/com/idea2strategy/backend/persistence/caseoperations/OperatorCaseJooqAdapter.java`
- Test: `ui/src/components/CaseApiPanels.test.tsx`
- Test: `backend/modules/backend-application/src/test/java/com/idea2strategy/backend/application/caseoperations/OperatorCaseServiceTest.java`

**Interfaces:**
- Produces: permission-driven navigation, privacy-safe evidence/history, sanction history, reauthentication, and durable command receipts.

- [ ] Add failing tests that forbid decisions without readable evidence and hide tabs without permission IDs.
- [ ] Add privacy-safe case details and provenance to the API; explicitly exclude private strategy source.
- [ ] Replace raw UUID/version/JSON inputs with server-backed selectors and current state.
- [ ] Separate command success receipts from subsequent refresh errors and add session-expiry recovery.
- [ ] Add dialog focus/Escape/focus-return tests; commit.

### Task 9: Inventory every visible action and frontend/backend API contract

**Files:**
- Create: `scripts/validate-ui-api-contracts.mjs`
- Create: `scripts/validate-ui-api-contracts.test.mjs`
- Create: `ui/src/ProductActionInventory.test.tsx`
- Modify: `package.json`

**Interfaces:**
- Produces: CI failures for frontend API paths without backend mappings and visible enabled actions without an asserted outcome.

- [ ] Write a failing fixture test with an unmapped `/api/v1` client path.
- [ ] Parse literal API routes and backend controller mappings, with an explicit allowlist only for documented proxy/websocket cases.
- [ ] Add route-level action inventory tests covering success, denied, unavailable, and destructive confirmation outcomes.
- [ ] Run contract inventory and UI suite; commit.

### Task 10: Full-stack verification and delivery

**Files:**
- Modify: `docs/evidence/product-integrity-hardening.md`
- Modify: root submodule pointers.

**Interfaces:**
- Produces: reproducible evidence, pushed component commits, and pushed root integration commit.

- [ ] Run backend unit/integration tests, UI unit/type/build tests, schema/contract checks, and all engine suites affected by contract changes.
- [ ] Build and start the isolated Docker stack using repository-local market data.
- [ ] Run browser E2E for fresh/existing customers, duplicate-name bots, strategy release, backtest terminal states, every competition phase, and operator RBAC/case flows.
- [ ] Run secret scanning on commits and working trees without printing secret values.
- [ ] Record commands, counts, URLs, data timestamps/checksums, and sanitized receipts in evidence.
- [ ] Push component branches, update/push root pointers, and report only verified outcomes.
