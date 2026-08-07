---
schema_version: 1
id: question.data.providers-rights
kind: decision
status: unknown
revision: 2
refs:
    - decision.data.providers-alpaca-sip
---

# question.data.providers-rights

Which provider and license satisfy quote-level and borrow data needs, if either is ever required?

Real-time bars, historical bars, corporate actions, storage, and redistribution are settled by `decision.data.providers-alpaca-sip`. Neither remaining feed is read by v1: Basic evaluates completed bars only, and borrow data stays an internal virtual-broker input.
