# Development monthly cost model

Basis date: 2026-08-04. Region: Asia Pacific (Seoul), `ap-northeast-2`.
The model uses a 730-hour month, the US-market weekday schedule for Trading,
100 Backtest instance-hours, and event-only Pipeline work. Taxes, credits, Free
Tier, data transfer, and request-dependent charges are not deducted.

## Why the old USD 96.83 estimate became approximately USD 240

The change was primarily a scope and uptime-model change, not AWS price
inflation. The original USD 96.83 estimate was a preliminary extension of the
USD 36.17 market-data bootstrap. It counted a small service EC2 host, RDS,
basic storage, one ALB, Route 53, ACM, Results S3, and ECR. It explicitly said
that actual service sizing and data usage still had to be determined.

The first diagram-based production-like interpretation added costs that the
USD 96.83 model did not include or did not run continuously:

| Added or changed assumption | Approximate monthly impact | Why it mattered |
| --- | ---: | --- |
| NAT Gateway | +USD 43 before data processing | A NAT was not in the USD 96.83 model. Private runtime subnets made it a new fixed cost. |
| Always-on `m7i-flex.large` compute host | +USD 86 | The diagram grouped Backtest and Pipeline on a large x86 host instead of scaling them to zero. |
| Separate/always-on service roles | variable, material | Trading and workers were interpreted as continuously running deployment units rather than scheduled or desired-zero units. |
| Managed cache, logs, queues, secrets, extra public IPv4 and transfer | at least the remaining USD 14, then usage-dependent | These services were absent or only partially represented in the preliminary estimate. |

The two dominant newly modeled fixed charges explain about USD 129 of the USD
143.17 gap (43 + 86). The remaining roughly USD 14.17 is readily consumed by
cache, additional runtime hours, IPv4, logging, queues, secrets, and transfer.
The ALB's roughly USD 16 monthly charge was already included in the USD 96.83
model, so it is part of the USD 240 total but must not be counted again as an
increase. The USD 240 number should therefore be understood as an
over-provisioned architecture scenario, not as a like-for-like price revision.

## Selected low-cost design

| Component | Planning assumption | Monthly USD |
| --- | --- | ---: |
| Core EC2 | `t4g.small`, USD 0.0208/h x 730 h | 15.18 |
| Trading EC2 | `c7g.xlarge`, USD 0.1632/h x about 196 h | 31.95 |
| Backtest EC2 | `t4g.medium`, USD 0.0416/h x 100 h | 4.16 |
| Pipeline | ARM64 Fargate Spot, event-only | 1-3 |
| RDS PostgreSQL | `db.t4g.small`, USD 0.051/h x 730 h, plus gp3/backup | 39-45 |
| Valkey | Serverless, low-usage 100 MB floor | 6-10 |
| EBS | Encrypted gp3 runtime and scratch volumes | 4-7 |
| Public IPv4 | Fixed Core EIP plus scheduled runtime hours | 5-6 |
| Edge | CloudFront, WAF, Route 53, viewer certificate | 10-15 |
| Object and artifact storage | S3 and ECR | 2-4 |
| Operations | CloudWatch, SQS, Secrets Manager, EventBridge | 8-15 |
| **Expected range** | usage-dependent Development workload | **126-166** |
| **Normal review target** | budgeted operating band | **135-150** |

The EC2 and RDS hourly rates were queried from the AWS Price List API on
2026-08-04 for Linux On-Demand/shared tenancy and PostgreSQL Single-AZ in Seoul.
AWS documents the public IPv4 price as USD 0.005 per IP-hour, Route 53 as USD
0.50 per month for each of the first 25 hosted zones, and Valkey Serverless with
a 100 MB minimum measured storage floor. WAF, CloudWatch, S3, SQS, Valkey ECPU,
backup, and transfer charges depend on actual traffic, so the estimate is a
range rather than a false-precision single number.

## Cost controls and sensitivity

- Terraform contains no NAT Gateway and no ALB.
- Trading runs only 08:00-17:00 `America/New_York` on weekdays.
- Backtest ASG is `min=0`, `desired=0`, `max=1`; each additional 100 hours adds
  about USD 4.16 before storage and logs.
- Pipeline has no ECS service and uses ARM64 Fargate Spot RunTask invocations.
- Raising Core to `t4g.medium` adds about USD 15 per month and requires measured
  memory, CPU-credit, GC, OOM, or latency evidence.
- One NAT Gateway would add about USD 43 per month before per-GB processing.
- One ALB would add about USD 16 per month before LCU and data charges.
- RDS Multi-AZ approximately doubles database instance cost and adds storage/I/O
  variance; it is intentionally deferred for Development.
- The Terraform budget default is USD 150. A budget alarm warns; it does not
  enforce a hard spending limit.

A plan with real immutable image digests and a final AWS Pricing Calculator or
Billing comparison is required before any apply.
