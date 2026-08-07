---
schema_version: 1
id: decision.accounting.precision-v1
kind: decision
status: approved
revision: 1
refs:
    - policy.market.us-only
    - quality.reproducibility
---

# decision.accounting.precision-v1

Choice: Money is stored as a decimal with four fractional digits and displayed rounded half-up to two. Quantities are whole shares. Order sizing truncates toward zero. Simulated slippage is a fixed 5 basis points. Realized profit and loss is computed first-in-first-out over canonical long lots. Official performance reports total return, maximum drawdown, win rate, and trade count.

Rationale: Four fractional digits absorb per-share fee arithmetic without binary floating-point drift while two are what a statement shows. Whole shares keep fractional-share settlement out of v1, and the supported instruments are all whole-share tradable. Truncation is a safety direction rather than a preference: a budget cap must never be exceeded by rounding. The remaining values restate constraints the database already enforces and the lot model the trading runtime already maintains, so recording them changes no behavior.
