# INT03 partial evidence — customer journey reaches two released Basic bots

Date: 2026-08-09 KST

Environment: AWS Development (`ap-northeast-2`, account `418553863687`)

Initial journey revision: `6ec540eb32aff6150a187a0a58c8515f3717b380`

Latest deployed revision verified: `b31b9b8d16078c915d130f730bfc210c7618e755`

This is partial evidence only. It deliberately does not create `docs/evidence/INT03.md`, because an
automatic backtest has not completed and the personal bot run, order/fill, and stop sequence has not
passed.

## Baseline and deployment verification

`scripts/verify-deployed-development.ps1` completed successfully against the Development Terraform
state. The HTTPS frontend, backend and backtest health routes, CloudFront/S3 origin, SSM parameters,
Core runtime, RDS, Valkey, queues, and CloudWatch checks passed.

Backend PR #242 was included through root PR #440 and the Development release workflow completed all
jobs successfully. The service host then reported backend image digest
`sha256:5a8e8c5dc4d0d6dae9fea2dfc5073a63fbfdf628bb9600a9eddb4f35fc09c774`, started at
`2026-08-08T17:20:37Z`. The release permission failure recorded by the previous revision of this file
is therefore fixed and deployed.

Backend #243, data-pipeline #57/#58, and root pointer/wiring PRs #444/#445 were subsequently merged.
Development release run
[31273180619](https://github.com/Idea2Strategy/Idea2Strategy/actions/runs/31273180619) completed
successfully for root `b31b9b8d16078c915d130f730bfc210c7618e755`. A fresh
`scripts/verify-deployed-development.ps1` run passed the frontend, backend, backtest, SSM, Core,
RDS, Valkey, queue, and CloudWatch checks against that deployment.

The published launch inputs used by the journey were:

- Basic catalog ID: `0f4a0000-0000-4000-8000-000000000001`
- Catalog version: `basic-elements:2026-08-08`
- Execution policy: `development-official-backtest-2026-q3-v1`
- Adjusted 30-minute dataset: `7f7113c9-3b02-4098-97ec-0baa07e2b3b0`
  (`2024-01-01` through `2024-02-01`)

## Customer journey observations

The journey used one newly created and email-verified Development customer. No email, password,
verification token, customer JWT, or AWS credential is recorded here.

| Step | Observation |
| --- | --- |
| Signup | `POST /api/v1/auth/signup` returned 202. |
| Email verification | `POST /api/v1/auth/verify-email` returned 204. |
| Login | `POST /api/v1/auth/login` returned 200. Short-lived access tokens were refreshed only through the public login API. |
| Scheduled strategy | Strategy `8967d7cb-cebe-4b23-99b3-5cd2ec38a407`, edit sequence 2, validation `89124fa0-85f7-4702-b96b-07cf02fb3e0c` = `VALID`. |
| Scheduled release | Release returned 201 and created bot `b0f67f60-02ac-3a4f-a901-3012eb3f2b4b` in BASIC lane. |
| RSI strategy | Strategy `37bf210f-8626-45eb-a173-08371ab98a05`, edit sequence 1, validation `512b521a-d6c6-4ebe-89d6-c392285a7e7c` = `VALID`. The AAPL flow uses `RSI_14/30m` and an equal-allocation market order action. |
| RSI release | Release returned 201 and created bot `456b1a35-ca12-397d-b4d4-5e181d73174b` in BASIC lane with one immutable feature materialization pin. |
| Bot state | Both released bots appeared in `GET /api/v1/bots/operations` as `running`, with no execution block and event sequence 0. |

## Automatic backtest observations

The scale-to-zero path worked: the BASIC request queue alarm changed
`idea2strategy-dev-backtest` from desired capacity 0 to 1. Instance `i-07a6870a8c4c199dc`
became healthy, completed cloud-init, pulled the immutable worker image, and ran
`idea2strategy-backtest-worker-1` without a restart.

The worker then rejected two distinct contract defects before any attempt began:

1. The scheduled-only release produced run `0ba6f135-07b7-35e0-9069-ebf22f9eafe1`, but its request
   carried an empty `featureMaterializations` array. The shared official request schema requires at
   least one item, so the worker moved it to the BASIC request DLQ with
   `CONTRACT_VIOLATION`. This proves that a valid/releasable schedule-only Basic strategy and the
   official backtest request contract currently disagree.
2. The RSI release produced run `232c4b30-e95e-33ea-9ea9-ff8ccc0a0b4f` with one feature pin. It
   passed body validation but was moved to the request DLQ with
   `TRANSPORT_ENVELOPE_MISMATCH`. Backend stores the `strategy-bot` outbox `aggregate_id` as
   `request.runId()`, while the official message identity and the backtest transport validator use
   `request.botId()`.

The second defect was tracked as
[Idea2Strategy-backend #243](https://github.com/Idea2Strategy/Idea2Strategy-backend/issues/243),
and its fix is now deployed. Poison messages were inspected without deletion and were not redriven.

After that deployment, a fresh RSI release produced run
`4071b877-1aaf-36b7-b473-df559881a45c`. Its corrected request reached the BASIC request queue and
was received by the healthy worker, but the run remained `QUEUED` with `attempt_count=0`. The worker
log showed that request claiming failed while reading `operations.outbox_messages`:

```text
psycopg.errors.InsufficientPrivilege: permission denied for schema operations
backtest request intake poll failed; retrying
```

The deployed `idea2strategy_backtest` role has no `operations` schema usage or table privileges,
while `PostgresRequestReceiptStore` reads `operations.outbox_messages` and writes
`operations.outbox_consumer_receipts`. This new runtime ACL defect is tracked as
[Idea2Strategy-backend #245](https://github.com/Idea2Strategy/Idea2Strategy-backend/issues/245),
assigned to `kcrmin`.

## Personal bot execution observations

The RSI bot preflight returned `ready=false` with:

```text
DATA_NOT_READY: instrument aa268aa6-9401-49d0-a2d4-a2a490df7d84,
feature 4b1c6801-0259-5176-a857-0e5ea923d898
```

A read-only Development query through the deployed backtest role observed five active feeds at the
feature's `30m` resolution, zero qualifying `market_data.stream_watermarks` rows, and no latest
ingestion timestamp. `POST /api/v1/bots/456b1a35-ca12-397d-b4d4-5e181d73174b/run` consequently
returned 409. Orders, fills, and judgment logs all remained empty.

The missing product-path watermarks were tracked as
[Idea2Strategy-data-pipeline #57](https://github.com/Idea2Strategy/Idea2Strategy-data-pipeline/issues/57),
and the code and Development schedule are now deployed. However, a post-deployment read-only query
still observed five active `30m` feeds and zero qualifying watermark rows. The EventBridge schedule
runs at `23:30 UTC` on weekdays; the deployment completed on Saturday UTC, so the first ordinary
scheduled opportunity is Monday `23:30 UTC` (Tuesday `08:30 KST`). Until that run publishes a
watermark, personal bot preflight is expected to remain `DATA_NOT_READY`. No schedule was invoked
manually and no watermark or other product state was inserted.

## Resume criteria

Resume INT03 after the remaining runtime prerequisite and scheduled data publication are complete:

1. backend #245 grants the backtest runtime only the operations-outbox privileges required by request
   intake, refreshes the root Flyway bundle, and deploys it;
2. the official weekday EventBridge run creates and advances the active feed watermark;
3. create a fresh RSI release rather than redriving any previous request;
4. verify the automatic backtest reaches `COMPLETED` and record its result hash and order/fill evidence;
5. verify personal bot preflight, run, judgment, virtual order/fill, and stop in order;
6. only then replace this partial record with `docs/evidence/INT03.md`.
