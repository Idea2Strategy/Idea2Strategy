---
schema_version: 1
id: scenario.account.sanction
kind: scenario
status: approved
revision: 1
refs:
    - role.operator
---

# scenario.account.sanction

Actor: role.operator

Trigger: An account suspension or permanent sanction is formally applied.

Outcome: Service access and all bots stop without deleting preserved evidence.

Failure: Unauthorized actions are rejected and audited.
