# Partition-aware backtest input selection implementation plan

**Goal:** Pin and execute the minimum deterministic manifest set required by every Basic flow's instruments, resolution, warm-up, and evaluation interval.

**Architecture:** Backend derives the immutable resolution requirements and solves an interval-cover problem independently per resolution. The request and durable input bundle carry every selected pin and the explicit evaluation interval. Backtest binding verifies segmented covers, derives flow-local series requirements, reads only the instruments required at each resolution, and prices each flow from its own clock.

**Repositories:** root, Backend, Backtest Engine.

---

## 1. Backend selector contract

- Extend selector tests with yearly segmented manifests, mixed resolutions, minimum-cover preference, revision tie-breaking, and gap rejection.
- Replace the one-period/one-manifest-per-resolution algorithm with deterministic minimum interval cover.
- Keep all selected pins sorted and stable.
- Include instrument scope in catalog data when present so future instrument manifests cannot be silently substituted.

## 2. Request interval contract

- Add tests proving dispatch carries the stored evaluation interval into the worker job.
- Parse and validate the explicit interval in the worker envelope.
- Preserve representative dataset fields strictly as compatibility aliases.

## 3. Worker segmented binding

- Add binding tests for repeated-resolution adjacent segments, gap rejection, conflicting overlap rejection, and mixed-resolution covers.
- Index resolved manifests by resolution and validate each required interval against its ordered segment cover.
- Stop requiring one unique manifest per resolution or one identical coverage window across all resolutions.

## 4. Flow-local execution requirements

- Add runtime tests showing unrelated flow instruments and resolutions are not cross-producted.
- Derive raw and feature requirements from each flow and the feature's declared instrument set.
- Derive each flow's reference series and use it for its candidate price.
- Reject ambiguous position-only clocks rather than falling back to 30m.

## 5. Efficient reading and deterministic replay

- Add orchestrator tests proving each manifest reads only instruments required for its resolution.
- Merge events from adjacent segments deterministically and reject duplicate source bars.
- Compute availability with the actual interval of each event series.

## 6. Real-data verification

- Run Backend and Backtest Engine focused suites, then full repository checks.
- Rebuild local services.
- Create/run a mixed-instrument, mixed-resolution strategy over the maximum supported local interval.
- Compare durable pins with the selected DB manifests and sample replay bars with original Parquet OHLCV.
- Record terminal status, decisions, fills, and input manifest evidence.

## 7. Delivery

- Run secret scanning and collaboration checks.
- Review the diff for contract compatibility and unrelated changes.
- Commit and push Backend and Backtest Engine branches, then update and push root gitlinks and documentation.
