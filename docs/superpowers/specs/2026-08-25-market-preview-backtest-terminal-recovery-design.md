# Market preview and backtest terminal recovery design

## Scope

This change makes strategy preview a read of canonical local market history and makes every backtest execution reach a durable terminal state. It does not introduce synthetic prices, change strategy semantics, or add a new database migration.

## Market preview contract

`GET /api/v1/market-data/instruments/{instrumentId}/bars` remains authenticated and owner-scoped through the existing customer principal. The optional `window=1m|3m` query selects a calendar window whose end is the last available bar for the requested instrument and timeframe. Without `window`, the existing `limit` contract remains available to other consumers.

A window response includes the requested interval, the actual returned interval, and a coverage state:

- `COMPLETE`: stored history reaches the requested start;
- `PARTIAL`: bars exist, but stored history begins after the requested start;
- `EMPTY`: no stored bar exists for that instrument/timeframe.

The server returns no generated fallback. Redis is only a read model of checksummed Parquet objects copied from the local object store. The UI displays the actual interval and a specific empty/partial/error explanation.

The preview's selected symbol is controlled by the editor. Changing symbol resolves that symbol's canonical instrument ID and performs a new request. Changing timeframe or 1/3-month window also performs a new request. Stale requests are aborted.

## Backtest terminal boundary

The worker parses an addressable job before applying its receive limit. A retryable outcome on the final allowed delivery is converted to `MAX_ATTEMPTS_EXHAUSTED`, the fenced attempt is closed, and the run is atomically marked `FAILED` before the message is copied to the DLQ. Permanent handler failures use the same terminal store operation, so a failed result publication cannot leave the run non-terminal. Duplicate delivery of an already terminal attempt remains idempotent.

The persistence-backed execution store owns this terminal transaction because it already owns the fenced attempt claim. In-memory test stores retain the same protocol and observable terminal record.

## Stale recovery

A periodic recovery pass runs inside the worker process and serializes candidates with database row locks:

- a RUNNING attempt with an unexpired lease is live, regardless of wall-clock duration;
- heartbeat extends the lease, so a healthy long job is never recovered;
- an expired RUNNING attempt below the retry limit is closed as `LEASE_EXPIRED` and its run returns to `QUEUED` for the existing SQS redelivery;
- an expired attempt at the retry limit becomes `FAILED`;
- a QUEUED run at the retry limit becomes `FAILED` immediately;
- a QUEUED run with no live attempt and no dispatch/retry progress for the configured timeout becomes `FAILED` with `QUEUE_DISPATCH_TIMEOUT`;
- an expired RUNNING cancellation request becomes `CANCELLED` rather than failed.

All transitions are conditional and idempotent. Recovery never republishes a job, preventing duplicate work after restart.

## UI and operations

The existing cancel endpoint and cooperative heartbeat cancellation remain the user path. The backtest detail shows run failure/cancellation state, total attempt count, and each attempt's failure reason. A one-shot recovery command is used after deployment to clean pre-existing stuck rows using the same rules as the periodic pass.

## Verification

Tests cover authenticated window contracts, exact latest-date calendar ranges, no-data/partial states, Parquet-to-Redis/API value equality, browser symbol/timeframe/window changes, final retry and DLQ terminal updates, stale lease recovery, live lease protection, cancellation, idempotent duplicate delivery, and the full local Docker flow. Secret scanning precedes commit and push.
