---
schema_version: 1
id: scenario.strategy.release
kind: scenario
status: approved
revision: 2
refs:
    - role.strategy-author
---

# scenario.strategy.release

Actor: role.strategy-author

Trigger: A validated working strategy is released.

Outcome: In one transaction the server re-validates the current document, copies it into an independent bot snapshot hierarchy that records no strategy identifier, source or lineage, and queues that bot's first official backtest.

Failure: Missing required policies or unsupported backtest blocks prevent release or return an explicit backtest-unavailable result without substitution.
