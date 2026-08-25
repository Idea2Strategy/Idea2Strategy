---
schema_version: 1
id: question.strategy.catalog
kind: decision
status: resolved
revision: 4
refs:
    - decision.strategy.basic-catalog-v1
    - decision.backtest.supportability
---

# question.strategy.catalog

Which risk element belongs in the Basic catalog, and where does a per-symbol holding cap live?

Resolved for the executable Basic catalog published as `basic-elements:2026-08-25`: no separate `RISK_POLICY` element is added. The per-symbol holding cap moves out of editor layout into the terminal `BASIC_EQUAL_ALLOCATION_ORDER.maxPositionPercent` parameter. It blocks only risk-increasing orders whose current position plus reserved BUY exposure would exceed the cap; it does not liquidate, reduce, or otherwise create an order by itself. A future stop-loss or forced-liquidation product is a separate decision and catalog version, not an implicit behavior of this cap.
