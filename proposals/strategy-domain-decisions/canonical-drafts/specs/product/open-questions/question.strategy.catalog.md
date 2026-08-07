---
schema_version: 1
id: question.strategy.catalog
kind: decision
status: unknown
revision: 2
refs:
    - decision.strategy.basic-catalog-v1
---

# question.strategy.catalog

Which risk element belongs in the Basic catalog, where does a per-symbol holding cap live, and how should an element declare the market data a backtest needs?

The Basic block set, the four bar periods, and the composition limits are settled by `decision.strategy.basic-catalog-v1`. Three items remain, each requiring a new published catalog version: a `RISK_POLICY` element and its stop semantics, moving the per-symbol holding cap out of editor layout into an order-element parameter, and replacing the current `feed`-and-resolution requirement, which names a token the market-data publication model does not define.
