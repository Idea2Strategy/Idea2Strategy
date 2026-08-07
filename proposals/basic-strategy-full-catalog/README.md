# Basic strategy full catalog proposal

Status: **PROPOSED / NOT GOVERNANCE-APPROVED**

This document records the behavior implemented on
`feature/basic-strategy-full-catalog`. It is deliberately isolated from `specs/` and `contracts/`
because the fresh governance observation did not identify the required product authority.

## Editor and persistence state machine

- Every editor change produces a new client revision and is preview-validated after a short debounce.
- A preview validates the submitted semantic document and is never persisted as the validation of a
  saved revision. Stale or aborted preview responses cannot replace a newer result.
- Save is available for both valid and invalid documents.
- A saved revision is `READY` only when a persisted `VALID` validation run has the exact same edit
  sequence, semantic hash, and element-catalog id. Otherwise it is `INCOMPLETE`.
- Personal-bot launch is available only while the current editor signature still equals that exact
  saved `READY` revision. Any edit immediately disables launch until the next successful save and
  validation.

## Published Basic operations

| Editor block | Runtime operation | Decision |
|---|---|---|
| 가격 비교 | `PRICE_COMPARE` | completed-bar price compared with previous close, session open, average entry, SMA, or prior range |
| 가격 변화율 | `PRICE_CHANGE_PERCENT` | signed percentage change from the selected base reaches the threshold |
| 거래량 | `VOLUME_COMPARE` | completed-bar volume compared with previous or rolling-average volume and multiplier |
| 연속 상승·하락 | `STREAK` | consecutive completed close-to-close moves reach the requested count |
| 평균선 교차 | `SMA_CROSS` | short SMA crosses the long SMA in the requested direction |
| RSI 반등 | `RSI_CROSS` | 14-period RSI crosses the threshold, rather than merely remaining beyond it |
| MACD 전환 | `MACD_CROSS` | MACD histogram crosses zero in the requested direction |
| 가격 띠 반전 | `BOLLINGER_REVERSAL` | price returns through the selected Bollinger boundary after the previous close was outside it |
| 현재 수익률 | `POSITION_RETURN` | current return from durable average entry reaches the profit/loss threshold |
| 보유 기간 | `HOLDING_PERIOD` | session close, completed bars at the selected resolution, or trading-day count reaches the limit |
| 최고 수익률 | `PEAK_RETURN` | observed peak return since the current position was loaded reaches the comparison |
| 고점 대비 하락 | `DRAWDOWN_FROM_PEAK` | decline from the observed position peak reaches the comparison |
| 정기 매수 패키지 | `SCHEDULE` | one trigger on the selected trading-day cycle |
| 주문 액션 | `EMIT_ORDER_CANDIDATE` | terminal candidate only; trading service still applies budget, position, and risk contracts |

All nine editor resolutions are built from normalized one-minute bars. Larger candles do not become
eligible until a complete aggregate closes. Insufficient rolling history yields `INPUT_MISSING`; a
partial candle yields `WAITING_FOR_BAR_CLOSE`. Neither can emit an order.

## Runtime boundary

The released plan carries the direct operation and its frozen parameters. Plans using only direct
operations carry an empty official-feature requirement set and skip the manifest warm-up lookup.
Normalized Redis market events update the rolling state, the Basic executor evaluates each AND
chain, the candidate converger resolves conflicts, and the existing exactly-once candidate processor
writes canonical order intents. Position-dependent sell operations read active canonical long lots.

Peak and completed-bar counters are fail-safe in-memory state keyed by the current durable position:
after a worker restart they restart from the current price and cannot invent an earlier peak or bar.
A future approved canonical contract may persist this derived state if cross-restart peak/history
continuity is required as product meaning.

Calendar cycles use the New York market timezone, observed stream boundaries for first-day cycles,
and the regular NYSE holiday calendar for month-end. An approved exchange-status source would still
be needed to account for extraordinary one-off exchange closures.
