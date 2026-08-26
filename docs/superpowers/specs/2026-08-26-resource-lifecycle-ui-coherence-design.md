# Resource lifecycle and UI coherence design

## Goal

Make strategies, released bots, and backtests understandable as separate lifecycle stages, remove misleading duplicate rows and accumulated local test noise, and present every primary state in a centered, consistent product surface.

## Product model

- The strategy page is an authoring workspace. It lists owned drafts only.
- A valid draft remains editable and is labelled `출시 가능`; an invalid or never-validated draft is labelled `작성 필요`.
- A release creates an immutable bot. Released bots never masquerade as incomplete strategies and are managed on the bot page.
- Backtests are execution records belonging to bots. Their status, attempt count, period, failure/cancellation reason, and result availability remain visible on the backtest page.
- PRO remains visibly unavailable and is never presented as a working route.

## Strategy list and pagination

- `GET /api/v1/strategies` accepts an optional resource-kind filter. The strategy home requests `draft` so server cursor pages contain only editable strategy resources.
- The UI renders one page at a time. `이전` uses cached pages and `다음` follows the opaque snapshot cursor. It never appends an unbounded list.
- The current page number and whether a next page exists are explicit. Counts are labelled as current-page counts unless the server provides a true total.
- Search and mode/state filters operate on the current server page and are labelled accordingly; resetting a filter is a single action.
- Draft rows are entirely keyboard/click accessible. A released item returned accidentally is labelled by its real kind and routes to bot operations rather than being disabled as an incomplete draft.

## Visual system

- All customer workspaces use a centered `min(1280px, 100%)` content container with responsive gutters.
- Page hierarchy is limited to eyebrow, one title, one support sentence, and one primary action.
- Panels use the same radius, border, surface, header height, spacing scale, and subdued shadow.
- Lime/teal is the only interaction accent. Green, amber, blue, and red are reserved for semantic status.
- Lists use clear resource-kind labels, descriptive metadata, visible row affordances, and consistent destructive controls.
- At narrow widths, controls wrap without horizontal clipping, list metadata collapses before names, and primary actions remain reachable.

## Product interaction audit

The acceptance question is not merely whether a control works. Every control must justify why it exists on that screen, whether it is the most likely next action, and whether its label describes the outcome.

- Strategy rows have one primary action: open the draft. The whole row owns it; a duplicate chevron button does not. Copy and delete are secondary and destructive actions behind one labelled overflow menu.
- Strategy mode filters are absent while Basic is the only shipped editor. A disabled Pro choice remains in the creation dialog only to communicate roadmap status without presenting a dead browsing filter.
- The header shows one draft count plus useful validation breakdown, not the same current-page count twice.
- Mobile uses five fixed bottom destinations. Primary navigation never depends on discovering or dragging a clipped horizontal scrollbar.
- Bot rows omit unsourced capital, return, operation type, and strategy counts. They show the known bot name, lifecycle timestamp, and lifecycle state instead of repeated em dashes.
- Backtest runs are identified by bot name. Opaque IDs remain execution metadata, never the primary label. Pagination is hidden when there is only one page.
- A dashboard with bots but no published performance offers `백테스트 결과 보기`; it does not end at “check later.”
- Competition copy describes the user task, not implementation (`LIVE API`). Empty search and truly empty lobby states have different explanations.
- Operator routes never carry customer navigation, notifications, account actions, or customer authentication buttons. The top bar states the dedicated operator boundary.
- Email notification settings remain visible for future UI work, but while no delivery channel is connected they are disabled and labelled `준비 중`; the product never claims that security email will be sent.

## State system

Every remote collection must distinguish:

1. Loading: stable skeleton/status region without fake data.
2. First-use empty: explains what the resource is and gives exactly one next action.
3. Filtered empty: explains that filters caused the result and offers reset.
4. Stale data plus refresh error: preserves last confirmed rows and explains that they may be outdated.
5. Unauthenticated: routes to sign-in without describing it as a server failure.
6. Forbidden: explains access, without retry loops.
7. Unavailable/retryable error: one retry action and no fabricated content.
8. Terminal execution status: completed, failed, and cancelled remain visually distinct.

## Local demonstration data

The developer account keeps only a compact, explainable set:

- `작성 중 · 첫 전략 연습`: incomplete draft with no release.
- `출시 준비 · MSFT 추세 반전`: valid draft with no bot.
- `운영 예시 · AAPL RSI·거래량`: valid source draft, one running bot, and its most recent completed maximum-range backtest.
- `취소 예시 · SPY·QQQ 순환`: one bot and one cancelled backtest only when needed to inspect cancellation presentation.

Timestamp names, duplicate bots, repeated completed runs, and obsolete cancellation runs are removed. Cleanup runs inside one verified database transaction after exact retained IDs are recorded. Market data, catalogs, policies, accounts, and audit/auth data are not touched.

## Verification

- Backend controller/application/persistence tests prove the kind filter and cursor behavior.
- UI tests first fail for released-item misclassification, draft-only requests, non-appending pagination, previous-page navigation, empty/filter/error states, and route selection.
- Existing strategy, bot, backtest, competition, account, and operator test suites remain green.
- The rebuilt Docker stack is verified with the real developer account in the in-app browser at desktop and narrow widths.
- Database queries independently prove only the retained demonstration records remain.
- Secret scanning and git status checks run before commit and push.
