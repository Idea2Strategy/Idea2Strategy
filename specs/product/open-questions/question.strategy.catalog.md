---
schema_version: 1
id: question.strategy.catalog
kind: decision
status: unknown
revision: 3
refs:
    - decision.strategy.basic-catalog-v1
    - decision.backtest.supportability
---

# question.strategy.catalog

Which risk element belongs in the Basic catalog, and where does a per-symbol holding cap live?

The Basic block set, the four bar periods, and the composition limits are settled by `decision.strategy.basic-catalog-v1`. How an element declares the data a backtest needs is settled by `decision.backtest.supportability`. Two items remain, each requiring a new published catalog version: a `RISK_POLICY` element and its stop semantics, and moving the per-symbol holding cap out of editor layout into an order-element parameter.
