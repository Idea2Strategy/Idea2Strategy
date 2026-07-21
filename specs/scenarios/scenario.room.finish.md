---
schema_version: 1
id: scenario.room.finish
kind: scenario
status: approved
revision: 1
refs:
    - role.room-participant
---

# scenario.room.finish

Actor: role.room-participant

Trigger: A room reaches its official evaluation end.

Outcome: Room performance is frozen using non-mutating virtual liquidation for scoring, while an explicitly continued bot keeps its actual state as a private bot.

Failure: A missing continue choice causes the real bot to stop, cancel open orders, and settle positions under the established stop procedure.
