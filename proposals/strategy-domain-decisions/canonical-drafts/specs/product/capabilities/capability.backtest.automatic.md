---
schema_version: 1
id: capability.backtest.automatic
kind: capability
status: approved
revision: 3
refs: []
---

# capability.backtest.automatic

Run one automatic official backtest when a bot is created, using locked data and calculation assumptions. The same immutable execution boundary also supports a user-selected period backtest and an official BACKTEST competition evaluation; each mode uses its own durable lane and cannot substitute mutable inputs for a locked bot release, dataset manifest, or policy version.
