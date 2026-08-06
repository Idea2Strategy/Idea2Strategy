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
- intended Development `deployment_phase` (`market_data_bootstrap`, `dns_foundation`, `host_ready`, or `full`) and, when publishing images, the separate `infra/terraform/artifact-foundation` state;
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
  `OPERATOR_OIDC_LOGOUT_REDIRECT_PARAMETER`,
  `OPERATOR_OIDC_SCOPES`, `OPERATOR_OIDC_SIGNING_ALGORITHM`,
  `OPERATOR_RBAC_CATALOG_READ_PERMISSION_ID`, and
  `OPERATOR_RBAC_ASSIGNMENT_READ_PERMISSION_ID`. The dedicated Cognito pool
  uses the approved signed namespaced claim
  `https://ideatostrategy.com/claims/mfa=cognito:mfa-required`; Backend still
  enforces the exact issuer, client audience, RS256 signature, and signed
  `auth_time` freshness. The two permission UUIDs must
  come from the same reviewed operator RBAC bootstrap receipt used by the
  Terraform runtime inputs. Register the
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

## Pre-DNS host verification

Use `deployment_phase=host_ready` after immutable runtime artifacts and the
database bootstrap receipt are ready. This phase creates the runtime hosts,
Valkey, queues, runtime IAM and SSM configuration, but does not create or enable
CloudFront, ACM, or public DNS traffic. Core has no inbound security-group rule;
the public EIP is stable preparation for the later edge cutover, not an access
path. Transactional email also remains disabled until SES identity verification
and the `full` cutover succeed.

Verify bootstrap and localhost health through SSM without opening a port:

```powershell
$coreInstanceId = terraform -chdir=infra/terraform/environments/development output -json core_ssm_health |
  ConvertFrom-Json | Select-Object -ExpandProperty instance_id

aws ssm start-session `
  --profile idea2strategy-dev `
  --region ap-northeast-2 `
  --target $coreInstanceId `
  --document-name AWS-StartPortForwardingSession `
  --parameters '{"portNumber":["8080"],"localPortNumber":["18080"]}'
```

While the session is open, request
`http://127.0.0.1:18080/actuator/health`. On the host, the authoritative target
is `http://127.0.0.1:8080/actuator/health`; Backtest API uses
`http://127.0.0.1:8082/health`. Also require `cloud-init status --wait` and
`systemctl is-active idea2strategy-runtime` through an SSM shell. Do not set
`dns_delegation_verified=true` or use `full` until the registrar change is
complete and independently resolved against all delegated nameservers.

## AWS-only execution remaining

The following steps intentionally remain outside this repository-only readiness pass and require explicit authorization, short-lived credentials, and a reviewed change window:

1. Authenticate to the intended AWS account and verify the caller identity and region.
2. The state bucket already exists. Do not re-apply the bootstrap root without first recovering its historical state. Plan the isolated `infra/terraform/ci-identity` root against its own remote state to create two GitHub Actions OIDC roles. Record the scoped plan/publisher ARN as `AWS_PLAN_ROLE_ARN` in the protected `development-plan` Environment and the privileged exact-plan apply ARN as `AWS_DEPLOY_ROLE_ARN` in the separately protected `development` Environment. Both Environments must allow deployments only from `develop`, require the designated reviewers, prevent self-review, disallow administrator bypass, and contain the exact AWS account/state variables. Do not create a long-lived AWS access key for CI.
3. Populate ignored `backend.hcl` and `terraform.tfvars` from the examples; never commit them.
4. Apply a reviewed `dns_foundation` saved plan first. This creates only the Route 53 zone and the private, encrypted, versioned frontend release bucket in addition to the existing market-data foundation. Copy every existing DNS record and record the Route 53 nameservers, but do not change the registrar delegation yet.
5. Bootstrap the five database LOGIN roles and Secrets Manager values through the reviewed one-shot database procedure, run Flyway once, and prepare the pinned S3 policy/artifact inputs. Build application inputs without AWS credentials. The `development-plan` job may then use only the scoped plan/publisher role to publish immutable ECR digests, run `terraform init -backend-config=backend.hcl`, and save a `host_ready` plan with `terraform plan -parallelism=1 -out deployment.tfplan`.
   The release job requires the versioned receipt at the exact
   `deployment-bootstrap/<root-sha>/<flyway-bundle-sha>/receipt.json` key. It
   also requires all five receipt-bound database secret versions to remain
   `AWSCURRENT`; a receipt from an older root or Flyway bundle is not accepted.
6. Review the complete `host_ready` plan, cost impact, replacements, deletions, IAM changes, immutable artifacts, and database consequences. It must contain no CloudFront, ACM, public DNS cutover, or unreviewed destroy action.
   The release workflow converts the saved plan to JSON and rejects ordinary
   deletes and all replacements except its exact create-before-destroy
   allow-list for ECS task-definition revisions and the Core/Trading EC2
   instances. Allowed replacements must preserve their reviewed type and stable
   network, IAM, security-group, and task identity; RDS, subnet, security group,
   hosted-zone, S3, and secret replacement remains prohibited.
7. Apply only that reviewed `host_ready` plan file through the separate `development` Environment approval. Do not run an unsaved `terraform apply`.
   The pre-approval plan uses deliberately invalid all-zero image digests and is
   never applyable. Apply only an independently reviewed plan from the isolated
   `infra/terraform/artifact-foundation` root to create ECR repositories. That
   state cannot delete or replace the existing Development compute/database
   state. Publish ARM64 images, then save and re-review a `host_ready` Development plan
   containing real digests.
8. Verify S3 public-access blocks/versioning/encryption, isolated RDS and Valkey
   reachability, RDS deletion protection/backups, EC2 IMDSv2/SSM access, no Core
   inbound rule, no SSH, no NAT/ALB, CloudWatch logs/alarms, Secrets Manager
   references, and both Core health endpoints over SSM localhost forwarding.
9. The EC2 bootstrap creates root-only mode-0600 env files, verifies
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
10. Only after host verification succeeds, review the copied DNS inventory and rollback record, change the registrar delegation, and independently verify every Route 53 nameserver before setting `dns_delegation_verified=true`.
11. Publish the immutable frontend prefix, save and review a separate `full` plan, and require zero replacement/deletion. Apply only that plan after approval; then verify CloudFront-prefix-list-only Core ingress, secret-header rejection, the viewer ACM certificate is `ISSUED`, and the Core DNS-01 ACME certificate is trusted from CloudFront.
12. Attach both exact plans, apply results, SSM/public smoke-test evidence, and rollback outcome to the approved deployment record.

After apply, CloudFront atomically serves the immutable frontend prefix named in
the reviewed plan; no mutable S3-root copy or cache invalidation is used. Rollback
means selecting the previous immutable release ID, reviewing that Terraform
plan, and applying only the reviewed saved plan. Run the read-only environment verifier from
the same exact checkout. It prints no credentials:

For the always-on Core host, changing the SSM image parameters alone is not a
deployment. The release workflow invokes the systemd-owned runtime start program
through SSM after apply, proves that Backend API, Backend Worker, and Backtest API
each run the exact applied repository digest, and observes a stable health
window. If rollout or digest verification fails, the host restores the previous
digest-pinned Compose file before the release job fails. The final verifier
independently repeats the exact SSM-parameter-to-container-image comparison.

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
  -PolicySeedSha256 <reviewed-lowercase-sha256> `
  -ScoringSeedSqlPath <approved-scoring-template-seed.sql> `
  -ScoringSeedSha256 <reviewed-lowercase-sha256>
```

After reviewing the exact root SHA, Flyway manifest/archive hashes, target
account, region, five secret ARNs, and S3 prefix, execute it in the approved
change window:

```powershell
./scripts/invoke-development-database-bootstrap.ps1 `
  -ExpectedAwsAccountId <12-digit-development-account> `
  -PolicySeedSqlPath <approved-policy-seed.sql> `
  -PolicySeedSha256 <reviewed-lowercase-sha256> `
  -ScoringSeedSqlPath <approved-scoring-template-seed.sql> `
  -ScoringSeedSha256 <reviewed-lowercase-sha256> `
  -Execute -Confirm
```

The orchestrator uploads versioned, checksum-bound artifacts, grants the
dedicated bootstrap role temporary access to read only the RDS master secret and
write only the five runtime secret versions, and launches one encrypted
`t3.small` with no inbound rules or SSH key. The x86 instance is intentional:
the pinned reviewed Flyway image is amd64-only; all application runtimes remain
ARM64. Systems Manager runs Flyway `migrate` once, then `validate`/`info`, checks
178 application tables, and applies the separately approved, SHA-pinned policy
seed artifact. The seed is mandatory and may insert only into
`trading.fee_policy_versions`,
`trading.buying_power_buffer_policy_versions`, and
`backtest.execution_policy_versions`; it runs as a temporary LOGIN role with
SELECT/INSERT access to only those tables. Forbidden DDL/DCL, transaction,
psql-metacommand, or other-table targets fail closed. Bootstrap verifies at
least one currently effective row in each policy family. A second independently
approved SHA-pinned scoring seed may target only
`competition.scoring_template_versions`; it is applied in its own transaction,
fails on an immutable identity/content collision, and must produce exactly four
expected active catalog identities. Until its exact proposal commit is approved,
do not supply it to an executable bootstrap invocation. The receipt records both
seed SHAs, row counts, and non-secret policy/scoring version/hash identifiers.
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
