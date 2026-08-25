# Product Integrity Hardening Design

## Goal

Make every shipped customer and operator workflow truthful, reachable, authorized, and understandable from an empty account through strategy authoring, release, bot operation, backtesting, competition participation, and operator intervention.

## Non-negotiable product rules

- Existing strategy drafts, immutable releases, compiled plans, backtest results, and ledgers keep their meaning.
- PRO authoring is outside the current product scope. PRO controls may remain visible only as clearly unavailable future affordances and must never imply a working backend capability.
- Customer signup completes without email verification while SES is unavailable. The API and UI must describe the same terminal outcome.
- Market preview and backtests use only stored market data and approved server-side policies.
- Customers never choose internal policy versions, UUIDs, raw JSON, or operational correlation fields.
- Secret-room membership requires an account-bound, single-use invitation grant. Knowing a room UUID is never sufficient.
- Operator authentication remains username/password plus TOTP plus server session. Customer and operator navigation, session recovery, and permissions remain separate.
- Operator views may expose decision evidence and provenance but never private strategy source beyond the minimum authorized disclosure.
- Every remote surface distinguishes loading, genuine empty data, filtered empty data, forbidden, unauthenticated/session-expired, unavailable, conflict/stale, and retryable failure.
- Destructive or high-risk commands are idempotent and display a durable receipt independently from refresh failures.

## Architecture

### 1. Contract-first integration baseline

The root branch starts from `feature/fixed-max-range-backtest`. The UI submodule integrates the current customer-signup and internal-operator-session work before feature changes. Contract tests cover every response shape used by the UI. A repository check inventories frontend API paths and backend controller mappings so an unimplemented UI endpoint fails CI.

### 2. Identity-based customer actions

Bots, strategies, backtests, rooms, and participations are selected and routed by immutable IDs. Names are presentation only. List rows retain their IDs through dashboard drill-down, release receipts, detail selection, and destructive confirmations.

### 3. Server-owned policy decisions

Release and competition APIs accept product intent, then resolve the active immutable policy bundle on the server. The UI displays a human explanation of the applied policy but does not ask customers to select implementation versions. Existing releases are not rewritten.

### 4. Authorized competition lifecycle

Invitation consumption creates a short-lived account-bound admission grant. Admission locks the room and grant, validates access type, phase, eligibility, instrument scope, capacity, validation ownership, and stopped-bot slot semantics, then consumes the grant in the same transaction. Room detail is reachable for the owner and admitted/invited account across non-public phases. Official BACKTEST creation stays operator-only.

### 5. Guided empty-to-value journey

The dashboard derives onboarding progress from server facts: account exists, first strategy draft, valid strategy, released bot, completed backtest, and optional competition entry. Empty states show why the surface is empty and exactly one primary next action. Backtest records show strategy/bot names, date coverage, terminal status, attempts, and actionable failure detail.

### 6. Dedicated operator workspace

`/operations/*` uses the operator session and shell only. Navigation is generated from server permission IDs. Case review includes privacy-safe submission detail, evidence metadata, and history. Sanctions are selected from current case/account state instead of entered as raw IDs. Session expiry offers reauthentication without pretending a command failed.

### 7. Verification model

Each behavior begins with a failing unit, contract, integration, or browser test. Automated coverage includes duplicate display names, signup without verification, all async states, secret-room bypass attempts, policy enforcement, idempotent retries, operator RBAC, keyboard dialogs, and empty-account journeys. Final verification uses the local Docker stack, real stored market data, two customer accounts, and an operator account.

## Delivery slices

1. Restore the correct integrated UI baseline and immediate signup/operator sessions.
2. Close authorization and wrong-object risks.
3. Align customer policy and lifecycle workflows.
4. Rebuild empty states and backtest/competition presentation.
5. Complete operator decision UX and auditability.
6. Add whole-product API/button/E2E inventory and run full-stack verification.

Each slice is independently tested and committed. Root submodule pointers are updated only after the component commit is pushed.
