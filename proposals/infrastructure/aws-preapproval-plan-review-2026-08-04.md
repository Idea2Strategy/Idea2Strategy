# AWS Development pre-approval plan review - 2026-08-04

Status: **read-only evidence; not approved for apply**

The plan was generated against the authenticated Development account in
`ap-northeast-2` with `deployment_phase=full`, HTTPS enabled, and the selected
low-cost instance classes. Terraform performed state refresh and planning only;
no AWS resource was created, changed, or deleted.

## Plan summary

- Create: 154 managed resources
- Update in place: 7 managed resources
- Delete: 7 managed resources
- Read during apply: 9 data sources
- NAT Gateway: 0
- ALB/ELB: 0
- Core: one `t4g.small` ARM64 EC2 instance with a fixed EIP
- Trading: one scheduled `c7g.xlarge` ARM64 EC2 instance
- Backtest: `t4g.medium` ARM64 launch template and ASG `0/0/1`
- Pipeline: desired-zero ARM64 Fargate Spot task definition
- Database: private Single-AZ `db.t4g.small` PostgreSQL
- Cache: private Valkey Serverless

## Planned deletions

| Address | Impact |
| --- | --- |
| `aws_instance.batch` | Deletes the stopped legacy `m7i-flex.large` and its 100 GiB root volume. This is the only material data-loss risk. |
| `aws_cloudwatch_metric_alarm.batch_cpu_high` | Removes an alarm tied only to the legacy host. |
| `aws_cloudwatch_metric_alarm.batch_memory_high` | Removes an alarm tied only to the legacy host. |
| `aws_cloudwatch_metric_alarm.batch_status_check_failed` | Removes an alarm tied only to the legacy host. |
| `aws_ssm_association.batch_host_safety` | Removes the legacy-host SSM association. |
| `aws_vpc_security_group_egress_rule.rds_all` | Replaces broad RDS egress with the new deny-by-default boundary. |
| `aws_vpc_security_group_ingress_rule.rds_from_batch` | Replaces access from the legacy batch SG with explicit workload SG rules. |

Before any approved apply, the legacy instance and its root volume require a
named EBS snapshot and restore test/inspection evidence. The historical batch
CloudWatch log group is retained by the new configuration.

## Deliberate non-applyable inputs

All nine container image inputs use the impossible review placeholder
`sha256:000...000`, and the frontend release is `preapproval-plan-only`.
Consequently, this saved plan must never be applied. The deployment guard proves
that all inputs are structurally present; it does not claim that artifacts have
been built or published.

## Required next plan

After architecture approval and the unresolved protected-contract work:

1. Apply only the non-destructive foundation/ECR subset under a separately
   reviewed plan.
2. Build, scan, sign/attest as available, and publish immutable ARM64 images.
3. Produce the real frontend artifact and release identifier.
4. Take the legacy 100 GiB EBS snapshot and record its snapshot ID.
5. Generate a new plan with the exact image digests and release ID.
6. Re-run Terraform validate, TFLint, Checkov, cost comparison, and destructive
   action review before requesting apply approval.

## Release blockers outside Terraform

- GitHub provider governance is `unknown`; protected `specs/**` and
  `contracts/**` cannot be changed or treated as approved.
- Backend contracts do not define Basic/Custom/Competition queue routing, and
  Competition currently emits no backtest work event.
- Backtest recovery lacks a lease-expiry reclaim boundary and still retains
  large event/result collections in memory.
- Data Pipeline lacks the production S3/PostgreSQL publication adapter,
  visibility heartbeat, and durable idempotency ledger.
- Current Trading canonical behavior is virtual execution with Alpaca SIP market
  data, not live Alpaca broker order/fill reconciliation.
- Real deployable image digests and the frontend release artifact do not exist.

These blockers mean the repository is not yet Deploy Ready, even though the
Terraform design and static validation are reviewable.
