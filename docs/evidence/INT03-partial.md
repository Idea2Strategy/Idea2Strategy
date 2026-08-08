# INT03 partial evidence — customer journey reaches validated Basic strategy

Date: 2026-08-09 KST

Environment: AWS Development (`ap-northeast-2`, account `418553863687`)

Root revision: `429cdd000c1faf5aeb48662e45a621908e2ac981`

This is partial evidence only. It deliberately does not create `docs/evidence/INT03.md`, because the
release, automatic backtest, personal bot run, order/fill, and stop stages have not passed.

## Baseline verification

`scripts/verify-deployed-development.ps1` completed successfully against the Development Terraform
state. The HTTPS frontend, backend and backtest health routes, CloudFront/S3 origin, SSM parameters,
Core runtime, RDS, Valkey, queues, and CloudWatch checks all passed. The Core instance observed by
the verifier was `i-03bb3f4a492227874`.

The published launch inputs were present:

- Basic catalog ID: `0f4a0000-0000-4000-8000-000000000001`
- Catalog version: `basic-elements:2026-08-08`
- Supported catalog instruments: 625
- Selectable execution policy: `development-official-backtest-2026-q3-v1`
- Selectable 30-minute adjusted dataset used for the release attempt:
  `7f7113c9-3b02-4098-97ec-0baa07e2b3b0` (`2024-01-01` through `2024-02-01`)

## Journey observations

The journey used a newly created test account under a verified Development SES identity. No email,
password, verification token, customer JWT, or AWS credential is recorded here.

| Step | Observation |
| --- | --- |
| Signup | `POST /api/v1/auth/signup` returned 202. |
| Email verification | `POST /api/v1/auth/verify-email` returned 204. |
| Login | `POST /api/v1/auth/login` returned 200 with a Bearer access token. |
| Basic strategy creation | Created strategy `8967d7cb-cebe-4b23-99b3-5cd2ec38a407`. |
| Document save | Saved a UI-compatible scheduled BUY flow for AAPL at edit sequence 2. |
| Validation | Validation run `89124fa0-85f7-4702-b96b-07cf02fb3e0c` returned `VALID`; semantic hash `b185c26fabe0ec08fa809e932f4a334c21ae214ae987f427cafc92cda9892e62`. |
| Release | `POST /api/v1/strategies/8967d7cb-cebe-4b23-99b3-5cd2ec38a407/releases` returned 500 at `2026-08-08T16:01:35Z`. |

## Blocking defect

The Development backend log identifies a runtime-role permission mismatch, not invalid user input:

```text
org.postgresql.util.PSQLException: ERROR: permission denied for table run_input_pins
at com.idea2strategy.backend.persistence.backtest.BacktestRunInputPinWriter.pin(...:22)
```

`BacktestRunInputPinWriter.pin` executes this query while producing the official backtest input
boundary:

```sql
select ...
from backtest.run_input_pins p
join backtest.input_bundles b on b.id = p.input_bundle_id
where p.run_id = ?
for update of p, b
```

The generated repeatable Flyway grant gives `idea2strategy_backend` only `SELECT, INSERT` on
`backtest.run_input_pins` and `backtest.input_bundles`. PostgreSQL requires `UPDATE` privilege on
tables named by `FOR UPDATE`, so the release transaction fails before it can publish the automatic
backtest request. The backend access-policy integration test explicitly asserts that this role does
not have `UPDATE` on `run_input_pins`, confirming the code and permission contract disagree.

No temporary grant was applied to Development. Passing INT03 through untracked privilege drift would
not be valid release evidence.

## Required handoff and resume point

This defect crosses into the `kcrmin`-owned backend/central-migration boundary. The preferred repair
is to retain the existing per-run advisory transaction lock and remove the unnecessary row-lock
clause from the immutable input-pin existence read, with a runtime-role integration test that
executes the producer path. If row locking is intentionally required instead, the database access
policy, generated repeatable grant, central Flyway bundle, and least-privilege tests must be changed
together.

After that fix is merged, deployed, and the repeatable migration has run, resume with the already
VALID validation run above and repeat the release request. Then verify, in order:

1. the automatically queued Basic backtest reaches a terminal successful result;
2. the personal bot passes preflight and runs;
3. an order and fill are observed for the journey account;
4. the bot stops and remains stopped;
5. only then write `docs/evidence/INT03.md`.
