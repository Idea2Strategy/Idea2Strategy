# Dual UI Prototypes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and run two interactive Idea2Strategy UI prototypes that present the same product scope and mock data through a balanced workspace design and a dense terminal design.

**Architecture:** A standalone React/Vite app lives in `prototype/` and never imports from or reads the retired `ui/` submodule. Shared domain data and page components supply equivalent content, while variant-specific shells and CSS tokens create visibly different navigation, density, hierarchy, and chart presentation. A query/path entry selects `/balanced` or `/terminal`; theme and active product page remain interactive in the browser.

**Tech Stack:** React 19.2.8, Vite 8.1.5, Vitest 4.1.10, Testing Library 16.3.2, Lucide React 1.25.0, CSS custom properties, inline SVG charts.

## Global Constraints

- Do not inspect, import, copy, or modify the existing `ui/` submodule.
- Use only neutral mock data and never display strategy, security, allocation, or performance recommendations.
- Both variants expose Strategy, Basic, Pro, Bots, Backtest, Rooms, Notifications, Account, and Admin entry points from the same domain model.
- Basic uses interlocking blocks, buy/sell strategy containers, minimal labels, and hover/focus rule-based natural-language review.
- Pro uses a left-to-right graph and opens a categorized compatible-node picker at the released connection point.
- Support light and dark themes, semantic labels in addition to color, and responsive read-only behavior for narrow screens.
- Keep the balanced and terminal variants visually distinct enough for side-by-side user comparison without changing product meaning.

---

### Task 1: Standalone app contract and smoke tests

**Files:**
- Create: `prototype/package.json`
- Create: `prototype/vite.config.js`
- Create: `prototype/index.html`
- Create: `prototype/src/test/setup.js`
- Create: `prototype/src/App.test.jsx`

**Interfaces:**
- Consumes: UI page inventory and strategy editor direction documents.
- Produces: test contract for `App`, variant switching, navigation, theme, Basic translation, and Pro node picker.

- [ ] Write tests that render each variant and assert the shared product navigation and distinct variant labels.
- [ ] Add tests for page navigation, theme switching, Basic hover/focus translation, and opening the Pro compatible-node picker at a supplied point.
- [ ] Run `pnpm test --run` and verify RED because the application modules do not exist.
- [ ] Add the minimal Vite and Vitest configuration needed for tests to execute.

### Task 2: Shared product model and application state

**Files:**
- Create: `prototype/src/data/mockData.js`
- Create: `prototype/src/lib/navigation.js`
- Create: `prototype/src/App.jsx`
- Create: `prototype/src/main.jsx`

**Interfaces:**
- Produces: `navItems`, neutral strategies, bot positions, backtest series, room rankings, notifications, `App({ initialVariant })`, and URL synchronization.

- [ ] Implement neutral immutable mock records for all representative product areas.
- [ ] Implement URL variant selection and local state for page, theme, editor mode, and selected records.
- [ ] Run the application tests and verify remaining failures are limited to missing views.

### Task 3: Shared page views and editors

**Files:**
- Create: `prototype/src/components/common.jsx`
- Create: `prototype/src/components/charts.jsx`
- Create: `prototype/src/views/StrategyViews.jsx`
- Create: `prototype/src/views/OperationsViews.jsx`
- Create: `prototype/src/views/SupportViews.jsx`

**Interfaces:**
- Consumes: mock records and callbacks from `App`.
- Produces: overview, strategy library, Basic editor, Pro editor, bots, backtest, rooms, notifications, account, and admin views.

- [ ] Build reusable stat, status, table, chart, toolbar, empty-state, and disclosure primitives.
- [ ] Build the strategy library and Basic editor with buy/sell containers and localized translation fragments.
- [ ] Build the Pro graph with typed ports and categorized node picker interaction.
- [ ] Build bot, backtest, room, notification, account, and admin representative pages.
- [ ] Run tests and verify all behavioral assertions pass.

### Task 4: Balanced and terminal visual systems

**Files:**
- Create: `prototype/src/styles/tokens.css`
- Create: `prototype/src/styles/base.css`
- Create: `prototype/src/styles/balanced.css`
- Create: `prototype/src/styles/terminal.css`

**Interfaces:**
- Consumes: semantic class names emitted by shared views.
- Produces: two complete light/dark responsive visual systems.

- [ ] Implement the balanced variant with sidebar navigation, generous surfaces, compact explanations, and a calm blue/neutral financial palette.
- [ ] Implement the terminal variant with a command rail, ticker strip, denser table/grid treatment, monospaced numeric styling, and high-information dark-first hierarchy.
- [ ] Implement responsive behavior that replaces editor manipulation with a clear desktop-required state below the editing breakpoint.
- [ ] Run tests, build, and CSS/search checks for semantic labels and no recommendation language.

### Task 5: Runtime and visual verification

**Files:**
- Modify only if a verified defect is found in `prototype/src/**`.

**Interfaces:**
- Produces: a running local Vite server and two comparison URLs.

- [ ] Run `pnpm test --run` and require zero failures.
- [ ] Run `pnpm build` and require a successful production bundle.
- [ ] Start Vite on an available localhost port with host access limited to the local machine.
- [ ] Open `/balanced` and `/terminal` in browser tabs and inspect desktop and narrow viewport screenshots.
- [ ] Exercise theme, product navigation, Basic translation, and Pro compatible-node picker in both variants.
- [ ] Fix only defects reproduced during verification, re-run tests/build, and leave the server running for the user.
