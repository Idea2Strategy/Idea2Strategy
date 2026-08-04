# Corporate-action approval contract proposal

Issue: Idea2Strategy/Idea2Strategy#143 (closed — data source and data rights decided; this is the one item it left unpinned)

Blocked implementation: Idea2Strategy/Idea2Strategy-data-pipeline#16 (D15), then F92 on Idea2Strategy/Idea2Strategy#28

Base: root `origin/develop` at `fdcaf1d2cb293da2bf6d059d13eb3713112c7ac0`

This directory is intentionally isolated. Nothing here is canonical or approved. It must not be copied into `contracts/` until `user:kcrmin` approves the exact proposal commit through the configured GitHub review provider.

## Why this proposal exists

Root #143 fixed D14's data source (extend Alpaca) and granted all three data rights, including retention and regeneration after the subscription ends. That closed the decision it tracked, but one boundary item was deliberately **not** closed with it: A's admin-mcp approval boundary is on `develop` and exposes `corporate_action_candidate.approve` with an RBAC `permissionId`, a `requestSchemaVersion`, and allowed input/output field sets — yet the **fail-closed rules for 미승인·위조·중복·취소·superseded are not written anywhere**.

An allowed-field set states what may arrive. It does not state what may be trusted. Leaving the gap means D defines the semantics of A's approval gate, which is exactly the class of defect root #138 and #181 already recorded elsewhere in this repository: a consumer deciding something the producer owns.

## Contents

- `contract.md`: the required fields of an approval result, five fail-closed rules, provider ownership, and audit reason codes.
- `validate-contract.test.mjs`: structural regression checks so the proposal cannot be gutted to a stub while still reading as a contract.

There is deliberately **no** `schema.draft.dbml`. This contract authors no DDL: review state lives in the `terms_document` of the canonical `market_data.corporate_actions` row with an append-only `review_history`, which is where the merged D implementation already puts it.

## Proposed obligations

- an approval result must carry candidate identity, decided version, evidence binding, actor, audit binding, and permission/schema version — any absence refuses;
- unapproved is deny-by-default, and an unwired approval provider refuses instead of reporting zero approvals;
- an unknown `requestSchemaVersion` is never read leniently, and a `decided version` that disagrees with D's `terms_hash` refuses;
- duplicates converge idempotently without re-triggering regeneration, while a re-decision is refused outright;
- a withdrawal is recorded as a new event and regenerates forward, leaving already-published dataset versions reproducible;
- exactly one approval holds authority per `(instrument, event type, effective date)`, and a supersede must name the prior candidate explicitly or it is a conflict;
- the `CORPORATE_ACTION` provider is owned by A, because D has no authority to interpret operator identity, permission, MFA freshness, or audit evidence.

## Validation

```text
npm run proposal:validate:boundary
npm run proposal:validate:corporate-action-approval
npm run dbml:validate
```

`proposal:validate:boundary` is the meaningful gate here: it asserts this change touches no protected canonical path (`contracts/`, `specs/`, `db/schema.dbml`, `.harness/governance.yaml`, `docs/collaboration-policy.md`). This proposal adds only files under `proposals/` plus one `package.json` script entry.

**Not executed locally.** No Node toolchain is installed on the authoring machine (`node`, `npm`, `pnpm`, `npx` all absent), so `validate-contract.test.mjs` has not been run — its first execution is in CI or by the reviewer. Every string and pattern it asserts was instead verified directly against `contract.md` and `README.md` with a literal-match sweep, so the assertions target text that exists; what is unverified is the harness itself, not the claims.

## Canonical apply order after approval

1. Rebase onto the then-current root `develop` and re-run the validators.
2. Add the reviewed contract to `contracts/business/corporate-action-approval.v1.md` with `status: approved` and the frontmatter refs `role.operator`, `journey.operator.administer`, `capability.audit.evidence`, `policy.legal.block-uncertain` (all four verified to exist under `specs/`).
3. Register it in `contracts/registry.yaml` as `contract.operations.corporate-action-approval.v1`, `kind: business`, `providers: [workspace.root]`, `consumers: [workspace.backend, workspace.data-pipeline]`, with `fingerprint` = `sha256` of the canonical file bytes, and link it from `contracts/business/index.md`.
4. Only then start D15 on data-pipeline#16, replacing the test-only `AdminDecision` injection with the real result.
5. F92 follows D15.
