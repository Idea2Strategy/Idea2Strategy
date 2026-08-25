# Basic Strategy and Backtest Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every visible Basic strategy capability execute through real Backend persistence, validation, compilation, release, all three Backtest lanes, and result UI while keeping Pro explicitly unavailable.

**Architecture:** A versioned Basic conformance corpus is copied byte-for-byte into UI, Backend, and Backtest and exercised by real behavior tests in each repository. Backend remains authoritative for validation and compilation; Backtest executes the immutable compiled plan; root integration tests prove the full vertical path and fixture parity.

**Tech Stack:** React 19, TypeScript 7, Vitest, Playwright, Java 21, Spring Boot, Jackson, JUnit 5, Testcontainers/PostgreSQL 16, Python 3.12, pytest, FastAPI, LocalStack/SQS, MinIO/S3, Flyway.

**Spec:** `docs/superpowers/specs/2026-08-25-basic-strategy-backtest-completion-design.md`

## Global Constraints

- Executable scope is Basic only; Pro remains visible with stable “준비 중” copy and no executable action.
- Basic supports only `30m`, `1h`, `4h`, and `1d`, with one selected resolution as its single clock.
- Maximum shape is four partitions, one BUY and one SELL container per partition, five conditions per container, and five instruments per partition.
- The consolidated V1 is immutable; database and catalog changes use a later Flyway migration.
- Missing data produces a typed unavailable result and never substitutes another input.
- Every behavior change follows test-driven development: observe the new test fail for the intended reason before changing production code.
- No mocked UI test is accepted as proof of Backtest execution.

---

### Task 1: Publish the shared Basic conformance corpus

**Files:**
- Create: `contracts/fixtures/basic-strategy/v1/basic-element-conformance.v1.json`
- Create: `scripts/validate-basic-strategy-conformance.mjs`
- Create: `scripts/validate-basic-strategy-conformance.test.mjs`
- Modify: `package.json`
- Copy in submodule tasks to: `ui/src/test/contracts/basic-element-conformance.v1.json`
- Copy in submodule tasks to: `backend/modules/backend-application/src/test/resources/contracts/basic-element-conformance.v1.json`
- Copy in submodule tasks to: `backtest-engine/tests/fixtures/contracts/basic-element-conformance.v1.json`

**Interfaces:**
- Produces: schema version `basic-element-conformance/v1`, catalog version `basic-elements:2026-08-25`, and fourteen cases keyed by `elementCode`.
- Each case contains `container`, literal `validParameters`, literal `invalidParameters`, `operation`, literal `arguments`, `trueInputs`, `falseInputs`, and `expectedReviewKo`.
- Later tasks consume the copied corpus as test input; no production component reads test fixtures at runtime.

- [ ] **Step 1: Write the failing parity and schema tests**

Create Node tests that invoke the validator against a temporary corpus and prove these mutations fail: delete `BASIC_MACD_CROSS`, duplicate an element code, provide an invalid resolution, omit `operation`, and change one copied fixture byte. Expected failure codes are respectively `ELEMENT_SET_MISMATCH`, `DUPLICATE_ELEMENT`, `INVALID_RESOLUTION`, `OPERATION_REQUIRED`, and `FIXTURE_PARITY_MISMATCH`.

- [ ] **Step 2: Run the tests and verify RED**

Run: `node --test scripts/validate-basic-strategy-conformance.test.mjs`
Expected: FAIL because the validator and corpus do not exist.

- [ ] **Step 3: Add the literal fourteen-case corpus and validator**

The exact element set is:

```js
[
  'BASIC_PRICE_COMPARE',
  'BASIC_PRICE_CHANGE_PERCENT',
  'BASIC_VOLUME_COMPARE',
  'BASIC_STREAK',
  'BASIC_SMA_CROSS',
  'BASIC_RSI_CROSS',
  'BASIC_MACD_CROSS',
  'BASIC_BOLLINGER_REVERSAL',
  'BASIC_POSITION_RETURN',
  'BASIC_HOLDING_PERIOD',
  'BASIC_PEAK_RETURN',
  'BASIC_DRAWDOWN_FROM_PEAK',
  'BASIC_SCHEDULE',
  'BASIC_EQUAL_ALLOCATION_ORDER',
]
```

Each condition case includes both BUY and SELL when allowed. SELL-only position cases name only SELL; schedule names only BUY. The terminal action includes `maxPositionPercent` in its valid arguments and invalid cases for `0`, `100.1`, negative, empty, and malformed values.

- [ ] **Step 4: Run the validator tests and verify GREEN**

Run: `node --test scripts/validate-basic-strategy-conformance.test.mjs`
Expected: all tests pass.

- [ ] **Step 5: Add the root command**

Add `contract:validate:basic-strategy` to `package.json` and point it to `node scripts/validate-basic-strategy-conformance.mjs`.

- [ ] **Step 6: Commit the root contract**

```bash
git add contracts/fixtures/basic-strategy scripts/validate-basic-strategy-conformance.mjs scripts/validate-basic-strategy-conformance.test.mjs package.json
git commit -m "test: define Basic strategy conformance corpus"
```

---

### Task 2: Make the Basic UI serialize every executable value and keep Pro unavailable

**Files:**
- Create: `ui/src/lib/basicStrategyDocument.ts`
- Create: `ui/src/lib/basicStrategyDocument.test.ts`
- Create: `ui/src/BasicStrategyConformance.test.ts`
- Modify: `ui/src/views/StrategyViews.tsx`
- Modify: `ui/src/StrategyApiView.test.tsx`
- Modify: `ui/src/StrategyCatalogCoverage.test.ts`
- Create: `ui/e2e/strategy.e2e.ts`
- Copy: `ui/src/test/contracts/basic-element-conformance.v1.json`

**Interfaces:**
- Produces: `buildBasicSemanticDocument(snapshot, catalog): BasicSemanticDocument` in a focused library module.
- The terminal block parameters include literal string `maxPositionPercent` for each instrument-specific compiled group.
- Pro controls expose no API call and render `프로 전략은 준비 중입니다`.

- [ ] **Step 1: Write failing UI behavior tests**

Tests use the literal corpus and prove:

- every corpus case can be created through the real Basic document builder;
- edited values survive save payload and reload snapshot;
- four resolutions produce the expected literal `resolution` value;
- five conditions and five instruments are accepted, but the sixth is blocked before release;
- each instrument cap is serialized rather than left only in presentation state;
- empty, zero, negative, malformed, and over-100 caps focus the exact field;
- Pro create/save/validate/release buttons are disabled and the API client remains untouched.

The mutation each test catches is removal or misrouting of a user-edited value, not a change to source text.

- [ ] **Step 2: Run UI tests and verify RED**

Run:

```bash
cd ui
pnpm test --run src/lib/basicStrategyDocument.test.ts src/BasicStrategyConformance.test.ts src/StrategyApiView.test.tsx
```

Expected: failures show that the builder is embedded in `StrategyViews.tsx`, caps are presentation-only, and Pro actions are not uniformly blocked.

- [ ] **Step 3: Extract and type the Basic document builder**

Move serialization helpers out of the 5,000-line view without changing behavior. Define explicit `BasicSemanticDocument`, `BasicSemanticGroup`, and `BasicSemanticBlock` types. Reject unknown labels instead of returning an empty `elementCode`.

- [ ] **Step 4: Serialize instrument caps and exact values**

Expand a multi-instrument editor card into deterministic instrument-specific semantic groups when caps differ. Stable IDs use `${cardId}:${instrumentId}`. Preserve equal-allocation membership through `allocationGroupId: cardId`. Include `maxPositionPercent` on the terminal action.

- [ ] **Step 5: Render authoritative errors and warnings**

Map Backend issue locations to partition, card, block, and input. Preserve unknown codes with correlation IDs. Never convert a rejected validation or unavailable result into ready or complete.

- [ ] **Step 6: Lock Pro to preparation state**

Keep the visual editor route and node library visible. Disable all execution-affecting controls and render one consistent status message and accessible explanation.

- [ ] **Step 7: Run UI verification**

Run:

```bash
pnpm test --run
pnpm typecheck
pnpm build
```

Expected: zero failures and no TypeScript errors.

- [ ] **Step 8: Commit and push the UI submodule branch**

```bash
git add src e2e
git commit -m "feat: complete Basic strategy document behavior"
```

---

### Task 3: Make Backend validation exhaustive and warning-aware

**Files:**
- Create: `backend/modules/backend-application/src/main/java/com/idea2strategy/backend/application/strategy/BasicStrategyWarningAnalyzer.java`
- Create: `backend/modules/backend-application/src/test/java/com/idea2strategy/backend/application/strategy/BasicStrategyWarningAnalyzerTest.java`
- Create: `backend/modules/backend-application/src/test/java/com/idea2strategy/backend/application/strategy/BasicElementConformanceTest.java`
- Modify: `backend/modules/backend-application/src/main/java/com/idea2strategy/backend/application/strategy/BasicBlockAssemblyValidator.java`
- Modify: `backend/modules/backend-application/src/main/java/com/idea2strategy/backend/application/strategy/BasicStrategyValidationCommandService.java`
- Modify relevant validation result records and API DTOs under `backend/apps/backend-api/src/main/java/com/idea2strategy/backend/api/strategy/`
- Copy: `backend/modules/backend-application/src/test/resources/contracts/basic-element-conformance.v1.json`

**Interfaces:**
- Produces stable severities `ERROR` and `WARNING` with `code`, `location`, `message`, and optional `details`.
- Warning codes: `DUPLICATE_CONDITION`, `CONTRADICTORY_CONDITION`, `CONDITION_ALWAYS_TRUE`, `CONDITION_ALWAYS_FALSE`, `REPEATED_ORDER_EXPOSURE`, `POSITION_CAP_REACHED`, `SELL_REQUIRES_POSITION`, and `RESTRICTIVE_COMBINATION`.

- [ ] **Step 1: Write failing conformance validation tests**

Load every literal valid and invalid parameter set from the fixture through the real Jackson parser and `BasicBlockAssemblyValidator`. Assert valid cases have no `ERROR`; each invalid case returns its literal code and precise JSON path.

- [ ] **Step 2: Write failing structural-limit tests**

Prove Backend, independent of UI, rejects partition 5, condition 6, instrument 6, missing terminal action, duplicate terminal action, BUY-only element in SELL, SELL-only element in BUY, equal/descending SMA periods, and cap values outside `(0, 100]`.

- [ ] **Step 3: Write failing warning tests**

Use hand-derived documents for equivalent duplicate thresholds, mutually exclusive bounds, always-true/false numeric ranges, and repeated execution. Assert warning severity does not invalidate an otherwise valid document.

- [ ] **Step 4: Run Backend RED tests**

Run:

```powershell
cd backend
./gradlew.bat :modules:backend-application:test --tests '*BasicElementConformanceTest' --tests '*BasicStrategyWarningAnalyzerTest'
```

Expected: failures identify missing bounds, missing cap semantics, and absent warning analysis.

- [ ] **Step 5: Implement schema-driven validation and warnings**

Use the catalog parameter schema for type, enumeration, length, and numeric constraints. Keep cross-field rules such as SMA ordering in explicit validators. Run warning analysis only after structural parsing succeeds.

- [ ] **Step 6: Persist and return the exact result**

Store warning and error collections with the validated edit sequence, semantic hash, and catalog version. Preview, validate, current-validation, and release endpoints return the same issue shape.

- [ ] **Step 7: Run Backend strategy tests**

Run:

```powershell
./gradlew.bat :modules:backend-application:test :modules:backend-persistence:test :apps:backend-api:test --tests '*strategy*'
```

Expected: zero failures.

- [ ] **Step 8: Commit and push the Backend validation branch**

```bash
git add modules/backend-application apps/backend-api modules/backend-persistence
git commit -m "feat: validate every Basic strategy shape"
```

---

### Task 4: Publish the new catalog and compile caps without semantic drift

**Files:**
- Create: `backend/db-migration/src/main/resources/db/migration/V2__basic_strategy_execution_completion.sql`
- Create: `backend/db-migration/src/test/java/com/idea2strategy/backend/migration/BasicStrategyExecutionCompletionMigrationIntegrationTest.java`
- Modify: `backend/modules/backend-application/src/main/java/com/idea2strategy/backend/application/strategy/BasicExecutionPlanCompiler.java`
- Modify: `backend/modules/backend-application/src/main/java/com/idea2strategy/backend/application/strategy/StrategyBotCompiledPlanAssembler.java`
- Create or modify compiler tests under `backend/modules/backend-application/src/test/java/com/idea2strategy/backend/application/strategy/`

**Interfaces:**
- Produces immutable catalog version `basic-elements:2026-08-25`.
- Produces compiled terminal arguments `orderPercent`, `maxPositionPercent`, `executionMode`, `waitMode`, `waitInterval`, and `maxExecutions`.
- Old releases pinned to `basic-elements:2026-08-08` remain loadable.

- [ ] **Step 1: Write failing migration and compiler tests**

Migration test starts from V1, applies V2, verifies all fourteen element definitions, verifies the terminal parameter schema contains numeric-string bounds for both percentages, and proves V1 rows are unchanged. Compiler tests load every conformance case and compare literal operation and arguments.

- [ ] **Step 2: Run compiler and migration tests and verify RED**

Run:

```powershell
cd backend
./gradlew.bat :modules:backend-application:test :db-migration:test --tests '*Basic*Completion*' --tests '*Basic*Compiler*'
```

- [ ] **Step 3: Implement V2 and deterministic compilation**

Publish new catalog and definition rows with stable hashes. Compile instrument-specific flows in sorted instrument-ID order and preserve one allocation-group key. Reject a terminal argument the runtime schema cannot consume.

- [ ] **Step 4: Verify legacy and new compiled plans**

Run all Backend strategy, migration, contract fixture, and immutable-release tests. Expected: V1 fixtures still load; V2 includes cap arguments and stable checksums.

- [ ] **Step 5: Commit the Backend catalog/compiler change**

```bash
git add db-migration modules/backend-application modules/backend-messaging
git commit -m "feat: compile complete Basic execution plans"
```

---

### Task 5: Execute every Basic operation and per-instrument cap in Backtest

**Files:**
- Copy: `backtest-engine/tests/fixtures/contracts/basic-element-conformance.v1.json`
- Create: `backtest-engine/tests/test_basic_element_conformance.py`
- Modify: `backtest-engine/src/backtest_engine/elements/catalog.py`
- Modify: `backtest-engine/src/backtest_engine/elements/orders.py`
- Modify: `backtest-engine/src/backtest_engine/basic_runtime.py`
- Modify: `backtest-engine/src/backtest_engine/wiring.py`
- Modify: `backtest-engine/tests/test_basic_runtime.py`
- Modify: `backtest-engine/tests/test_wiring.py`

**Interfaces:**
- Consumes every compiler operation and argument from the conformance corpus.
- `OrderCandidate.max_position_percent: Decimal` is required for V2 and defaults only when loading a pinned V1 plan.
- A cap rejection produces stable reason `MAX_INSTRUMENT_POSITION_PERCENT` and an auditable result record.

- [ ] **Step 1: Write failing operation conformance tests**

For each of the twelve conditions, construct real `EvaluationInputs` from literal fixture values and prove true and false outcomes. Missing history, missing position, incomplete bar, and malformed input must not become false.

- [ ] **Step 2: Write failing cap tests**

Prove current position plus reserved BUY exposure at or above the cap rejects new BUY risk; a SELL that reduces exposure remains allowed; separate instruments and partitions do not borrow caps; decimal rounding cannot exceed the cap after fill-price recheck.

- [ ] **Step 3: Run Backtest RED tests**

Run:

```bash
cd backtest-engine
uv run pytest tests/test_basic_element_conformance.py tests/test_basic_runtime.py tests/test_wiring.py -q
```

- [ ] **Step 4: Implement missing operation and cap behavior**

Use completed bars at the selected resolution. Use pinned `RSI_14` materializations for RSI and deterministic raw-bar calculations for the other published V2 operations. Preserve V1 loader compatibility.

- [ ] **Step 5: Run the full Backtest suite**

Run:

```bash
uv run pytest -q
uv run ruff check .
uv run mypy src
```

Expected: zero failures and no lint/type errors.

- [ ] **Step 6: Commit and push the Backtest branch**

```bash
git add src tests
git commit -m "feat: execute complete Basic catalog"
```

---

### Task 6: Prove complex strategies across all three lanes

**Files:**
- Replace the single-operation builder in: `scripts/integration/test_three_lane_feature_e2e.py`
- Create: `scripts/integration/basic_strategy_cases.py`
- Create: `scripts/integration/test_basic_strategy_matrix_e2e.py`
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Produces deterministic generated cases covering all fourteen elements, four resolutions, BUY/SELL, multiple instruments, multiple partitions, maximum shape, warnings, and unavailable inputs.
- Every case records the element set it covers so the test can fail with the uncovered set.

- [ ] **Step 1: Write the failing coverage assertion**

Add an assertion that the existing RSI-only integration leaves thirteen required element codes uncovered. Run it and observe `CATALOG_CASES_MISSING` with the literal missing set.

- [ ] **Step 2: Add pairwise case generation**

Use a deterministic seed and hand-checked expected case count. Do not compute expected semantic results using production helpers. Include curated maximum-size and contradiction cases outside pairwise generation.

- [ ] **Step 3: Execute BASIC, CUSTOM, and COMPETITION**

For every valid compiled case, persist pins once, enqueue lane requests, run the real intake and worker, and compare terminal state, candidate/fill summary, checksum, and immutable result manifest. For unavailable cases, assert no execution message or complete result exists.

- [ ] **Step 4: Run Docker integration tests**

Run:

```bash
python -m pytest -c backtest-engine/pyproject.toml \
  scripts/integration/test_three_lane_feature_e2e.py \
  scripts/integration/test_basic_strategy_matrix_e2e.py -m docker -vv
```

- [ ] **Step 5: Add the matrix to required CI**

Keep `three-lane-feature-e2e` required and run both integration files in that job.

- [ ] **Step 6: Commit the root integration proof and advanced gitlinks**

```bash
git add backend backtest-engine ui scripts/integration .github/workflows/ci.yml
git commit -m "test: prove complete Basic strategy execution"
```

---

### Task 7: Add browser-to-result real E2E

**Files:**
- Create: `ui/e2e/basic-strategy-real.e2e.ts`
- Modify: `ui/e2e/run-real-api.mjs`
- Modify: `ui/playwright.real-api.config.ts`
- Modify: `scripts/dev.ps1`
- Create: `scripts/test-basic-strategy-real-e2e.ps1`

**Interfaces:**
- Consumes the real local URLs emitted by `scripts/dev.ps1`.
- Uses the repository-created local test account; no credential is committed.
- Produces a machine-readable receipt with strategy ID, release ID, run IDs by lane, terminal states, and result checksums but no tokens or secrets.

- [ ] **Step 1: Write the failing real browser flow**

The test signs in, creates a Basic strategy, selects instruments, uses every block across several partitions, edits values, verifies warnings and blocking errors, saves/reloads, releases, and waits on condition-based API/UI state. It must fail against the current app because the full catalog cannot complete the real path.

- [ ] **Step 2: Add negative-state browser flows**

Prove unavailable, failed, cancelled, forbidden, lease conflict, stale validation, and Pro-preparation states. Assert no success UI appears for any negative state.

- [ ] **Step 3: Make the local runner deterministic**

Start the deploy-like Docker stack, wait on health endpoints, seed the local account and approved data, execute Playwright, write the receipt under ignored `.harness/local/artifacts`, and stop only processes the runner created.

- [ ] **Step 4: Run the real E2E twice**

Run: `./scripts/test-basic-strategy-real-e2e.ps1` twice without resetting D: or AWS dependencies. Expected: both runs pass; idempotent setup does not create conflicting fixtures.

- [ ] **Step 5: Commit the E2E**

Commit UI changes in the UI submodule first, then advance the root gitlink and root runner in a root commit.

---

### Task 8: Refresh Flyway, documentation, and required gates

**Files:**
- Modify generated bundle: `db/flyway-ci-bundle/`
- Modify: `scripts/test-flyway-ci-bundle.ps1`
- Modify: `.github/workflows/ci.yml`
- Modify: `specs/product/open-questions/question.strategy.catalog.md`
- Modify: `specs/product/decisions/decision.strategy.basic-catalog-v1.md`
- Create: `docs/evidence/basic-strategy-backtest-completion.md`

**Interfaces:**
- Root Flyway bundle pins the exact Backend revision containing V2.
- Evidence lists every Basic element with UI, validation, compiler, runtime, lane, and browser status.

- [ ] **Step 1: Update the approved product records**

Record that the per-instrument cap is a terminal-order parameter, blocks only risk-increasing orders, and never liquidates. Mark the former open question resolved by `user:kcrmin` approval from this session.

- [ ] **Step 2: Refresh and test the central Flyway bundle**

Run:

```powershell
./scripts/refresh-flyway-ci-bundle.ps1
./scripts/test-flyway-ci-bundle.ps1
```

- [ ] **Step 3: Add required CI commands**

Run root conformance validation in `schema-and-coordination`, matrix integration in `three-lane-feature-e2e`, and retain GitGuardian as a required branch-protection check.

- [ ] **Step 4: Write evidence from actual outputs**

Populate the support matrix only after each command has run. Use exact test counts, run IDs, and checksums; do not infer a green cell from a neighboring test.

- [ ] **Step 5: Commit root adoption**

```bash
git add db .github scripts specs docs backend backtest-engine ui
git commit -m "docs: record complete Basic execution evidence"
```

---

### Task 9: Full verification, review, PR, and merge

**Files:**
- No new production files; fix only failures reproduced by the commands below, each with a regression test first.

**Interfaces:**
- Produces a clean root worktree, pushed submodule commits, a green root PR, and a merge commit on `origin/develop`.

- [ ] **Step 1: Verify every repository independently**

Run UI tests/typecheck/build, Backend full test suite, Backtest full test/lint/type suite, data-pipeline feature tests, root contract validators, Flyway integration, generated matrix integration, and real browser E2E.

- [ ] **Step 2: Verify secret safety before push**

Run the repository secret-pattern hook tests and scan staged/tracked changes for credential signatures without printing secret values.

- [ ] **Step 3: Request code review**

Use `superpowers:requesting-code-review` and resolve every confirmed finding through TDD. Re-run the full verification after the final change.

- [ ] **Step 4: Push submodule branches and root branch**

Push only the commits created for this goal. Confirm every root gitlink points to a reachable remote commit.

- [ ] **Step 5: Create the root PR**

The PR body links this spec and plan, quotes the approving `user:kcrmin` instructions, lists exact verification evidence, and states that Pro remains unavailable.

- [ ] **Step 6: Wait for every required check**

Do not merge while GitGuardian, Flyway, infrastructure, schema/coordination, three-lane matrix, or any added real-E2E check is pending or failed.

- [ ] **Step 7: Merge and verify remote develop**

Merge only after all required checks succeed. Fetch `origin/develop`, verify the PR merge commit is its head, verify branch protection still requires GitGuardian, and verify every worktree is clean.
