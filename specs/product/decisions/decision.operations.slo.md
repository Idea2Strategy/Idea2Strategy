---
schema_version: 1
id: decision.operations.slo
kind: decision
status: approved
revision: 1
refs:
    - decision.product.complete-service
    - decision.data.providers-alpaca-sip
    - quality.reproducibility
---

# decision.operations.slo

Choice: The v1.0 operational targets are the following, measured in the development environment that hosts the service. Evaluation latency: from the publication of a `MARKET_EVALUATION_READY` event to the hand-off of its order-candidate batch, p95 at or under 30 seconds, and never past 5 minutes — a decision that arrives after the next 30-minute boundary is a missed bar, not a late one. Concurrency: 100 running bots sustained through a full regular session without breaching the latency target. Official backtest: one instrument over its full available history at any of the four clocks completes within 10 minutes p95 from dequeue, 15 minutes end-to-end from request. Availability: 99.0% monthly for the API and the evaluation path, measured over US regular sessions only. Backup and recovery: RDS point-in-time recovery stays enabled with RPO at or under 1 hour and RTO at or under 4 hours; result and market-data buckets keep versioning on; snapshots retain 7 days. Audit events retain at least 180 days, within the retention categories the schema already enforces. Support: best-effort with next-business-day response; no paging rotation before v1.0.

Rationale: Every number follows from the product's clock and its fills being virtual. The strategy clock is the 30-minute bar, so a 30-second p95 evaluation budget is two orders of magnitude inside the bar and the 5-minute ceiling still leaves the decision meaningfully inside it; sub-second targets would buy nothing a user can observe and would forbid the modest single-host deployment this phase runs on. One hundred concurrent bots is roughly triple the load three operators and early users can realistically create, so it is a target that can fail honestly in INT07 rather than a vanity ceiling. The backtest bound reflects that a ten-year 30m replay is the worst case the catalog admits, and a request that cannot finish inside a coffee break would push users to stop validating strategies before release — the opposite of what the automatic official backtest exists for. Availability is scoped to regular sessions because every trigger in the catalog is a completed session bar; off-session downtime is invisible to the product's own semantics. The recovery numbers restate what RDS point-in-time recovery and S3 versioning already provide when left on, so they cost nothing new and become promises instead of accidents. These are v1.0 floors chosen to be honestly measurable in INT07 now; raising them later is a new revision of this decision, not a breach.
