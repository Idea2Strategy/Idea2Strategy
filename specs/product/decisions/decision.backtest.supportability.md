---
schema_version: 1
id: decision.backtest.supportability
kind: decision
status: approved
revision: 1
refs:
    - capability.backtest.automatic
    - scenario.strategy.release
    - decision.strategy.basic-catalog-v1
    - quality.reproducibility
---

# decision.backtest.supportability

Choice: Strategy validation decides only what is a function of the strategy document — document well-formedness against the pinned element catalog, and the strategy's own data requirements, which it records as information. It never decides whether that data is available. Availability is resolved when a release or a backtest is requested, against the immutable dataset manifest and feature materializations already pinned into that request, and a shortfall produces the `backtest-unavailable` state naming what is missing. That state does not block release. An element declares the official features it reads; it does not name a market-data feed. Corporate-action-adjusted bars at the evaluated resolution are a platform invariant rather than a per-element declaration.

Rationale: A validation run calls itself deterministic and is pinned by edit sequence, semantic hash, and catalog version. Data coverage is none of those — it is infrastructure state that changes with what the pipeline has published, so a stored run could carry a conclusion that was already false while nothing about the strategy had changed, and release re-checked the pin without ever re-checking coverage. The backtest execution contract already answers the same question at the moment it matters, against pinned artifacts, failing closed on missing or unavailable inputs with no substitution, so the copy inside validation was redundant, unpinned, and weaker. Naming a feed per element made this worse: the token named nothing in the publication model, which expresses bar data as a data layer and a resolution rather than a feed kind, and no feed satisfying it could be published without breaking corporate-action regeneration. Since every official feature reads adjusted bars, that requirement is an invariant of the platform and belongs stated once rather than repeated, unsatisfiably, in every element.
