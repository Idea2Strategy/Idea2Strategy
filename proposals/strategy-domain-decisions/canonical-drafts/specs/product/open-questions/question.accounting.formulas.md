---
schema_version: 1
id: question.accounting.formulas
kind: decision
status: unknown
revision: 2
refs:
    - decision.accounting.precision-v1
---

# question.accounting.formulas

Which margin, borrow-cost, and short-collateral formulas pass market and legal review, once short selling is designed?

Precision, rounding, slippage, realized profit and loss, and the official performance metrics are settled by `decision.accounting.precision-v1`. What remains applies only to short positions, which Basic excludes, so it blocks no part of v1 and should stay open until Pro short support is specified.
