---
schema_version: 1
id: decision.data.providers-alpaca-sip
kind: decision
status: approved
revision: 1
refs:
    - decision.data.hybrid
    - policy.market.us-only
    - quality.reproducibility
---

# decision.data.providers-alpaca-sip

Choice: Use the paid Alpaca SIP feed as the single provider for real-time and historical US equity bars and for corporate actions. Adjusted datasets derived from it may be retained and regenerated after the subscription ends. Users are shown derived indicator values and their own results; raw provider market data is never redistributed.

Rationale: One provider for bars and corporate actions removes cross-provider reconciliation from the adjustment path, and retention with regeneration rights is what makes an official backtest reproducible without a licensing expiry. Quote-level and borrow data are deliberately excluded: Basic reads completed bars only, and borrow data is a virtual-broker operational input that is never exposed as a strategy input, sort key, or formula value.
