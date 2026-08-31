---
schema_version: 1
id: decision.strategy.basic-catalog-v1
kind: decision
status: approved
revision: 2
refs:
    - capability.strategy.basic
    - policy.strategy.no-ai
---

# decision.strategy.basic-catalog-v1

Choice: Basic strategy conditions are selected at one of four bar periods — 30 minutes, 1 hour, 4 hours, and one day. That selected period is the strategy's only clock: it identifies the adjusted bars the conditions read, the cadence of every indicator they use, and the bar close on which orders price and fill. No shorter period is a selectable condition resolution, and the active path never resamples or substitutes a shorter one. The published element catalog `basic-elements:2026-08-08` is the canonical Basic block set: twelve conditions, one schedule trigger, and one terminal order action. A Basic strategy carries at most five conditions per container, one buy and one sell container per section, four sections per strategy, five instruments per section, and reads at most sixty completed bars of history.

Rationale: The four periods match what the product offers and what adjusted market data is published at; the shortest is 30 minutes because adjusted bars exist only from that period upward. Making the selected period the single clock is what keeps a released bot and its official backtest reading the same bars — a strategy evaluated on one period but priced on another could not be reproduced. The limits are derived from the catalog itself where possible — sixty bars is the largest period any published element requests — so the two cannot drift, and each bounds per-event evaluation cost while staying above any shape a Basic user plausibly builds.
