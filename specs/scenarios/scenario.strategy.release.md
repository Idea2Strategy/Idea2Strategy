---
schema_version: 1
id: scenario.strategy.release
kind: scenario
status: approved
revision: 1
refs:
    - role.strategy-author
---

# scenario.strategy.release

Actor: role.strategy-author

Trigger: A validated working strategy is released.

Outcome: The server creates an immutable version and starts its single official automatic backtest.

Failure: Missing required policies or unsupported backtest blocks prevent release or return an explicit backtest-unavailable result without substitution.
