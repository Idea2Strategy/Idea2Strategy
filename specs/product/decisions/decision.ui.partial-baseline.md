---
schema_version: 1
id: decision.ui.partial-baseline
kind: decision
status: approved
revision: 3
refs: []
---

# decision.ui.partial-baseline

Choice: Retire the old UI reference, freeze the approved Basic and Pro editor interactions and required states, and defer exact visual design to a new editable UI workspace. Implementation is gated on the required-states contract alone; an undecided visual baseline never blocks building or testing a screen.

Rationale: The old exploratory UI no longer represents the intended editor. New representative screens must be judged against product meaning without inheriting its layout or code. Treating the deferred visual decision as a build blocker stalled work that the required states already specify completely enough to implement.
