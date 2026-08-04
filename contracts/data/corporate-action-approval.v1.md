---
schema_version: 1
id: contract.operations.corporate-action-approval.v1
kind: data
status: approved
revision: 1
refs:
  - role.operator
  - journey.operator.administer
  - capability.audit.evidence
  - policy.legal.block-uncertain
  - contract.operations.operator-trust.v1
  - contract.operations.outbox-delivery.v1
  - quality.failure-safety
---

# contract.operations.corporate-action-approval.v1

Status: approved canonical contract. Product authorities `user:pjy008008` and
`user:Juwon-Na` approved the exact source proposal on root PR #204 before this
canonical write.

## 1. Boundary and envelope

Only an approval result issued by backend Admin MCP for target domain
`CORPORATE_ACTION` can make a researched corporate action official. The backend
owns provider authentication, authorization, active-operator resolution, MFA
freshness, permission evaluation, and audit evidence. Data pipeline consumes the
result through the transactional-outbox backend relay and never reconstructs
those decisions from transport identity headers.

The versioned delivery envelope contains `candidateId`, `decision`,
`decidedContentHash`, `evidenceBindings`, `actorId`, `auditId`, `permissionId`,
`requestSchemaVersion`, `decidedAt`, `supersedesCandidateId`, `deliveryId`, and
`aggregateSequence`. `decision` is `APPROVE` or `WITHDRAW`. Identifiers are UUIDs,
timestamps are UTC instants, `aggregateSequence` is a positive integer, and
`evidenceBindings` is a non-empty set of lower-case SHA-256 content hashes.

`candidateId` must equal the deterministic `market_data.corporate_actions.id`.
`decidedContentHash` is the decision version and must be exactly equal to that
row's lower-case SHA-256 `terms_hash`; no numeric version may substitute for the
content actually reviewed. Every evidence binding must be present in the stored
`terms_document` evidence set. `actorId` must resolve to an `ACTIVE operator` in
`operations.operator_accounts`. `auditId` must recover the same decision from
backend audit evidence. `permissionId` and `requestSchemaVersion` must exactly
match the registered Admin MCP tool values.

## 2. Fail-closed acceptance

Data pipeline refuses and applies nothing if the provider is unwired, any field
is missing or malformed, the candidate is unknown, actor or audit evidence does
not resolve, evidence is unbound, permission differs, the schema version is an
unknown schema version, or `decidedContentHash` differs from `terms_hash`. Raw
operator, ALB, servlet, and queue headers are not permission evidence. Test-only
local decision injection does not exist on a production path.

Refusal is durable and carries a distinct reason code. At minimum suspected
forgery, unknown schema, permission mismatch, inactive actor, unknown candidate,
unbound evidence, stale content hash, reversed sequence, unnamed supersede, and
conflicting re-decision are distinguishable. A refused delivery acknowledges no
business effect and cannot trigger dataset regeneration.

## 3. Idempotency, order, and re-decision

The pair (`candidateId`, `decidedContentHash`) and `deliveryId` are durable
idempotency identities. Repeating the same semantic result converges on the
recorded outcome and later deliveries do not trigger regeneration again. A
reused identity with different content, an older `aggregateSequence`, or an
opposite decision for already-decided content is refused. Review history remains
append-only.

## 4. Withdrawal

Withdrawal is an explicit withdrawal event, never deletion or state rollback.
It carries and verifies the same proof fields as approval, changes the candidate
so it no longer contributes to future adjusted datasets, and regenerates once
from that fact forward. Previously published dataset manifests remain immutable
and reproducible.

## 5. Supersede

At most one approval contributes for an `(instrument, event type, effective
date)` subject. A replacement approval must set `supersedesCandidateId` to the
currently approved prior candidate. The prior candidate is marked `SUPERSEDED`,
the new one becomes `APPROVED`, and one regeneration uses only the new approval.
A same-subject candidate that does not explicitly name the prior candidate is
an unnamed-supersede conflict and is refused.

## 6. Storage and verification

This contract authors no DDL. Review state, append-only review history,
idempotency identities, refusal evidence, and supersede/withdrawal facts are
stored in the canonical row's `terms_document`. The implementation must verify
missing provider, forged proof, stale hash, duplicate, reversed order,
conflicting re-decision, withdrawal, named supersede, unnamed conflict, crash
redelivery, and single-regeneration behavior.
