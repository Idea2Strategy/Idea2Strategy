---
schema_version: 1
id: decision.strategy.basic-catalog-v1
kind: decision
status: approved
revision: 1
refs:
    - capability.strategy.basic
    - decision.modes.basic-pro
    - policy.strategy.no-ai
---

# decision.strategy.basic-catalog-v1

Choice: Basic strategy conditions are selected at one of four bar periods — 30 minutes, 1 hour, 4 hours, and one day. One-minute bars are the aggregation source for those periods and the basis on which fills are evaluated; they are never a selectable condition resolution. The published element catalog `basic-elements:2026-08-07` is the canonical Basic block set: twelve conditions, one schedule trigger, and one terminal order action. A Basic strategy carries at most five conditions per container, one buy and one sell container per section, four sections per strategy, five instruments per section, and reads at most sixty completed bars of history.

Rationale: The four periods match what the product offers and what adjusted market data is published at; the shortest is 30 minutes because adjusted bars exist only from that period upward. Separating the aggregation and fill layer from the selectable resolutions is what stopped the editor from defaulting to a period the product does not have. The limits are derived from the catalog itself where possible — sixty bars is the largest period any published element requests — so the two cannot drift, and each bounds per-event evaluation cost while staying above any shape a Basic user plausibly builds.
