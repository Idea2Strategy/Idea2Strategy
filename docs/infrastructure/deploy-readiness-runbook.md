# Infrastructure deploy-readiness runbook

This runbook covers the last safe checks before an authorized operator creates or changes AWS resources. Running it does not authorize deployment. Keep all AWS credentials, generated plans, state, `backend.hcl`, `terraform.tfvars`, and `.env.docker` outside Git.

## Local and CI checks (no AWS access)

Run from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-deployment-inputs.ps1
```

With Terraform 1.15.x installed:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-terraform-readiness.ps1
```

Without local Terraform, use the pinned container (Docker Desktop must be running):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-terraform-readiness-docker.ps1
```

These checks validate formatting, provider lockfile integrity, Terraform configuration with the S3 backend disabled, the merged Compose model, localhost-only published ports, ignored generated inputs, secret-free examples, immutable runtime image references, and Docker Compose env-file quoting. They do not contact AWS and do not produce a plan.

CI also runs TFLint, Checkov with the documented Development exceptions in
`infra/terraform/checkov.yaml`, and the low-cost architecture policy test. That
test rejects NAT Gateway, ALB, x86 runtime AMIs, open/SSH ingress, an always-on
backtest host, missing queue lanes, a Backtest limit other than Basic 2 / Custom
1 / Competition 1 / total 4, missing `t4g.medium` saturation alarms, or a
non-ARM64 Fargate pipeline.

Corporate-action approval is a separate durable SQS handoff. Backend Worker
publishes `CORPORATE_ACTION_APPROVAL_DECIDED` to its encrypted queue; the ARM64
Fargate Spot Pipeline service has desired/minimum zero and maximum one. A queue
backlog alarm raises desired count to one. Scale-in requires two consecutive
minutes with both visible and in-flight message counts at zero, so an active
regeneration is not terminated merely because its message became invisible.
The worker retains PostgreSQL idempotency and claim ownership; SQS and the ECS
desired count are transport/capacity signals, not business completion evidence.

Room ledger opening uses the shared transactional outbox as F's request source.
Trading Worker must explicitly set `TRADING_ROOM_ACCOUNT_OPEN_ENABLED=true` only
after the migration is present. Its `OPENED` and `OPEN_REJECTED` completion facts
are published through two encrypted SQS queues with independent DLQs; Backend
Worker enables the result consumer and advances `PENDING_LEDGER` only from a
content-hash-bound durable receipt. Verify both the success and permanent
rejection routes before enabling room evaluation traffic.

## Release-candidate inputs

Run the read-only AWS identity and input gate before creating a plan:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-aws-deployment-prerequisites.ps1 -RequireInputs -RequireAlpacaSecrets -RequireRuntimeDatabaseSecrets
```

The command prints only a masked account ID and principal name. It fails when AWS
CLI authentication, the Seoul region, `backend.hcl`, or `terraform.tfvars` is
missing. It never prints credentials or the contents of ignored input files.

If a proposed diagram changes the approved EC2 count, Redis operating product,
durable queue technology, public/private placement, or operator ingress, run a
fresh governance check and obtain product-authority approval before encoding that
choice in Terraform. Keep an unapproved review under `proposals/`.

Before requesting an AWS plan, record and review all of the following:

- exact root commit and exact submodule commits;
- successful CI URL for the exact root commit;
- Terraform version `1.15.x` and AWS provider version from both lockfiles;
- intended Development `deployment_phase` (`market_data_bootstrap`, `dns_foundation`, or `full`) and, when publishing images, the separate `infra/terraform/artifact-foundation` state;
- approved AWS account ID, region, and operator identity from `aws sts get-caller-identity`;
- reviewed `terraform.tfvars` values, with no credentials in the file;
- reviewed S3 backend bucket, key, region, and lockfile settings in ignored `backend.hcl`;
- expected create/update/destroy/replace counts from a saved plan; snapshot the
  stopped historical Batch volume before approving its instance deletion;
- current cost estimate and an owner for every recurring-cost resource;
- database migration/rollback evidence and application image digests for a full rollout;
- five pre-created least-privilege database LOGIN secrets named by
  `runtime_database_secret_names`: `backend`, `batch`, `backtest`, `trading`,
  and `pipeline`. Every JSON secret contains non-empty `engine=postgres`,
  `host`, `port`, `dbname`, `username`, and `password`; the Pipeline secret
  additionally contains a URL-encoded
  `PIPELINE_WORKER_DATABASE_URL`. The runtime IAM roles cannot read the RDS
  master secret;
- S3 version ID and lowercase SHA-256 for both Backtest policy documents and
  every Trading materialization input. Required Trading paths are fixed to
  `instruments.json`, `alpaca-sip-rights.json`, and `warmup/manifest.json`;
- `enable_backtest_outbox_relay=true` only after the exact Backend consumer
  commit and all three queue routes have passed integration tests;
- exact dedicated operator OIDC issuer, JWKS URI, single audience, and MFA
  `acr`/`amr` allow-list, plus the immutable RBAC catalog version and read
  permission UUIDs installed by the reviewed bootstrap receipt. The provider
  must issue RS256 access tokens with `auth_time` and one approved MFA claim.
  Amazon Cognito's default token shape has no `acr`/`amr`, so it is not a
  drop-in substitute for this contract;
- reviewed public GitHub Actions variables for the production UI:
  `OPERATOR_OIDC_ISSUER`, `OPERATOR_OIDC_AUTHORIZATION_ENDPOINT`,
  `OPERATOR_OIDC_TOKEN_ENDPOINT`, optional `OPERATOR_OIDC_END_SESSION_ENDPOINT`,
  `OPERATOR_OIDC_CLIENT_ID`, `OPERATOR_OIDC_AUDIENCE`,
  `OPERATOR_OIDC_REDIRECT_URI`, `OPERATOR_OIDC_POST_LOGOUT_REDIRECT_URI`,
  `OPERATOR_OIDC_SCOPES`, and `OPERATOR_OIDC_SIGNING_ALGORITHM`. Register the
  exact callback and logout URIs with a public Authorization Code + PKCE S256
  client, disable implicit flow, and allow the UI origin at the token endpoint.
  These are public build inputs, never a client secret. The release workflow
  fails closed when one is absent and cross-checks issuer/audience against the
  Terraform runtime inputs;
- DNS record inventory and rollback owner before any registrar delegation change.
- the existing `www.ideatostrategy.com` A record remains pinned to
  `121.254.178.253` during delegation; move it only in a separately reviewed
  CloudFront traffic cutover;
- the SES domain identity is verified, all three DKIM records report `SUCCESS`,
  and the approved sender is `no-reply@ideatostrategy.com`. The Core instance
  role is the credential boundary; do not create SMTP or access keys.

Before enabling real customer email, run the credential-safe SES preflight:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-development-email-delivery-prerequisites.ps1 `
  -ExpectedAwsAccountId <12-digit-development-account> `
  -RequireProductionAccess
```

Without `-RequireProductionAccess`, the command can verify identity and DKIM
while the account remains in the SES sandbox. In the sandbox, recipients must
also be verified and production user flows are not release-ready. Request SES
production access separately; Terraform deliberately cannot approve that
account-level anti-abuse decision. The preflight prints only account/identity
status and public mail configuration, never credentials or message contents.

Stop if the account, region, commit, provider lockfile, backend, or protected product/contract fingerprint differs from the reviewed candidate.

Do not use `deployment_phase=market_data_bootstrap` against state that already
owns the DNS foundation. The hosted zone and frontend bucket use
`prevent_destroy`, so a phase downgrade fails during planning instead of
silently deleting them. Keep `dns_foundation` or `full` for subsequent plans;
intentional retirement requires a separate reviewed code change and DNS/data
recovery plan.

## AWS-only execution remaining

The following steps intentionally remain outside this repository-only readiness pass and require explicit authorization, short-lived credentials, and a reviewed change window:

1. Authenticate to the intended AWS account and verify the caller identity and region.
2. The state bucket already exists. Do not re-apply the bootstrap root without first recovering its historical state. Plan the isolated `infra/terraform/ci-identity` root against its own remote state to create two GitHub Actions OIDC roles. Record the scoped plan/publisher ARN as `AWS_PLAN_ROLE_ARN` in the protected `development-plan` Environment and the privileged exact-plan apply ARN as `AWS_DEPLOY_ROLE_ARN` in the separately protected `development` Environment. Both Environments must allow deployments only from `develop`, require the designated reviewers, prevent self-review, disallow administrator bypass, and contain the exact AWS account/state variables. Do not create a long-lived AWS access key for CI.
3. Populate ignored `backend.hcl` and `terraform.tfvars` from the examples; never commit them.
4. Apply a reviewed `dns_foundation` saved plan first. This creates only the Route 53 zone and the private, encrypted, versioned frontend release bucket in addition to the existing market-data foundation. Copy every existing DNS record, record the Route 53 nameservers, and change the registrar delegation with a tested rollback record. Independently verify public delegation before setting `dns_delegation_verified=true`; a `full` plan is deliberately blocked otherwise.
5. After delegation, build application and frontend inputs without AWS credentials. The `development-plan` job may then use only the scoped plan/publisher role to publish immutable ECR digests and a new `/_releases/<release-id>/` frontend prefix, run `terraform init -backend-config=backend.hcl`, and create `terraform plan -parallelism=1 -out deployment.tfplan`.
6. Review the complete plan, cost impact, replacements, deletions, IAM changes, public network paths, immutable frontend release ID, and database consequences. A non-zero destroy count requires a separate explicit decision.
7. Apply only that reviewed plan file through the separate `development` Environment approval. Do not run an unsaved `terraform apply`.
   The pre-approval plan uses deliberately invalid all-zero image digests and is
   never applyable. Apply only an independently reviewed plan from the isolated
   `infra/terraform/artifact-foundation` root to create ECR repositories. That
   state cannot delete or replace the existing Development compute/database
   state. Publish ARM64 images, then save and re-review a `full` Development plan
   containing real digests.
8. Verify S3 public-access blocks/versioning/encryption, isolated RDS and Valkey
   reachability, RDS deletion protection/backups, EC2 IMDSv2/SSM access,
   CloudFront-prefix-list-only Core ingress, secret-header rejection, no SSH,
   no NAT/ALB, CloudWatch logs/alarms, and Secrets Manager references.
9. For the full phase, bootstrap the five
   database LOGIN roles and Secrets Manager values through the reviewed one-shot
   database procedure, run Flyway once, and set the pinned S3 policy/artifact
   inputs. The EC2 bootstrap then creates root-only mode-0600 env files, verifies
   every S3 version/checksum, authenticates to ECR, validates the Compose model,
   and starts the systemd-owned Core, Backtest, or Trading stack. Verify
   container health/readiness, three-lane queue processing, scheduled Trading
   stop/drain/start, corporate-action approval Queue/DLQ redrive, desired-zero
   Pipeline 0→1→0 completion, and rollback.
   Separately bootstrap the approved operator subject mapping/RBAC catalog,
   record its immutable receipt, configure the exact OIDC inputs, and prove a
   real MFA token succeeds while a stale, wrong-audience, customer, or
   non-MFA token fails closed. Terraform generates the subject HMAC key in the
   Core secret; the IdP token, subject, and bootstrap material never enter
   Terraform variables or state.
10. Continue only after the CloudFront viewer ACM certificate is `ISSUED` and the Core DNS-01 ACME certificate is trusted from CloudFront.
11. Attach the exact plan, apply result, smoke-test evidence, and rollback outcome to the approved deployment record.

After apply, CloudFront atomically serves the immutable frontend prefix named in
the reviewed plan; no mutable S3-root copy or cache invalidation is used. Rollback
means selecting the previous immutable release ID, reviewing that Terraform
plan, and applying only the reviewed saved plan. Run the read-only environment verifier from
the same exact checkout. It prints no credentials:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/verify-deployed-development.ps1 `
  -ExpectedAwsAccountId <12-digit-account-id>
```

It verifies the account/state boundary, HTTPS frontend, Backend and Backtest
health through CloudFront, ACM-backed distribution status, private/versioned
frontend S3, SSM-managed Core, private deletion-protected RDS, available Valkey
Serverless, SQS redrive policies and managed encryption, and required CloudWatch
log groups. The release workflow runs the same verifier automatically after the
saved plan is applied.

No step above should expose credential values in command output, logs, CI artifacts, or issue comments.

## Runtime secret and state boundary

Terraform generates the Core identity keys and the Backtest internal
result-ingestion credentials, then stores them only as Secrets Manager secret
versions. Core and Backtest use separate secrets because IAM cannot authorize a
single JSON field independently. The generated values are still present as
sensitive plaintext inside Terraform state; therefore the remote state bucket,
state IAM policy, versioning, encryption, and access logging are part of the
credential boundary. Never copy state into CI artifacts or a local shared path.
Rotate these secrets by a reviewed replacement plan and coordinated application
restart, not by editing a secret value in place.

Database passwords are intentionally not generated by this runtime root. A
reviewed one-shot database bootstrap must create/rotate each LOGIN, grant only
its NOLOGIN group (`backend`, `batch`, `backtest`, `trading`, or `pipeline`), and
write the matching existing Secrets Manager secret. This prevents application
instances from receiving the RDS master credential and lets a failed or missing
bootstrap stop the full plan before EC2 starts.

### Reviewed Development database bootstrap

The Development Terraform state owns the five Secrets Manager metadata objects,
their seven-day recovery windows, and a dedicated SSM instance profile/security
group. It deliberately owns no runtime database secret version. Apply and review
those additive resources before running the one-shot procedure; if a same-named
secret was created outside Terraform, import it instead of replacing or deleting
it.

From the exact clean root release candidate, first render the credential-free
execution summary:

```powershell
./scripts/invoke-development-database-bootstrap.ps1 `
  -ExpectedAwsAccountId <12-digit-development-account> `
  -PolicySeedSqlPath <approved-policy-seed.sql> `
  -PolicySeedSha256 <reviewed-lowercase-sha256>
```

After reviewing the exact root SHA, Flyway manifest/archive hashes, target
account, region, five secret ARNs, and S3 prefix, execute it in the approved
change window:

```powershell
./scripts/invoke-development-database-bootstrap.ps1 `
  -ExpectedAwsAccountId <12-digit-development-account> `
  -PolicySeedSqlPath <approved-policy-seed.sql> `
  -PolicySeedSha256 <reviewed-lowercase-sha256> `
  -Execute -Confirm
```

The orchestrator uploads versioned, checksum-bound artifacts, grants the
dedicated bootstrap role temporary access to read only the RDS master secret and
write only the five runtime secret versions, and launches one encrypted
`t3.small` with no inbound rules or SSH key. The x86 instance is intentional:
the pinned reviewed Flyway image is amd64-only; all application runtimes remain
ARM64. Systems Manager runs Flyway `migrate` once, then `validate`/`info`, checks
177 application tables, and applies the separately approved, SHA-pinned policy
seed artifact. The seed is mandatory and may insert only into
`trading.fee_policy_versions`,
`trading.buying_power_buffer_policy_versions`, and
`backtest.execution_policy_versions`; it runs as a temporary LOGIN role with
SELECT/INSERT access to only those tables. Forbidden DDL/DCL, transaction,
psql-metacommand, or other-table targets fail closed. Bootstrap verifies at
least one currently effective row in each policy family and records the seed
SHA, row counts, and non-secret policy version/hash identifiers in the receipt.
It then creates or rotates five hardened LOGIN roles, removes
all old memberships, grants exactly one matching NOLOGIN group, verifies direct
connections, and writes the required JSON values. The Pipeline value additionally
contains a URL-encoded `PIPELINE_WORKER_DATABASE_URL` with `sslmode=require`.

Only a credential-free receipt is returned and archived. A `finally` block
revokes the transient inline policy before terminating the exact instance ID and
waiting for termination; its encrypted root volume has
`DeleteOnTermination=true`. A partial failure is recoverable by rerunning the
same reviewed command: Flyway remains checksum/idempotency guarded, each LOGIN
password is rotated, and each secret receives a new `AWSCURRENT` version. Never
copy SSM stderr, process environments, secret JSON, or the RDS master value into
CI artifacts or issue comments.

Backtest scale-down is enabled only on the fenced worker release. The instance
role may call `SetDesiredCapacity(0)` on its exact Backtest ASG and no other
group. The controller requires two consecutive observations with zero durable
`QUEUED`/`RUNNING` runs, zero DB-time live claims, and zero visible, in-flight,
or delayed messages in all three lane queues. Any DB, SQS, or AWS error resets
the gate and keeps the instance running. A message arriving after the final
observation remains durable in SQS and the independent queue alarm restores the
ASG to one; active fenced work never authorizes termination.
