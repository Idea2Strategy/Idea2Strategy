# INT03 partial evidence — customer journey reaches two released Basic bots

Date: 2026-08-09 KST

Environment: AWS Development (`ap-northeast-2`, account `418553863687`)

Initial journey revision: `6ec540eb32aff6150a187a0a58c8515f3717b380`

Latest fully verified release before the current investigation: `b31b9b8d16078c915d130f730bfc210c7618e755`

Current deployed root under investigation: `70cdd868f9daff5644ddd5646bee7ddc0faf5a67`

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

Backend #245 was then fixed by backend PR #246 and root PR #446. Development release run
[31277100544](https://github.com/Idea2Strategy/Idea2Strategy/actions/runs/31277100544) applied the
refreshed Flyway bundle. A pre-existing backtest worker had started before the runtime database
secret was rotated and failed password authentication with its embedded URL. The tracked
`idea2strategy-runtime.service` restart path reloaded Secrets Manager state, recreated the worker
container, and a connection-only `select 1` check succeeded without exposing the URL or secret.

A fresh RSI release made after that refresh produced strategy
`0450e1c4-c068-45a7-85a2-90add8f74cc3`, validation
`3b8c6e55-8eac-4f9e-a2d9-266e65859919`, bot
`9c155d0f-2602-3681-973a-562ca806dd05`, and run
`030f0465-307c-35eb-8ea3-c0756956e1fe`. Request intake passed and five durable attempts were
created, proving the operations-outbox ACL blocker was removed. All five attempts immediately
ended `FAILED` with `terminal_reason_code=RETRY_RELEASED`; the run remained `QUEUED` and the job
reached the BASIC execution DLQ. This is a distinct post-intake execution failure, not a recurrence
of #245.

At the user's direction, all further automatic-backtest mutations are paused while `kcrmin`
investigates the exact failure and assigns the fix owner. No further release/run, worker or ASG
operation, DLQ receive/delete/redrive, or automatic-backtest deployment is permitted during that
pause. The existing DLQ message was not deleted or redriven.

### One authorized diagnostic reproduction after retry-reason deployment

Root PR #452 deployed backtest-engine `d0d6392d88a841cc8ff1d02bc438c5a21fe817f4` in Development
release run [31281669723](https://github.com/Idea2Strategy/Idea2Strategy/actions/runs/31281669723).
That revision preserves a retry handler's reason in `backtest.run_attempts.failure_code` and enables
the worker's INFO/error logging. `scripts/verify-deployed-development.ps1` passed against AWS account
`418553863687` before the reproduction.

After `kcrmin` requested exactly one `hjcud` reproduction, one new customer journey used the public
signup, email verification, login, strategy save, validation, and release APIs. Credentials and the
verification token were generated ephemerally and were not written to this repository or command
output. The accepted release used the already-published launch inputs named above and produced:

| Artifact | ID / observation |
| --- | --- |
| Account | `08664ea6-012a-48d6-b2b1-00495a405cdf` |
| Strategy | `6a25d5fb-6426-40e2-b679-2223be5558b9` |
| Validation | `a1cc1e79-fb85-4d6d-908d-0587acddb88f` = `VALID` |
| Bot | `8918215c-d8bf-35c7-ba91-be8ba4feadf6` |
| Official run | `cfca9ae2-58a4-34e4-82f3-d0f2316761cc` |
| Attempts | 1 through 5 all `FAILED`, each with `failure_code=HANDLER_ERROR:ProgrammingError` |

The observability change worked: the five durable attempt rows now name the handler exception, and
the `/idea2strategy/dev/backtest` CloudWatch log names the exact failing dependency. Every attempt
failed while `PostgresCompiledPlanRepository.by_checksum` executed:

```sql
SELECT plan_document
  FROM bot.launch_contract_plans
 WHERE plan_checksum = :checksum
```

PostgreSQL rejected it with `InsufficientPrivilege: permission denied for schema bot`. The
Development `idea2strategy_backtest` runtime therefore needs the narrow read grant required for the
published immutable launch plan; the failure occurs before simulation begins. This is a new runtime
ACL gap after the already-fixed `operations` schema intake grant, not a recurrence of that defect.

No second release or run was created. No worker restart, ASG change, DLQ receive/delete/redrive,
additional release, or permanent deployment was performed after this observation. The diagnostic
run was left in place as evidence.

### One authorized post-grant reproduction after Development release #61

Root `70cdd868f9daff5644ddd5646bee7ddc0faf5a67` completed every job in Development release run
[31285790795](https://github.com/Idea2Strategy/Idea2Strategy/actions/runs/31285790795). This deployed
the narrow `bot.launch_contract_plans` read grant and the Backtest worker rollout. A fresh
`scripts/verify-deployed-development.ps1 -ExpectedAwsAccountId 418553863687` run then passed the
public frontend, backend, backtest, WebSocket, CloudFront/S3, SSM, Core runtime, RDS, Valkey, queue,
and CloudWatch checks.

After the release completed, one new customer journey used only the public signup, email
verification, login, strategy save, validation, and release APIs. Preparatory request-shaping
created ephemeral verified accounts and invalid drafts while matching the deployed Basic catalog,
but it did not create a release, bot, or backtest run. The final accepted payload used
`BASIC_SCHEDULE -> BASIC_RSI_CROSS -> BASIC_EQUAL_ALLOCATION_ORDER`, and exactly one accepted
strategy release produced:

| Artifact | ID / observation |
| --- | --- |
| Account | `cef3b0ef-5da1-4c80-9339-26633dc576a9` |
| Strategy | `671dfc39-3e33-4c97-a953-b0d574fff8c9` |
| Validation | `b0470f6d-2b3a-40f3-ae0b-22d91a35485d` = `VALID` |
| Bot | `eb8a35aa-7fbe-3eb7-8198-0d8748c3bd37` |
| Official run | `c0df2755-01eb-3660-b57e-be20ab73001a` |
| Worker / message | `i-07a6870a8c4c199dc` / `d6c7eed3-bc69-40a2-b753-b2c0a7f52253` |
| First failure | `2026-08-09 10:17:01 KST` |
| Attempts | 1 through 5 reported `failure_code=HANDLER_ERROR:ContractValidationError` |

The run appeared as `QUEUED` immediately, exhausted all five attempts, and remained `QUEUED` after
a bounded 30-minute public-API observation. A read-only, time-ordered inspection of
`/idea2strategy/dev/backtest` found two causally ordered failures on every delivery of the same
message.

First, execution preparation could not resolve the immutable compiled plan named by the job:

```text
backtest_engine.wiring.JobNotSatisfiable:
compiled plan sha256:f98de8f7bde5c44eaadf82acad874d9ba7c10eae0d56030687fa706f49a2e850
is not resolvable
```

`OrchestratorJobHandler.bind` raises this before simulation when the deployed
`PostgresCompiledPlanSource` returns no document for the exact checksum. The handler correctly tried
to publish this non-retryable `REQUIRED_INPUT_UNAVAILABLE` result as terminal `FAILED`.

Second, building that failure event raised another exception because the result-event correlation
ID was not a UUID:

```text
backtest_engine.contracts.ContractValidationError:
backtest_result_event.metadata.correlationId: 'i-07a6870a8c4c199dc'
does not match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
```

The root Development user-data template obtains the EC2 instance ID and assigns it to both
`BACKTEST_WORKER_ID` and `BACKTEST_WORKER_CORRELATION_ID`. The Backtest worker uses the latter as the
result event's required correlation ID, whose contract accepts a UUID. That secondary validation
exception escaped the handler, so the outer worker recorded `HANDLER_ERROR:ContractValidationError`,
released the same message for retry, and repeated the chain through attempt 5. It also prevented the
original `JobNotSatisfiable` result from becoming terminal, which explains why the run remained
`QUEUED`. This was not a long-running simulation and is not a recurrence of either database grant
failure.

The personal bot run was not called because the automatic backtest did not reach `COMPLETED`. No
additional release or run, worker restart, ASG operation, DLQ receive/delete/redrive, or deployment
was performed. The failed run remains in place as evidence.

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
and the code and Development schedule are now deployed. `pjy008008` invoked the exact ECS Fargate
target and official `--publish-manifest-watermarks` command once, rather than inserting product
state. The task exited 0 and reported 16 active feeds with 13 advanced. A subsequent read-only query
observed 13 watermark rows and qualifying watermarks for four of five active `30m` feeds, including
the `RSI_14/30m` feature feed.

The inherited acceptance check then called
`GET /api/v1/bots/456b1a35-ca12-397d-b4d4-5e181d73174b/preflight` through the public customer API.
It returned HTTP 200 with `ready=true` and `issues=[]`. This proves the original `DATA_NOT_READY`
condition was removed without a DB insert, fabricated watermark, or temporary grant. The result was
recorded on data-pipeline #57 and that issue was closed again.

## Resume criteria

Development release #61 satisfied the previous `bot.launch_contract_plans` grant and worker-rollout
criteria. Two separate defects now block the same run: the exact compiled-plan checksum is not
resolvable through the deployed immutable plan source, and the failure event cannot be published
because its correlation ID is not a UUID. Resume INT03 only after `kcrmin` coordinates both owning
boundaries, deploys both fixes, and explicitly lifts the automatic-backtest pause:

1. make plan `sha256:f98de8f7bde5c44eaadf82acad874d9ba7c10eae0d56030687fa706f49a2e850`
   resolvable through the deployed `PostgresCompiledPlanSource` and verify the publisher/consumer handoff;
2. supply a UUID-conformant stable value for `BACKTEST_WORKER_CORRELATION_ID` so terminal failures can publish;
3. deploy both fixes without redriving prior DLQ evidence;
4. create one fresh RSI release through the public customer flow;
5. verify the automatic backtest reaches `COMPLETED` and record its result hash and order/fill evidence;
6. verify personal bot run, judgment, virtual order/fill, and stop in order (preflight already passes);
7. only then replace this partial record with `docs/evidence/INT03.md`.
