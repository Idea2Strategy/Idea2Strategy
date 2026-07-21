---
schema_version: 1
id: decision.data.hybrid
kind: decision
status: approved
revision: 2
refs: []
---

# decision.data.hybrid

Choice: Use a relational system of record with logically separated schemas and external object storage for large immutable data. Store typed strategy graphs as structured JSON-family documents in the main RDB, separating executable semantics from editor layout; do not introduce a separate NoSQL source of truth without proven need. Keep live official orders, fills, and double-entry ledgers relational. Keep backtest run metadata, locked inputs, monthly judgment summaries, queryable performance summaries, and integrity manifests relational, while storing high-volume backtest trade, replay-ledger, position, and calculation-series details as immutable objects linked and verified by those manifests.

Rationale: Strategy drafts require atomic document saves with relational ownership and release locking, while backtest details are immutable, high-volume, replay-oriented data. This boundary preserves integrity and auditability without forcing every graph edge or simulated event into an operational RDB row or creating multiple mutable sources of truth.
