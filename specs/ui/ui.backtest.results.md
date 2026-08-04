---
schema_version: 1
id: ui.backtest.results
kind: ui
status: approved
revision: 2
refs:
    - role.strategy-author
    - journey.backtest.review
---

# ui.backtest.results

Required states: loading, empty, queued, running, cancelling, cancelled, complete, failed, unavailable, forbidden. Automatic, user-selected period, and eligible competition results are visibly distinguished; the UI never fabricates a successful result while an API, manifest, or permission check is unavailable.
