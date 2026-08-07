---
schema_version: 1
id: policy.strategy.immutable-release
kind: policy
status: approved
revision: 2
refs: []
---

# policy.strategy.immutable-release

A released bot's execution meaning and mode cannot be edited; only its presentation may change, meaning the bot name, partition and flow descriptions, coordinates and in-flow layout. The strategy a bot was released from stays editable and its later edits never reach that bot. Changing execution meaning requires releasing an independent new bot.
