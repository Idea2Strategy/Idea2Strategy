# Signal product UI and strategy refinement

## Status

User-confirmed visual proposal for the standalone `prototype/` workspace. The user selected design concept C, Signal Studio, as the single product UI. The former terminal/balanced variants and their switch are retired. The retired `ui/` submodule remains outside this change.

## Goal

- Screen: Signal strategy home dashboard and Basic editor.
- User: a strategy author returning to find, review, import, or start a strategy.
- Success: within five seconds the user can identify current drafts, see which item needs work, and start or open the correct editor.

## Format

- Primary review size: desktop at 1280px and wider.
- Navigation: C-style horizontal product menu with the logo, primary pages, search, watchlist, notifications, utilities, theme, and profile.
- Narrow screens: the primary menu becomes a horizontally scrollable second row and strategy content collapses to one column.

## Layout and hierarchy

1. Compact page header: `전략` and one support line, followed by `새 전략` as the only primary action.
2. Strategy totals appear as one compact inline count group; they do not use cards or occupy a separate content band.
3. Main workspace: one full-width searchable/filterable, reorderable strategy list.
4. Opening a strategy remains on its row. Reuse is available only from the creation flow.
5. `빠른 시작` and template shortcuts are removed because their destination and effect are ambiguous.
6. Creation choices appear only after `새 전략` is selected.
7. Blocks never appear on the strategy home. They belong only to the Basic strategy editor.

## Type system

- UI: Space Grotesk/Pretendard-style compact sans serif.
- Numbers and micro labels: existing monospace token.
- One page title, compact section titles, and no repeated explanatory paragraphs.
- Korean labels describe state or action. Short English micro labels may identify the current workspace or live state.

## Color and material

- Default dark charcoal canvas with near-black surfaces and thin structural rules.
- One lime accent for selection, primary actions, and live indicators.
- The retained light-mode control maps the same system to a pale neutral canvas and deep mint accent.
- Green, amber, and red remain semantic status colors only.
- Use low-contrast borders, square corners, and minimal shadows; no glass, decorative gradients, or competing accent colors.

## Exact copy

- Title: `전략`
- Support: `작성 중인 전략을 이어가거나 새 전략을 시작하세요.`
- Primary action: `새 전략`
- Main section: `내 전략`
- Empty search result: `조건에 맞는 전략이 없습니다.`

## Mock interactions

- Search filters by strategy name without changing pages.
- Mode filters support all, Basic, and Pro.
- State filters support all, ready, and needs-input views.
- The three state totals are displayed as a compact, non-card summary beside the strategy section title.
- Opening a strategy routes to its existing Basic or Pro editor.
- Strategy rows do not expose copy actions or block details.
- `새 전략` opens a compact chooser; selecting Basic or Pro opens the matching editor.
- `기존 전략 가져오기` is available inside the chooser and creates a new draft from the selected strategy without changing the source.
- Strategy rows can be dragged to reorder the local example list.

## Constraints

- Change 1: all product routes use one Signal horizontal navigation; no terminal/balanced selector remains.
- Change 2: strategy home hierarchy and mock interactions are replaced.
- Legacy `/terminal` and `/balanced` entry points resolve to the same Signal product shell.
- Do not import, inspect, or copy the retired `ui/` submodule.
- Do not add recommendations, implied profitability, or prefilled material strategy values.
- Do not modify protected `specs/` or `contracts/` as part of this proposal.

## Acceptance evidence

- Component tests cover the horizontal Signal menu, strategy search and filters, absence of home-page blocks and copy actions, and create-time strategy import.
- Basic grouped-translation and Pro compatible-node tests remain green.
- Production build succeeds.
- Browser review confirms the Signal desktop and narrow layouts.
- Strategy, bot, backtest, Competition, account, admin, Basic editor, and Pro editor share the Signal Studio surface and type rules.

## Basic editor natural-language popover

- Hovering or clicking an individual block does not reveal a fragment.
- Clicking the `매수 전략` or `매도 전략` header opens the whole group's natural-language rule; clicking it again closes the explanation.
- Opening the other group replaces the current explanation.
- Group headers are native buttons and support keyboard activation.
- The explanation is an overlaid popover and does not move adjacent blocks.
- The final `BUY` and `SELL` output blocks are fixed, visually attached footers rather than removable steps.
