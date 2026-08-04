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

These checks validate formatting, provider lockfile integrity, Terraform configuration with the S3 backend disabled, the merged Compose model, localhost-only published ports, ignored generated inputs, and secret-free examples. They do not contact AWS and do not produce a plan.

## Release-candidate inputs

Run the read-only AWS identity and input gate before creating a plan:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/test-aws-deployment-prerequisites.ps1 -RequireInputs
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
- intended `deployment_phase` (`market_data_bootstrap` or `full`);
- approved AWS account ID, region, and operator identity from `aws sts get-caller-identity`;
- reviewed `terraform.tfvars` values, with no credentials in the file;
- reviewed S3 backend bucket, key, region, and lockfile settings in ignored `backend.hcl`;
- expected create/update/destroy/replace counts from a saved plan;
- current cost estimate and an owner for every recurring-cost resource;
- database migration/rollback evidence and application image digests for a full rollout;
- DNS record inventory and rollback owner before any registrar delegation change.

Stop if the account, region, commit, provider lockfile, backend, or protected product/contract fingerprint differs from the reviewed candidate.

## AWS-only execution remaining

The following steps intentionally remain outside this repository-only readiness pass and require explicit authorization, short-lived credentials, and a reviewed change window:

1. Authenticate to the intended AWS account and verify the caller identity and region.
2. If it does not exist, plan and apply the bootstrap root to create the remote state bucket.
3. Populate ignored `backend.hcl` and `terraform.tfvars` from the examples; never commit them.
4. Run `terraform init -backend-config=backend.hcl`, then create a saved plan with `terraform plan -parallelism=1 -out deployment.tfplan`.
5. Review the complete plan, cost impact, replacements, deletions, IAM changes, public network paths, and database consequences. A non-zero destroy count requires a separate explicit decision.
6. Apply only that reviewed plan file. Do not run an unsaved `terraform apply`.
7. Verify S3 public-access blocks/versioning/encryption, RDS private reachability/deletion protection/backups, EC2 IMDSv2/SSM access, security-group paths, CloudWatch logs/alarms, and Secrets Manager references.
8. For the full phase, publish immutable application images, configure runtime secrets through AWS-managed stores, run Flyway once, verify health/readiness and worker processing, and test rollback.
9. Copy and verify every existing DNS record before changing registrar nameservers. Enable HTTPS only after ACM reports `ISSUED`.
10. Attach the exact plan, apply result, smoke-test evidence, and rollback outcome to the approved deployment record.

No step above should expose credential values in command output, logs, CI artifacts, or issue comments.
