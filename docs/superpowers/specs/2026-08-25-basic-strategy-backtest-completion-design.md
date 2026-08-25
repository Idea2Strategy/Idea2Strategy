# Basic Strategy and Backtest Completion Design

**Date:** 2026-08-25
**Status:** Approved in session by `user:kcrmin`
**Scope:** Basic strategy authoring and every downstream backtest path. Pro remains visible but unavailable.

## 1. Goal

Every Basic capability that the UI presents as usable must work through the real service boundary:

1. edit in the browser;
2. serialize into a canonical semantic document;
3. save and reload through Backend;
4. validate with stable blocking errors and warnings;
5. compile into an immutable execution plan;
6. release a bot and pin every execution input;
7. execute in the BASIC, CUSTOM, and COMPETITION lanes;
8. query an immutable result; and
9. render the same terminal state and result in the UI.

Passing a build, a mocked browser test, or an RSI-only integration test does not satisfy this goal.

## 2. Product boundary

### 2.1 Basic is the executable strategy mode

The executable Basic surface contains the published twelve condition blocks, one schedule trigger, and one terminal order action. It supports:

- one of `30m`, `1h`, `4h`, and `1d` as the single strategy clock;
- at most four partitions;
- at most one BUY and one SELL container per partition;
- at most five conditions per container;
- at most five instruments per partition; and
- at most sixty completed bars of warm-up history.

The current catalog `basic-elements:2026-08-08` is the compatibility baseline. Schema or execution-meaning changes publish a later immutable catalog version; they do not mutate the baseline.

### 2.2 Pro is explicitly unavailable

Pro remains visible so its UI can be designed, but the product must not imply that it is executable. Every Pro entry point displays a stable “준비 중” state. Create, save, validate, release, and backtest actions are disabled and cannot produce a synthetic success response.

### 2.3 Draft validity and data availability are different

Backend validation decides only facts that follow from the semantic document and its pinned catalog. Market-data and feature availability are decided when release or backtest inputs are selected. A structurally valid strategy can be released even when local data is absent. The request then becomes `UNAVAILABLE`, naming the missing instrument, resolution, interval, dataset, or feature materialization. No layer may silently substitute another resolution, instrument, feed, feature, or mutable input.

## 3. Canonical execution path

```text
Basic editor
  -> semantic document
  -> Backend draft + edit sequence + lease
  -> authoritative validation
  -> immutable compiled plan
  -> bot release + input pins + Outbox
  -> BASIC/CUSTOM/COMPETITION producer queue
  -> lane intake and execution queue
  -> Backtest runtime
  -> immutable result manifest and relational summary
  -> Backend result API
  -> Backtest UI
```

The UI is responsible for responsive editing feedback. Backend is authoritative for validation and compilation. Backtest is authoritative for execution. PostgreSQL is authoritative for durable state, and immutable object versions are authoritative for large result artifacts.

## 4. Shared capability contract

A machine-readable conformance fixture covers every published Basic element. Each case records:

- element code and allowed BUY/SELL containers;
- editable parameters, types, units, defaults, enumerations, and numeric bounds;
- valid boundary examples and invalid examples;
- data and warm-up requirements;
- expected compiler operation and arguments;
- expected runtime outcome for true, false, missing-input, and malformed-input cases;
- stable validation or warning codes; and
- the Korean review sentence produced from the same meaning.

UI, Backend, and Backtest tests consume the same cases. A root parity verifier fails when a visible UI block, published catalog element, compiler operation, runtime operation, or fixture is missing from any other set.

The fixture is verification data, not a second source of product truth. The approved specification and active catalog remain authoritative, and fixture hashes bind cases to the catalog version they prove.

## 5. Basic semantic document

The UI snapshot remains presentation-only. All execution-affecting values are represented in the semantic document:

- partition identity and budget cap;
- container identity and side;
- stable instrument identifiers;
- selected resolution;
- ordered condition blocks and typed parameters;
- schedule behavior;
- terminal order behavior;
- re-entry or re-execution behavior; and
- per-instrument maximum holding percentage.

Labels, descriptions, coordinates, open panels, selected blocks, and viewport state remain outside the semantic hash.

The per-instrument holding cap is no longer an inert editor value. The new catalog binds it to the terminal order meaning. The compiler carries one deterministic cap per instrument into the compiled plan. At execution time, the cap includes current position plus accepted and reserved exposure. Reaching the cap blocks only orders that increase risk. It never creates an automatic sell, liquidation, or recommendation.

## 6. Validation and warning model

### 6.1 Blocking errors

Release is blocked for:

- unknown, retired, or catalog-mismatched elements;
- missing required values or unsupported extra parameters;
- values outside the published schema;
- invalid period relationships such as a short moving average not shorter than the long average;
- invalid container placement;
- missing or duplicate terminal actions;
- more than five conditions, five instruments, or four partitions;
- missing BUY/SELL structure required by the selected template;
- invalid allocation totals or non-positive caps;
- unsupported cycles, re-entry modes, or order settings;
- disconnected or unreachable execution-affecting blocks; and
- a semantic document whose canonical hash does not match the validated edit sequence.

### 6.2 Warnings

Warnings do not block release unless a separate blocking invariant is also violated. Stable warnings cover:

- duplicate equivalent conditions;
- contradictory bounds on the same operand;
- a condition that can be proven always true or always false;
- repeated-order exposure caused by “while satisfied” behavior;
- a signal with no effective position change because the holding cap is already reached;
- a SELL flow that cannot act without a position; and
- unusually restrictive combinations that are valid but likely to produce no candidates.

The UI maps Backend codes to one user message and focuses the exact partition, card, block, or setting. Unknown server codes remain visible as a safe generic failure with the correlation identifier; they are never treated as success.

## 7. Compilation and runtime semantics

Compilation is deterministic for the semantic document, catalog version, compiler version, and instrument catalog version. The compiled plan contains no draft, UI layout, credentials, provider secret, or mutable data body.

Every condition block compiles to a runtime operation supported by Backtest. The runtime must cover all twelve conditions:

- price comparison;
- price change percentage;
- volume comparison;
- consecutive movement;
- SMA cross;
- RSI cross;
- MACD cross;
- Bollinger reversal;
- position return;
- holding period;
- peak return; and
- drawdown from peak.

Schedule and terminal order settings are executed, not merely serialized. BUY sizing uses partition-available cash. SELL sizing uses unreserved sellable quantity. Candidate batching applies allocation and holding caps before execution. Fee, slippage, precision, calendar, completed-bar, and no-look-ahead rules remain versioned execution-policy inputs.

Missing historical inputs never become a false condition. They produce a typed unavailable or data-gap outcome according to the pinned policy.

## 8. Backtest lanes and results

The same immutable bot release is usable in:

- `BASIC`: the one automatic official run created with release;
- `CUSTOM`: a user-selected inclusive evaluation period; and
- `COMPETITION`: the locked hidden period and shared competition inputs.

Each lane retains its own queue, DLQ, idempotency scope, and concurrency limit. Tests must prove that lane isolation, retries, cancellation, leases, duplicate delivery, and terminal publication do not change strategy meaning.

The UI distinguishes loading, empty, queued, running, cancelling, cancelled, complete, failed, unavailable, and forbidden. A result is complete only after relational state and every immutable object referenced by the manifest agree.

## 9. Test strategy

### 9.1 Element-level coverage

For every editable numeric value, tests include the minimum, maximum, immediately inside each boundary, immediately outside each boundary, zero, negative, decimal, empty, and malformed representations as applicable. Enumerations cover every allowed value plus an unknown value.

Each element has UI serialization, Backend schema/assembly validation, compiler, runtime true/false, unavailable, and review-text tests.

### 9.2 Composition coverage

Generated tests cover all element types while varying side, order, resolution, instrument count, partition count, and edited parameters. Pairwise generation is used for the broad combination space, supplemented by curated adversarial cases:

- the maximum-size valid strategy;
- duplicate and contradictory conditions;
- multiple sections sharing instruments;
- BUY and SELL triggering at the same instant;
- caps already reached or reached by reserved orders;
- insufficient warm-up and mid-period gaps;
- cancellation versus completion races;
- same-key retry and conflicting idempotency reuse; and
- missing, changed, duplicate, or hash-mismatched pins.

### 9.3 Real full-stack E2E

Mocked Playwright tests remain UI contract tests and say so explicitly. A separate real E2E starts the repository Docker environment and drives:

1. local signup/login;
2. Basic strategy creation through the browser;
3. instrument and block selection;
4. editing every material value;
5. warning and blocking-error display;
6. save/reload and semantic equality;
7. validation and release;
8. automatic run completion;
9. custom period run completion;
10. eligible competition run completion;
11. result detail rendering; and
12. unavailable, failed, cancelled, and forbidden states.

At least one generated suite uses the real Backend, PostgreSQL, queues, data objects, Backtest intake, and worker. An RSI-only plan cannot satisfy the catalog coverage gate.

## 10. Database and migration policy

The consolidated V1 is now an applied baseline. All schema, catalog, and seed changes for this work are introduced through a later Flyway migration and mirrored into the root CI bundle. Existing applied migration content remains immutable.

The migration publishes a new immutable Basic catalog version for changed terminal order and cap semantics. Old released bots continue to resolve their pinned historical catalog and compiled plan.

## 11. Delivery order

1. Add the shared capability fixture and cross-repository parity gate.
2. Close UI semantic serialization and Pro-unavailable gaps.
3. Close Backend validation, warnings, persistence, and compiler gaps.
4. Close Backtest operation and holding-cap execution gaps.
5. Publish the later catalog migration and refresh the central Flyway bundle.
6. Replace RSI-only evidence with full catalog and composition integration tests.
7. Add browser-to-result real E2E and negative-state coverage.
8. Run the complete verification matrix, create a PR, require all checks including GitGuardian, merge, and update local `develop`.

Each behavioral fix follows red-green-refactor. A failing regression test must reproduce the missing behavior before production code changes.

## 12. Completion evidence

Completion requires all of the following:

- every visible Basic element maps one-to-one across UI, catalog, compiler, runtime, and conformance cases;
- every valid UI-produced document saves, reloads, validates, and compiles without semantic drift;
- every compiled plan either executes or returns a typed missing-input result without substitution;
- BASIC, CUSTOM, and COMPETITION runs preserve the same release meaning;
- real result state and UI state agree for every terminal state;
- Pro cannot produce an executable or successful response;
- UI tests, Backend tests, Backtest tests, type checks, builds, Flyway integration, generated composition tests, and real full-stack E2E pass from a clean checkout; and
- the PR is green, GitGuardian reports no secret, and the merge commit is present on remote `develop`.

The final report includes the element-by-element support matrix, exact verification commands, test counts, PR and merge commit, and any remaining product limitation. No limitation may be hidden behind a passing mocked test.
