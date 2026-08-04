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
- intended Development `deployment_phase` (`market_data_bootstrap` or `full`) and, when publishing images, the separate `infra/terraform/artifact-foundation` state;
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
- DNS record inventory and rollback owner before any registrar delegation change.

Stop if the account, region, commit, provider lockfile, backend, or protected product/contract fingerprint differs from the reviewed candidate.

## AWS-only execution remaining

The following steps intentionally remain outside this repository-only readiness pass and require explicit authorization, short-lived credentials, and a reviewed change window:

1. Authenticate to the intended AWS account and verify the caller identity and region.
2. The state bucket already exists. Do not re-apply the bootstrap root without first recovering its historical state. Plan the isolated `infra/terraform/ci-identity` root against its own remote state to create the GitHub Actions OIDC deploy role. Record the role ARN as the protected `AWS_DEPLOY_ROLE_ARN` GitHub Environment variable; do not create a long-lived AWS access key for CI.
3. Populate ignored `backend.hcl` and `terraform.tfvars` from the examples; never commit them.
4. Run `terraform init -backend-config=backend.hcl`, then create a saved plan with `terraform plan -parallelism=1 -out deployment.tfplan`.
5. Review the complete plan, cost impact, replacements, deletions, IAM changes, public network paths, and database consequences. A non-zero destroy count requires a separate explicit decision.
6. Apply only that reviewed plan file. Do not run an unsaved `terraform apply`.
   The pre-approval plan uses deliberately invalid all-zero image digests and is
   never applyable. Apply only an independently reviewed plan from the isolated
   `infra/terraform/artifact-foundation` root to create ECR repositories. That
   state cannot delete or replace the existing Development compute/database
   state. Publish ARM64 images, then save and re-review a `full` Development plan
   containing real digests.
7. Verify S3 public-access blocks/versioning/encryption, isolated RDS and Valkey
   reachability, RDS deletion protection/backups, EC2 IMDSv2/SSM access,
   CloudFront-prefix-list-only Core ingress, secret-header rejection, no SSH,
   no NAT/ALB, CloudWatch logs/alarms, and Secrets Manager references.
8. For the full phase, publish immutable application images, bootstrap the five
   database LOGIN roles and Secrets Manager values through the reviewed one-shot
   database procedure, run Flyway once, and set the pinned S3 policy/artifact
   inputs. The EC2 bootstrap then creates root-only mode-0600 env files, verifies
   every S3 version/checksum, authenticates to ECR, validates the Compose model,
   and starts the systemd-owned Core, Backtest, or Trading stack. Verify
   container health/readiness, three-lane queue processing, scheduled Trading
   stop/drain/start, desired-zero Pipeline completion, and rollback.
9. Copy and verify every existing DNS record before changing registrar
   nameservers. Continue only after the CloudFront viewer ACM certificate is
   `ISSUED` and the Core DNS-01 ACME certificate is trusted from CloudFront.
10. Attach the exact plan, apply result, smoke-test evidence, and rollback outcome to the approved deployment record.

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

Backtest automatic scale-down remains disabled. The current canonical schema
lacks the fenced lease, heartbeat, cancellation, and attempt-lineage columns
needed to prove that an idle worker can terminate without abandoning or
duplicating work. The worker role therefore has no `SetDesiredCapacity`
permission. An operator may return the ASG to desired zero only after all three
queues, in-flight messages, and durable run state have been reviewed; automatic
scale-down can be added only with the approved schema/migration and race tests.
