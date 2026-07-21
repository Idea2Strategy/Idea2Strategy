---
schema_version: 1
id: scenario.bot.evaluate
kind: scenario
status: approved
revision: 1
refs:
    - role.bot-owner
---

# scenario.bot.evaluate

Actor: role.bot-owner

Trigger: Valid market or event data reaches an active bot.

Outcome: Strategies evaluate one at a time per bot, candidates converge through final order processing, and approved simulated orders enter the official ledger.

Failure: Invalid or stale inputs discard affected candidates, preserve prior official events, and record objective reasons without hidden orders.
