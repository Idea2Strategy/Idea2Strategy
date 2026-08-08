# Backtest RSI resolution alignment proposal

Status: **implementation draft; product-authority approval required**

Requested: 2026-08-08

Affected catalog: `basic-elements:2026-08-08`

## Requested product meaning

Every newly released Basic strategy selects exactly one execution resolution from
`30m`, `1h`, `4h`, or `1d`. That same value identifies all of the following:

1. the adjusted market bars used by the strategy;
2. the RSI calculation cadence;
3. the immutable `RSI_14` feature definition and output feed;
4. the pinned feature materialization consumed by the backtest;
5. the bar-close evaluation and pricing clock.

The active path does not resample or substitute `1m`, `5m`, or `15m` data. The legacy
`RSI_14@1m` definition and feed remain immutable and readable only so historical plans
that already pin the legacy catalog continue to replay.

## Proposed immutable identities

| Resolution | Feature definition UUID | Definition hash | Output feed UUID |
|---|---|---|---|
| `30m` | `4b1c6801-0259-5176-a857-0e5ea923d898` | `363f534dc77c6af0ebfe58f35be4fd2aa208906b1eaa36b550b17e9acb8692e4` | `57794d8c-2254-53e4-966e-44f97edd9e6a` |
| `1h` | `2e18c093-5d4e-5d9a-bd22-b7e5679f1a3e` | `9b8512c0502ca80e1804711ac624eb4a3b4e294a875dac2364e3510e284cc8b9` | `28012549-4f45-56d3-8bb6-329e4c7a9d77` |
| `4h` | `1b2785bd-20f0-50a2-ae96-6a1f7bad74b9` | `da3aff028a1fdef861abb1d68852e2ba3a91ed3917f7c7196e2d43ef48176b2c` | `e1d7d508-aaf1-5ae9-8098-c4af870f6fa4` |
| `1d` | `eddfb2d4-8586-5260-8fc9-9c8125990270` | `0cf646eb9cacf5826d26f7dcb982bf7cec9213cc438b99716ac47883aa04ba04` | `6d2647f8-5caf-55ee-8821-869dc693f68a` |

All four definitions use `RSI_14`, calculator `rsi:1.0.0`, adjusted close, XNYS,
`SIMPLE_AVERAGE_BOUNDED_WINDOW`, output type `NUMBER`, and 15 history points. A
definition UUID cannot be paired with another resolution.

## Implementation behavior

- Backend validation reports deterministic requirements only. Availability is checked
  against pinned artifacts at release/request time.
- The active element catalog declares `RSI_14` only for `BASIC_RSI_CROSS`; raw adjusted
  bars remain a platform input and are not expressed as a per-element availability claim.
- Compilation and immutable release select the feature definition by
  `(feature code, selected resolution)`, not by feature code alone.
- Data Pipeline publishes one deterministic feature feed per definition/resolution and
  rejects identity drift.
- Backtest verifies the exact definition, feed, materialization, object version, schema,
  hashes, and resolution. `RSI_CROSS` reads pinned current and prior values and fails
  closed on a missing or gapped value; it never recomputes RSI from closes.
- User cancellation retains the recommended terminal behavior: accepted queued/running
  cancellation ends as `CANCELLED`, is acknowledged, and is not sent to the DLQ.

## Verification evidence

- The runtime catalog and binder tests cover the exact definition/feed identities for all four
  supported resolutions and reject cross-resolution substitution.
- The root PostgreSQL 16 + LocalStack integration journey executes an active-catalog
  `RSI_CROSS@30m` plan through BASIC, CUSTOM, and COMPETITION on one runtime. It proves retry,
  duplicate suppression, result persistence, immutable versioned feature input, and fail-closed
  rejection when the pinned feature object version is replaced.
- The local proof does not replace the required deployed-environment run or product-authority
  approval.

## Issue #248 impact

The current authoritative comment on
[Issue #248](https://github.com/Idea2Strategy/Idea2Strategy/issues/248#issuecomment-5222189024)
states that `RSI_14` has one fixed `1m` identity. That clause is incompatible with the
latest requested product meaning above. The issue must not be closed or described as
fully resolved until a configured product authority approves this replacement and a
deployed three-lane end-to-end run proves Basic, Custom, and Competition request intake,
pin resolution, execution, publication, cancellation, retry, duplicate, and DLQ behavior.

## Governance and release gate

`stackcord governance check --json` did not return a fresh approved authority observation
for the protected fingerprint. Therefore this change is isolated as a proposal and draft
implementation. It does not modify `specs/**`, `contracts/**`, `.harness/governance.yaml`,
or `docs/collaboration-policy.md`, and it must not be called approved, integrated,
Deploy Ready, or production-releasable until one of the configured product authorities
approves the exact protected change and the canonical sources are updated.

Draft implementation PRs:

- Root: [Idea2Strategy#371](https://github.com/Idea2Strategy/Idea2Strategy/pull/371)
- Backend: [Idea2Strategy-backend#236](https://github.com/Idea2Strategy/Idea2Strategy-backend/pull/236)
- Backtest: [Idea2Strategy-backtest-engine#67](https://github.com/Idea2Strategy/Idea2Strategy-backtest-engine/pull/67)
- Data Pipeline: [Idea2Strategy-data-pipeline#44](https://github.com/Idea2Strategy/Idea2Strategy-data-pipeline/pull/44)
