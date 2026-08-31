# Release-proof Verification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish and execute a repeatable release gate that detects semantic, durability, data, UI/API, and operational defects before launch and fixes every reproducible release blocker.

**Architecture:** Compose the existing Basic conformance matrix, three-lane integration, independent actual-run oracle, real browser E2E, and root contract checks into a deterministic runner with sanitized receipts. Add repeated actual-data and chaos scenarios only where the current harness lacks durable evidence, then fix defects at their owning boundary through red-green tests.

**Tech Stack:** Python 3.12/pytest/pyarrow/boto3/SQLAlchemy, Java 21/Spring Boot/Gradle, React 19/TypeScript/Vitest/Playwright, PostgreSQL 16, Redis, LocalStack SQS, MinIO S3, Docker Compose, PowerShell, GitHub Actions

**Spec:** `docs/superpowers/specs/2026-08-31-release-proof-verification-design.md`

## Global Constraints

- Use only stored local market data; never generate substitute OHLCV.
- Preserve immutable strategy releases, compiled plans, input pins, results, and applied Flyway migrations.
- Basic is executable; Pro remains unavailable.
- Customer signup must not require email verification while SES is absent.
- Customers never select internal policy or dataset versions.
- Every async case must reach a finite typed terminal state.
- Do not print or commit passwords, tokens, keys, cookies, or environment-file contents.

---

### Task 1: Baseline the isolated release candidate

**Files:**
- Inspect: root and all five submodules
- Create: `.local/artifacts/release-proof/baseline.json`

**Interfaces:**
- Consumes: `origin/develop` at root and pinned submodule revisions
- Produces: clean revision and environment receipt used by every later task

- [ ] Record root/submodule revisions, dirty state, Docker versions, resource capacity, and sanitized service health in `baseline.json`.
- [ ] Run root contract tests, Flyway bundle validation, component unit/type/lint suites, and container build contracts.
- [ ] Repeat deterministic unit suites three times in fresh processes and record any order-dependent failure.
- [ ] Classify every baseline failure as environment, flaky test, or product defect before proceeding.

### Task 2: Add a durable release-proof runner

**Files:**
- Create: `scripts/integration/release_proof_runner.py`
- Create: `scripts/integration/test_release_proof_runner.py`
- Modify: `package.json`

**Interfaces:**
- Produces: `ReleaseScenario`, `ScenarioResult`, `assert_terminal_runs()`, `write_sanitized_receipt()`, and a `verify:release-proof` command

- [ ] Add failing tests proving receipts reject secret-like fields, require scenario/seed/fingerprint/terminal state/duration, and sort results deterministically.
- [ ] Run `python -m pytest scripts/integration/test_release_proof_runner.py -q` and verify the expected failures.
- [ ] Implement the minimal runner and JSON receipt schema without embedding service credentials.
- [ ] Run focused tests, malformed receipt tests, and the root secret-scanner tests.
- [ ] Commit the self-contained runner slice.

### Task 3: Exhaust the Basic strategy semantic matrix

**Files:**
- Modify: `scripts/integration/basic_strategy_cases.py`
- Modify: `scripts/integration/test_basic_strategy_matrix_e2e.py`
- Test: `backtest-engine/tests/test_basic_element_conformance.py`
- Test: `backend/modules/backend-persistence/src/test/java/com/idea2strategy/backend/persistence/strategy/BasicStrategyCatalogPersistenceIntegrationTest.java`
- Test: `ui/src/BasicStrategy*.test.tsx`

**Interfaces:**
- Consumes: `contracts/fixtures/basic-strategy/v1/basic-element-conformance.v1.json`
- Produces: deterministic pairwise cases plus maximum, contradictory, duplicate, no-signal, unavailable, and simultaneous BUY/SELL cases

- [ ] Prove all twelve conditions, schedule, order action, four resolutions, both sides, 1..4 partitions, and 1..5 instruments are covered.
- [ ] Add numeric minimum/maximum/inside/outside/zero/negative/decimal/empty/malformed assertions for every applicable parameter and unknown-enum assertions.
- [ ] Execute the generated matrix ten times with shuffled test order and fixed recorded seeds.
- [ ] For each discovered semantic mismatch, add the narrow failing owner test, implement the minimal fix, and rerun UI/backend/compiler/runtime parity.
- [ ] Commit each owner repository only after its complete affected suite passes.

### Task 4: Run and reconcile the actual-data strategy corpus

**Files:**
- Modify: `scripts/local/sample_backtest_strategies.py`
- Modify: `scripts/integration/backtest_actual_run_oracle.py`
- Create: `.local/artifacts/release-proof/actual-data-runs.json`

**Interfaces:**
- Consumes: fixed interval `2016-01-01..2026-07-29` and stored immutable manifests
- Produces: at least twenty fresh run receipts across materially different strategy shapes

- [ ] Build the corpus from the active long-growth strategy plus single-clock, mixed-clock, all-block, warning-bearing, no-signal, and typed-unavailable releases.
- [ ] Submit runs sequentially per custom-lane capacity and verify request idempotency with same-key and conflicting-key repetitions.
- [ ] Assert selected manifests are the deterministic minimal cover for each instrument/resolution requirement and contain no unrelated cross-product.
- [ ] Reconcile every completed run's source hashes, OHLCV base prices, fills, fees, slippage, balanced ledgers, FIFO realized PnL, ending cash/equity, and result hash independently.
- [ ] Repeat representative strategies three times and require identical immutable inputs and deterministic result evidence.

### Task 5: Exercise queue, lease, cancellation, and restart chaos

**Files:**
- Test: `backtest-engine/tests/test_worker.py`
- Test: `backtest-engine/tests/test_stale_recovery.py`
- Test: `backtest-engine/tests/test_reproducibility_e2e.py`
- Create: `.local/artifacts/release-proof/chaos-runs.json`

**Interfaces:**
- Produces: evidence for duplicate delivery, saturation, worker kill/restart, lease reclaim, late completion fencing, cancellation races, DLQ exhaustion, and resource exits

- [ ] Saturate BASIC/CUSTOM/COMPETITION above 2/1/1 concurrency and prove excess work remains queued without lane starvation.
- [ ] Kill the worker during binding, replay, upload, and publication checkpoints; restart it and validate attempt lineage and single terminal result.
- [ ] Race cancellation with claim, heartbeat, checkpoint, and completion and require cancellation/success mutual exclusion.
- [ ] Inject missing/version-changed objects, invalid input, resource limit, publication failure, and max retries; require typed finite failure and UI-visible reason.
- [ ] Run stale recovery after every chaos batch and assert no invalid QUEUED/RUNNING record remains while live heartbeats are preserved.

### Task 6: Verify real customer, competition, and operator browser flows

**Files:**
- Test: `ui/e2e/basic-strategy-real.e2e.ts`
- Test: `ui/e2e/competition-room-create-real.e2e.ts`
- Test: `ui/e2e/operator-session.e2e.ts`
- Test: `ui/e2e/operator-commands.e2e.ts`
- Create: `.local/artifacts/release-proof/browser-runs.json`

**Interfaces:**
- Consumes: deploy-like Docker stack and local test identities
- Produces: clean-context browser receipts for customer and operator journeys

- [ ] Repeat signup/login without email verification, empty-account onboarding, strategy authoring/save/reload/validation/release, and result review in fresh browser contexts.
- [ ] Exercise loading, empty, filtered-empty, queued, running, cancelling, cancelled, completed, failed, unavailable, forbidden, conflict, and session-expired states.
- [ ] Create public and secret competitions through the calendar/time UI and verify admission, submission, evaluation, ending, cancellation, and operator-only actions.
- [ ] Inventory every enabled visible action and require an asserted success, denial, retry, navigation, or confirmation outcome with zero unexpected console/network errors.
- [ ] Run responsive and keyboard-accessibility checks at phone, tablet, laptop, and desktop widths.

### Task 7: Measure operational bounds and repeated stability

**Files:**
- Create: `.local/artifacts/release-proof/soak-summary.json`
- Modify: `docs/evidence/release-proof-verification-2026-08-31.md`

**Interfaces:**
- Produces: latency percentiles, resource peaks, retry counts, terminal counts, and leak/drift evidence

- [ ] Execute at least thirty actual service runs across the corpus and chaos cases, recording request-to-terminal and dequeue-to-terminal durations.
- [ ] Run the full deterministic gate five consecutive times and compare failures, result hashes, database row growth, queue depth, worker memory, and file-descriptor trends.
- [ ] Verify the approved 10-minute p95 dequeue and 15-minute request ceiling for full-history single-instrument runs.
- [ ] Query for orphan attempts, duplicate manifests, unbalanced ledgers, invalid terminal timestamps, stale claims, and max-attempt nonterminal runs; require zero rows.
- [ ] Document expected strategy-level rejections separately from engine or lifecycle defects.

### Task 8: Final verification and delivery

**Files:**
- Modify: `docs/evidence/release-proof-verification-2026-08-31.md`
- Modify: root submodule pointers and `db/flyway-ci-bundle/source-revisions.json` when component fixes exist

**Interfaces:**
- Produces: merged green release evidence on remote `develop`

- [ ] Run every affected component suite, root contracts, Flyway integration, Docker E2E, browser E2E, and secret scans from the final tree.
- [ ] Review the complete diff for scope, immutable-history safety, error semantics, and leaked values.
- [ ] Request code review and resolve every Critical or Important finding.
- [ ] Push component branches, create PRs, wait for required checks, merge components, refresh the root Flyway bundle, then merge the root PR.
- [ ] Mark the Goal complete only after remote `develop`, local services, actual receipts, and final report all agree.
