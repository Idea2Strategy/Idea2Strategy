---
schema_version: 1
id: ui.strategy.authoring
kind: ui
status: approved
revision: 2
refs:
    - role.strategy-author
    - journey.strategy.author
---

# ui.strategy.authoring

Required states: draft, validating, invalid, ready, released, locked, backtest-unavailable

Basic uses interlocking Scratch-style blocks inside visibly distinct buy and sell strategy containers. Blocks keep text minimal and expose a rule-based natural-language reading beside the completed group on hover. Basic buy and sell templates include simple indicator-direction structures and known indicator-based structures, with all material values unset.

Only the Basic authoring mode is in scope. Professional graph editing, custom formulas, and pair-trading workflows are not exposed.
