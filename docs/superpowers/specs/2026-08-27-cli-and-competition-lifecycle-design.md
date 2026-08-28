# CLI and Competition Lifecycle Design

**Product authority:** `user:kcrmin`

**Recorded instruction:** “애매하게 덜 하지 말고 비즈니스 로직에 맞게 해야 할거 다 해줘 … 그만 물어봐 … 대회 방 생성 안되는 문제도 해결 … 달력에서 눌러서 3개 날짜를 직관적으로 고를 수 있게.”

## Goal

Make the CLI a complete JSON automation boundary for the supported customer workflows, repair local competition creation, and replace six-field schedule entry with one accessible three-milestone calendar. Runtime objects remain immutable after launch and all destructive actions preserve evidence.

## Domain boundaries

- Strategy supports create, list/read, reviewed Basic edits, copy, validate, release, and soft delete. The reviewed edit vocabulary gains `SET_GROUP_INSTRUMENTS`; it replaces one container's complete instrument set after validating every identifier against the published catalog.
- Bot supports list/read and permanent stop only. The CLI exposes no run, restart, rename, budget, continuation, strategy, instrument, or timeframe mutation.
- Backtest supports create, list/read, cancellation, and owner soft delete. Creation remains Backend-owned; reads and deletion remain Backtest API-owned. A delete request cancels queued/running work and records deletion intent; terminal evidence is retained and hidden from customer queries after `deleted_at` is set.
- Competition (the product's live paper-trading room) supports create, list/read, and delete-as-cancellation. Room rules are immutable through the CLI. Cancellation appends the existing room lifecycle event; it does not erase competition evidence.
- CLI never performs direct SQL, arbitrary code execution, external market-data fetching, or direct orders.

## Stable CLI surface

```text
strategy list|get|create|copy|edit preview|edit apply|validate|release|delete
bot list|get|stop
backtest create|list|get|cancel|delete
competition create|list|get|delete
```

All commands return the existing single JSON envelope. IDs are path-encoded, list limits are bounded, and stop/delete commands require `--yes`. Mutations follow their server-owned replay contract: backtest creation requires the caller's idempotency key, while commands whose backend derives a stable domain key or treats a repeated terminal request as a no-op keep that canonical behavior. API problem details remain visible as stable CLI errors without leaking credentials; the CLI does not pretend an unsupported header makes a non-idempotent endpoint safe.

Backend and Backtest API may use separate origins locally. `--base-url`/`I2S_BASE_URL` selects Backend and `--backtest-base-url`/`I2S_BACKTEST_BASE_URL` selects Backtest API; the latter defaults to the Backend origin for deployed path routing.

## Backtest deletion lifecycle

- Add nullable `deletion_requested_at` and `deleted_at` to `backtest.runs` in a new immutable Flyway migration and canonical DBML.
- Terminal runs are soft-deleted immediately.
- QUEUED deletion atomically cancels and soft-deletes.
- RUNNING deletion records cancellation plus deletion intent. The terminal cancellation transition finalizes `deleted_at`.
- Customer list/get/result endpoints exclude `deleted_at` rows. Worker/internal result ingestion continues to resolve a deletion-pending run until it reaches a terminal state.
- Repeated delete is idempotent. A foreign owner receives the existing ownership denial semantics.

## Competition creation root cause and local parity

The running local database has zero rows in `competition.scoring_template_versions`, while fee and buying-power policies exist. The room input catalog therefore returns no selectable template and the UI correctly fails closed, but currently explains it poorly. AWS development bootstrap already loads the reviewed scoring seed; local `dev.ps1` does not.

Local startup will apply the same checksum-bound, idempotent scoring seed used by the AWS development bootstrap. A fresh or existing local database will then expose the four reviewed templates. Startup fails if the seed is missing or rejected.

## Three-milestone schedule calendar

The creation dialog presents one calendar and three milestones: recruitment opens, evaluation starts, evaluation ends. Clicking a milestone selects what the next calendar click edits; after a date is chosen focus advances to the next incomplete milestone. The calendar visually distinguishes all three dates and the interval between evaluation start/end.

Each milestone has an explicit time control with sensible local defaults rounded into the future. The timezone selector remains visible. The UI derives participation open, participation close, and finalization deadline according to existing server rules. It validates strict chronological order before submission and announces the exact invalid milestone instead of a generic failure.

The component uses semantic buttons, keyboard focus, localized month navigation, visible selected states, and mobile-safe layout. No new calendar dependency is introduced.

## Failure behavior

- Missing scoring templates identify unavailable scoring policy and offer retry; they are not described as a login/input problem.
- API errors distinguish authentication, authorization, conflict, invalid schedule/policy, and temporary service failure.
- Stop/delete reject missing confirmation before network activity.
- A bot stop never mutates bot configuration.
- A competition delete never becomes physical deletion.

## Verification

- Unit and API tests for every new CLI route, argument, confirmation, output, and forbidden mutation.
- Backend application tests for `SET_GROUP_INSTRUMENTS` and migration/DBML tests for backtest deletion fields.
- Backtest lifecycle, persistence, API ownership, idempotency, active cancellation, terminal deletion, and hidden-query tests.
- Local seed validation plus an integration check that the catalog contains selectable templates after startup.
- React behavior tests for the single-calendar three-click flow, time controls, timezone conversion, errors, keyboard names, and exact request payload.
- CLI-only edit of the target strategy's last partition to include META, followed by API/document readback.
- Browser creation of a real local competition and readback from the owned-room API.
