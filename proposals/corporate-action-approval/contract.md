# Corporate-action approval contract v1 proposal

Status: isolated canonical proposal. Not approved until product authority `user:kcrmin` reviews the exact commit through the configured GitHub review provider.

Scope: the single item root [#143](https://github.com/Idea2Strategy/Idea2Strategy/issues/143) left unpinned when it fixed D14's data source and data rights — the **fail-closed rules for an administrator's approval result**.

Consumers: [data-pipeline #16](https://github.com/Idea2Strategy/Idea2Strategy-data-pipeline/issues/16) (D15), and A's `apps/admin-mcp` `corporate_action_candidate.approve` as the producer. F92 (root [#28](https://github.com/Idea2Strategy/Idea2Strategy/issues/28)) consumes the approved result downstream.

## 1. Purpose and non-goals

This contract makes **only A's admin-mcp approval result** capable of producing an official corporate action and an adjusted-dataset regeneration. It governs exactly one seam: where D consumes the result of the `corporate_action_candidate.approve` tool.

The tool's allowed output field set is already owned by A's tool registration. This contract fixes what that field set **cannot** express — which results D must refuse. A field set states what may arrive; it does not state what may be trusted. Without the latter, D defines it, and the meaning of the approval gate leaks into the consumer.

Non-goals: corporate-action data source selection, research method, adjustment arithmetic, and the RBAC permission values themselves.

This proposal authors **no DDL**. Review state lives in the `terms_document` of the canonical `market_data.corporate_actions` row alongside an append-only `review_history`, which is where the merged D implementation already puts it. There is no `schema.draft.dbml` in this directory for that reason.

## 2. What an approval result must carry

D applies an `APPROVE` only when the result carries all of the following. If any one is absent, D **refuses and applies nothing**.

| Field | Obligation |
| --- | --- |
| candidate identity | The approved candidate's id. Must equal D's deterministic `market_data.corporate_actions.id`. If no row carries it, D refuses rather than creating one (`UnknownCandidateError`). |
| decided version | Fixes the candidate content the administrator actually saw. Must be comparable against D's `terms_hash`. |
| evidence binding | Identifies the researched evidence the decision rested on. Must be present in the evidence set of D's stored `terms_document`. |
| actor | The deciding operator subject, resolvable to an `operations.operator_accounts` row. |
| audit binding | Recovers this decision from A's audit evidence. |
| permission and schema version | The `permissionId` and `requestSchemaVersion` the tool registration declares. |

Raw operator, ALB, and servlet identity headers are not permission evidence. This restates the rule already fixed by [contract.operations.operator-trust.v1](../../contracts/business/operator-trust.v1.md) and applies it to approval results.

## 3. Fail-closed rules

### 3.1 Unapproved — deny by default

A researched action is inert. `REVIEW_REQUIRED` and `REJECTED` are indistinguishable from the dataset's point of view: neither contributes a factor, neither triggers a regeneration. Exactly one transition affects data — `REVIEW_REQUIRED -> APPROVED`.

D applies no candidate in the absence of an approval result. Test-only local decision injection must not exist on the production path. If the approval provider is unwired, D **refuses** rather than quietly processing zero approvals — "zero approvals" and "no provider" are indistinguishable, and reporting the latter as success means a missed split silently corrupts every adjusted price after it.

### 3.2 Forgery — an unproven result is not an approval

D refuses when any required field of §2 is absent, when the actor does not resolve to an `ACTIVE` operator, when `permissionId` differs from the value the tool registration declares, or when `requestSchemaVersion` is not a version D knows.

A future `requestSchemaVersion` is **not** interpreted leniently. Reading an unknown schema generously is precisely the point at which a forged result becomes indistinguishable from a valid one.

D refuses when `decided version` does not match its stored `terms_hash`. It means the content the administrator approved is not the content D would apply. This also occurs legitimately when a re-run changed the candidate, so the resolution is re-approval, not coercion.

### 3.3 Duplicate — idempotent, not re-applied

The same `(candidate identity, decided version)` approval may arrive more than once. The second and later arrivals **converge on already-applied and do not trigger regeneration again**. D's candidate recording is already idempotent by candidate identity (`record_candidate`); approval application must have the same property.

A duplicate is not a **re-decision**. Deciding an already-decided action the other way is refused (`ConflictingDecisionError`): the adjusted dataset built from the approval already exists and downstream consumers may have read it, so silently flipping the state would leave the catalog claiming `REJECTED` while the data remains. Reversal happens only through §3.5.

### 3.4 Cancellation — a withdrawal is a new fact

An approval withdrawal is not a deletion and not a state rollback. It is reflected by **recording the withdrawal as an explicit event and regenerating the adjusted dataset from that point forward**.

Dataset versions produced before the withdrawal remain and stay identified by their own manifests. This is deliberate: backtest results already computed from them must stay reproducible.

A withdrawal result carries the same required fields as §2. An unevidenced withdrawal is refused for the same reason as an unevidenced approval.

### 3.5 Superseded — exactly one approval holds authority

When a new approval arrives for the same `(instrument, event type, effective date)`, the prior approval becomes `SUPERSEDED` and **only the newest contributes to `approved_actions()`**. A state where two approvals both contribute a factor cannot exist — a split applied twice makes every adjusted price silently wrong by a factor of two.

A supersede must satisfy all of: the prior approval is marked `SUPERSEDED` rather than deleted; the new approval explicitly names the prior candidate identity; and regeneration runs once against the new approval.

A new approval that merely happens to target the same subject without naming the prior one is **not** a supersede but a **conflict**, and is refused.

## 4. Provider ownership

The `AdminMcpProviderPort` implementation for the `CORPORATE_ACTION` `targetDomain` is **owned by A (backend)**. D is the consumer of approval results, not the provider.

Rationale: the operator subject, permission, MFA freshness, and audit evidence an approval decision requires are all state A owns, and D has no authority to interpret any of them. If D were the provider, authenticity adjudication would move to D and §3.2 could not hold.

D receives A-issued approval results across a delivery boundary. The transport follows the same decision root [#138](https://github.com/Idea2Strategy/Idea2Strategy/issues/138) settled as a backend relay.

## 5. Audit

A refused approval result is recorded with a reason code. Suspected forgery, unknown schema version, and `terms_hash` mismatch must be **distinct** reasons, because their operational responses differ — security investigation, deployment-ordering problem, and re-approval request respectively.

## 6. Relationship to merged code

The merged D implementation already satisfies §3.1 and half of §3.3: `approved_actions()` returns only `APPROVED` rows, so unapproved and rejected candidates are structurally without effect; `record_candidate` is idempotent by candidate identity; and re-decision is refused by `ConflictingDecisionError`.

§3.2, §3.4, §3.5 and §4 are implemented when the real admin-mcp result replaces the test-only `AdminDecision` injection.
