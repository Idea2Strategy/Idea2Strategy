# AWS Development architecture review proposal — 2026-08-04

Status: **isolated proposal; implementation may be reviewed, but protected product meaning is not approved**

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
  Edge -->|"/api/* and /ws/*; HTTPS + secret header"| Core["Core EC2 t4g.small\nfixed EIP, public subnet"]

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

- Core is the only 24-hour application process. It receives webhooks, commits
  authoritative PostgreSQL transactions, and publishes durable work through an
  outbox. It must not continuously run batch, MCP, pipeline, backtest, or trading
  worker JVMs.
- Trading is On-Demand, never Spot. EventBridge Scheduler starts it at 08:00 and
  stops it at 17:00 in `America/New_York`. Startup and shutdown reconciliation
  must compare Alpaca orders/fills with PostgreSQL, preserve idempotency, and
  keep `extended_hours=false`.
- Backtest starts when any lane has visible work. Scale-down is worker-initiated
  only after all three queues have zero visible/in-flight messages, PostgreSQL
  has no valid RUNNING claim, result/checkpoint persistence is confirmed, and a
  15-minute idle grace elapsed. SQS approximate metrics alone never stop it.
- Pipeline has no ECS service. A schedule/event invokes one ARM64 Fargate Spot
  task with a public IP for egress; checkpoints and content-addressed manifests
  remain in S3.
- Valkey contains only reconstructible session/cache/temporary-stream state.
  Orders, fills, ledgers, claims, and outbox records remain authoritative in
  PostgreSQL.

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
