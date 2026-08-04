# AWS Development architecture review proposal — 2026-08-04

Status: **technical topology accepted by the requester; protected product and contract meaning remains an isolated proposal until the GitHub governance gate passes**

The supplied diagram is a useful logical responsibility map, but it is not safe
to deploy unchanged. It omits subnet and route boundaries, concrete queue
semantics, runtime lifecycle, origin authentication, recovery rules, and cost
controls. A fresh governance observation is still unavailable, so this proposal
does not edit `specs/**` or `contracts/**`.

## Selected low-cost Development topology

```mermaid
flowchart TB
  Client["User / operator"] --> R53["Route 53"] --> Edge["CloudFront + WAF"]
  Edge -->|"default + OAC"| Web["Private frontend S3"]
  Edge -->|"/api/* and /ws/*; HTTPS + secret header"| Core["Core EC2 t4g.medium\nfixed EIP"]

  subgraph VPC["Development VPC — ap-northeast-2"]
    subgraph Public["Public application subnets — 2 AZ"]
      Core
      Trading["Trading EC2 c7g.xlarge\n08:00–17:00 America/New_York"]
      Backtest["Backtest ASG t4g.medium\nmin/desired 0, max 1"]
      Pipeline["Fargate Spot ARM64\nRunTask only, desired zero"]
    end
    subgraph Isolated["Isolated data subnets — 2 AZ"]
      RDS["RDS PostgreSQL 16\ndb.t4g.small Single-AZ"]
      Cache["Valkey Serverless\nTLS private endpoint"]
    end
    Core --> Basic["SQS basic + DLQ"]
    Core --> Custom["SQS custom + DLQ"]
    Core --> Competition["SQS competition + DLQ"]
    Basic --> Backtest
    Custom --> Backtest
    Competition --> Backtest
    Core --> RDS
    Trading --> RDS
    Backtest --> RDS
    Core --> Cache
    Trading --> Cache
    Backtest --> Market["Market-data S3"]
    Backtest --> Results["Results S3"]
    Pipeline --> Market
  end
```

There is deliberately no NAT Gateway, ALB, bastion, SSH rule, always-on
backtest/pipeline host, or Development Multi-AZ database. Runtime instances use
ARM64 images, IMDSv2 with hop limit one, SSM, encrypted gp3, and no inbound rules
except Core TCP 443 from the AWS-managed CloudFront origin-facing prefix list.
CloudFront also sends a per-distribution secret header; Nginx retrieves the
secret at runtime and rejects requests without it. DNS-01 ACME provides the
trusted Core origin certificate without opening port 80 or exporting private
keys through Terraform.

## Why this differs from the earlier USD 240 design

The earlier estimate assumed three private always-on EC2 roles, a NAT Gateway,
an ALB, node-based Valkey, and a large always-on x86 Compute host. Those fixed
charges dominated the bill. This design removes roughly USD 43/month NAT,
USD 16/month ALB, and about USD 86/month always-on large Compute, then replaces
them with a scheduled Trading host, a 100-hour example Backtest worker, and
event-only Fargate Spot. The trade is explicit: Development has lower ingress
and egress infrastructure redundancy, and public-IP runtime subnets require very
strict security groups and host hardening.

## Runtime and recovery rules

- Core is the only 24-hour application host. The recommended continuous units
  are `backend-api`, the durable outbox `backend-worker`, and the result-reading
  `backtest-api`. `backend-batch` runs only for scheduled jobs and `admin-mcp`
  only during an authorized operator session. Pipeline, Trading, and the
  compute-heavy Backtest worker do not run on Core.
- Trading is On-Demand, never Spot. EventBridge Scheduler starts it at 08:00 and
  stops it at 17:00 in `America/New_York`. Startup and shutdown reconciliation
  must compare Alpaca orders/fills with PostgreSQL, preserve idempotency, and
  keep `extended_hours=false`.
- Backtest starts when any lane has visible work. The single `t4g.medium` worker
  target exposes four logical slots: Basic 2, Custom 1, and Competition 1; requests over
  a lane limit remain queued. The instance uses Standard CPU credits and raises
  CPU, credit-balance, memory, and queue-latency alarms so resizing is driven by
  evidence. Scale-down is worker-initiated only after all three queues have zero
  visible/in-flight messages, PostgreSQL has no valid RUNNING claim,
  result/checkpoint persistence is confirmed, and a 15-minute idle grace elapsed.
  SQS approximate metrics alone never stop it.
- Pipeline has no ECS service. A schedule/event invokes one ARM64 Fargate Spot
  task with a public IP for egress; checkpoints and content-addressed manifests
  remain in S3.
- Valkey contains only reconstructible session/cache/temporary-stream state.
  Orders, fills, ledgers, claims, and outbox records remain authoritative in
  PostgreSQL.

## Requester-confirmed decisions

The requester confirmed the following technical decisions on 2026-08-04. This
record is deliberately outside the protected canonical paths; the product and
cross-service contract portions must still receive an exact GitHub provider
approval before they can be integrated into `specs/**` or `contracts/**`.

- Core is `t4g.medium`. `backend-api`, `backend-worker`, and the result-reading
  `backtest-api` are continuous; `backend-batch` and `admin-mcp` are on demand.
- Backtest is `t4g.medium` ASG `0/0/1`, with Basic 2, Custom 1, and Competition
  1 logical execution slots. Excess lane requests remain in their SQS queues.
- Trading is scheduled `c7g.xlarge` On-Demand. Pipeline is desired-zero ARM64
  Fargate Spot.
- The public hostname is the apex `ideatostrategy.com`. Neither
  `dev.ideatostrategy.com` nor `origin.dev.ideatostrategy.com` is used. The
  required non-user-facing CloudFront origin is `origin.ideatostrategy.com` to
  avoid an apex-to-itself routing loop and to provide origin TLS.
- Route 53 becomes authoritative after existing DNS records are copied and
  checked by GitHub owner `Juwon-Na` and AWS operator `admin-Pearwon99`.
- CI/CD uses GitHub OIDC, immutable image digests, a reviewed Terraform plan,
  a protected Development environment, and an explicit apply approval. No
  long-lived AWS access key is stored in GitHub.
- Frontend assets use immutable versioned keys. Deployment invalidates only
  entry documents; rollback restores the previous entry document/release
  manifest and invalidates those same paths.
- The accepted low-cost Development availability posture is Single-AZ RDS,
  one Core host, one-at-a-time Backtest host, scheduled Trading, and Spot
  Pipeline. Queues, database backups, S3 versioning, health alarms, and tested
  reconstruction are the recovery controls; this is not a production HA SLA.

## Read-only AWS inventory observed at confirmation

The authenticated `idea2strategy-terraform` profile resolves to IAM user
`admin-Pearwon99` in the intended account. No secret values were read.

- No Route 53 hosted zone for `ideatostrategy.com` exists yet.
- No matching ACM certificate exists in Seoul or `us-east-1`.
- No CloudFront distribution currently has a custom alias.
- Secrets Manager contains `idea2strategy-dev/database/market-loader`.
- Parameter Store already contains the database host, port, name, master and
  market-loader secret ARNs, plus the market-data bucket name under
  `/idea2strategy/dev/**`.
- The account API cannot enumerate registrar domains because Route 53 Domains
  is unavailable for this Free Tier account. Registrar delegation therefore
  remains a controlled human step with the original nameservers retained for
  rollback.

## Deployment-unit implementation boundary

The current Terraform plan is an infrastructure envelope, not a complete
application rollout. Its EC2 bootstrap does not start application containers,
and the diagram's process grouping cannot be copied onto the selected sizes
without correction:

- Core placement is `backend-api`, the durable outbox relay `backend-worker`,
  and `backtest-api` continuously on `t4g.medium`, with explicit heap/container
  limits. `backend-batch` and `admin-mcp` start only on demand.
- The Backtest worker remains the approved `t4g.medium` ASG `0/0/1` with Basic
  2, Custom 1, Competition 1, total 4. The recommended placement for the
  independently packaged `backtest-api` is Core, bound to an internal/loopback
  route, because its durable result-read endpoints must remain available while
  the worker ASG is zero. This recommendation increases the Core memory envelope
  and still requires the API's production collaborator factories and auth route
  to be implemented and verified; those are not invented by Terraform.
- A complete rollout therefore still needs reviewed systemd/container units,
  runtime secret and database/cache/queue wiring, health checks, graceful drain,
  frontend artifact publication/invalidation, and an explicit `backtest-api`
  placement decision. Terraform must not be applied as a service rollout before
  those units and tests exist.

The accepted planning envelope is USD 150-165/month under the documented usage
assumptions, with a USD 180 monthly budget and alerts at 80% and 100%. A USD 200
operational boundary triggers explicit resizing or schedule review. Tax,
internet transfer, unexpected log volume, Backtest burst hours, and Alpaca
market-data subscription charges remain outside or variable.

## Approval and apply gates

1. Review the saved full Terraform plan and current cost report.
2. Obtain fresh protected-meaning approval through the configured GitHub review
   provider before integrating queue/recovery semantics into canonical sources.
3. Confirm the exact AWS account, hosted zone/delegation, artifact digests,
   frontend release ID, budget owner, and alert destination.
4. Apply foundation/ECR first, publish ARM64 immutable images, produce a second
   exact plan with real digests, and obtain confirmation for that candidate.
5. Apply infrastructure, validate DNS/ACM/ACME, migrate PostgreSQL, roll out Core,
   Trading, Backtest and Pipeline separately, and capture rollback evidence.

No AWS mutation, DNS delegation, image publication, service rollout, or release
is authorized by this proposal alone.
