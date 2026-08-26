# Partition-aware minimal backtest input selection

Date: 2026-08-26
Authority: `user:kcrmin`

## Outcome

An official Basic backtest derives the exact market-series requirements of each executable flow and pins the smallest deterministic set of immutable dataset manifests that covers those requirements. A run may therefore consume multiple resolutions and multiple adjacent manifest periods without runtime discovery, substitution, or synthetic data.

## Confirmed failure

The local publication contains adjusted 30m, 1h, 4h, and 1d history from 2016 through 2026. Only 30m also has one full-range manifest. The current selector chooses at most one manifest per resolution and requires every chosen manifest to have the same period. The worker then rejects repeated resolutions. Consequently the full-range 30m path succeeds while equivalent 1h, 4h, and 1d runs fail even though their yearly manifests collectively cover the requested period.

The runtime also cross-products all plan instruments with every global feature and resolution, and uses one plan-wide reference series to price every flow. That is not the strategy the user authored when flows use different instruments or clocks.

## Requirement model

The immutable compiled plan is the authority. For each flow, derive normalized requirements keyed by:

- flow/partition key;
- official instrument id;
- data kind and exact resolution;
- warm-up start and evaluation interval;
- feature definition/materialization where applicable.

Requirements are deduplicated only when their instrument, data kind, and resolution match. Warm-up uses the greatest lookback among the matching flow steps. Requirements from unrelated flows are never cross-producted.

## Dataset selection

Backend selects available adjusted-bar manifests as of the request instant. For each required resolution it chooses a deterministic minimum interval cover from the required warm-up start through the requested evaluation end.

Selection rules, in order:

1. exact data layer, schema, feed, resolution, availability instant, and policy bounds;
2. no uncovered interval inside the required range;
3. newest revision at an otherwise equivalent boundary;
4. fewest manifests;
5. least coverage outside the required range;
6. stable manifest-id ordering as the final tie-break.

Universe manifests may contain multiple instruments. They are selected once for a resolution/period and the worker reads only the instruments required from that resolution. An instrument-scoped manifest, when present, must match the required instrument exactly. Silent resolution substitution and runtime resampling remain forbidden.

The request atomically pins every selected dataset and feature materialization. Evaluation start/end are carried to the worker explicitly; manifest coverage no longer changes the requested evaluation interval.

## Worker binding and replay

The worker resolves and verifies every pin before execution. Multiple manifests with the same resolution are valid when their effective coverage forms a coherent interval cover. Conflicting overlaps, gaps, changed hashes, wrong schemas, or unbound datasets fail before replay.

Resolved inputs are indexed by `(data kind, resolution)`. Each index entry contains its ordered manifest segments and exact required instrument ids. Readers filter each segment by that requirement set. Events from all series are merged deterministically by occurrence instant, resolution duration, instrument id, and source identity.

Each flow obtains requirements and its order reference price from its own condition series. Position-only flows inherit the paired instrument's executable market clock deterministically; ambiguity is rejected rather than defaulted to 30m.

## Compatibility

The legacy representative dataset fields remain populated only as compatibility aliases. They do not control coverage, requirement derivation, or replay. Competition's existing single-dataset contract is unchanged; this change applies to Basic/custom official backtests.

## Failure reporting

Input failures name the missing tuple and interval, for example:

`AAPL / 4h / 2021-01-01..2022-01-01 is not covered by an available adjusted dataset manifest`.

Deterministic input failures terminate as unavailable/failed according to the existing lifecycle contract and are not retried.

## Verification

Tests must prove:

- one resolution covered by several yearly manifests;
- several resolutions in one run;
- different instruments and clocks in different flows without a cross-product;
- minimum-cover determinism, revision preference, gap rejection, and overlap conflict rejection;
- explicit evaluation interval independent of manifest outer coverage;
- flow-local condition evaluation and reference pricing;
- exact manifest hashes and original Parquet OHLCV values are consumed;
- a real local multi-flow run reaches a terminal state with the expected pins, decisions, and fills.
