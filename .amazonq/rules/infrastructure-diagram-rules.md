# Idea2Strategy infrastructure diagram rules

These rules apply whenever Amazon Q analyzes, creates, or updates Idea2Strategy
infrastructure architecture diagrams.

## 1. Source priority

When sources disagree, use this precedence:

1. The user's latest explicit decision in the current conversation.
2. The newest approved Draw.io flow, currently
   `docs/infrastructure/diagrams/idea2strategy-server-flow-v3.drawio`.
3. The newest Accepted ADR.
4. Terraform for facts about the currently deployed or Terraform-defined AWS
   environment.
5. `docs/infrastructure/architecture.md`.
6. `docs/infrastructure/backend-and-aws-architecture.md`.
7. `docs/infrastructure/architecture-diagrams.md`.
8. Proposed ADRs, `docs/infrastructure/questions.md`, and older diagrams.

Terraform is authoritative for `Deployed` claims. A target design may be based
on the latest approved flow, but a target resource must never be presented as
already deployed.

The latest user decision separates Queue and Redis. Older text that treats
Redis Streams as the queue is superseded for new diagrams.

## 2. Mandatory clarification gate

Before changing a diagram, inspect the sources and list every ambiguity that
could change any of the following:

- AWS product choice
- Deployed versus Target status
- Region, VPC, Availability Zone, or Subnet placement
- trust boundary or public ingress
- arrow direction, producer, or consumer
- synchronous versus asynchronous behavior
- high availability or disaster recovery claims

Ask the user about these ambiguities before editing files. Do not resolve them
by silently applying a generic AWS best practice.

If the technology or placement is not decided and the uncertainty does not
block the overall diagram, label it `TBD` rather than inventing a decision.

## 3. Diagram separation

Create and maintain two different diagrams:

1. `Service Flow` is a logical target view. It emphasizes actors, services,
   Queue, Redis, PostgreSQL, S3, and data or control flow. VPC, Availability
   Zone, and Subnet details are omitted or reduced to a simple boundary.
2. `AWS Physical Placement` is a target placement view. It emphasizes Region,
   VPC, Availability Zones, Subnets, and the actual placement semantics of ALB,
   EC2, and RDS. It may show deployment status badges, but it must not imply
   that a Target resource is Deployed.

Do not combine the two views into one crowded diagram.

## 4. Status vocabulary

Use text badges, not color alone:

- `Deployed`: confirmed by Terraform and current deployment evidence.
- `Terraform-defined`: represented in Terraform but not necessarily enabled in
  the current deployment phase.
- `Target`: part of the latest approved target architecture but not confirmed
  as deployed.
- `TBD`: product, topology, or placement is not decided.

Each diagram must include its view type, status basis, reference date, and a
legend.

## 5. AWS icon rules

Use only the latest official AWS Architecture Icons package available from:

`https://aws.amazon.com/architecture/icons/`

Before drawing:

1. Verify the latest package on the official AWS page.
2. Record the package release, source URL, and verification date.
3. Verify whether repository icons match that release.
4. Use one AWS icon release consistently across both diagrams.

Do not:

- mix AWS icon releases;
- use legacy AWS Simple Icons;
- redraw, recolor, crop, distort, or change the aspect ratio of AWS icons;
- substitute an unofficial icon when the official icon cannot be found;
- represent an undecided product with a specific AWS service icon.

If the latest official icon package cannot be verified or obtained, stop and
ask the user instead of silently using an older package.

Non-AWS products may use their official logo or a neutral labeled component.

## 6. Queue and Redis rules

Queue and Redis are separate components.

- Draw Queue as `Queue — technology and placement TBD`.
- Draw Redis as `Redis — hosting model and placement TBD`.
- Queue represents asynchronous work delivery.
- Redis represents real-time market state and rebuildable cache.

Until a decision is documented, do not use Amazon SQS, Amazon MQ, Amazon MSK,
RabbitMQ, or another specific queue icon. Do not use the Amazon ElastiCache icon
for Redis.

Do not place Queue or Redis in a specific Subnet in the physical diagram until
their hosting models are decided. A small `TBD` callout outside the settled
Subnet layout is acceptable.

## 7. AWS containment and placement

Use this containment hierarchy:

```text
AWS Cloud
└── Seoul Region (ap-northeast-2)
    ├── Development VPC
    │   ├── Availability Zone A
    │   │   ├── Public Application Subnet A
    │   │   └── Private DB Subnet A
    │   └── Availability Zone B
    │       ├── Public Application Subnet B
    │       └── Private DB Subnet B
    └── Regional managed services
```

- Availability Zones must be inside the Region and visually partition the VPC.
- A Subnet must be inside exactly one Availability Zone.
- Do not invent AZ names. If not resolved from Terraform or AWS, use `AZ A` and
  `AZ B`.
- Do not invent CIDRs. Read Terraform values or omit them.
- An Internet Gateway is attached to the VPC boundary, not placed inside a
  Subnet.
- A public Subnet is public because its route table has a default route to the
  Internet Gateway, not merely because of its name or color.

Route 53 is global and outside the Region/VPC. ACM is regional and outside the
VPC. S3, ECR, CloudWatch, Systems Manager, Parameter Store, Secrets Manager, and
EventBridge are regional managed services outside Subnets.

Do not place S3 buckets in a private Subnet. Do not place Lambda in a Subnet
unless VPC attachment is confirmed.

## 8. Current and target placement facts

The current Development Terraform environment includes two public Subnets and
two private DB Subnets across two Availability Zones. The default deployment
phase currently creates the batch/market-data bootstrap host and supporting
resources. The full phase defines an ALB-facing service host and a batch host;
it does not implement the complete three-EC2 target.

The target placement view uses:

- one logical ALB spanning Public Application Subnet A and B;
- Core EC2, Trading EC2, and Compute EC2 in Public Application Subnet A;
- only Core EC2 in the ALB target group;
- no direct public inbound to Core, Trading, or Compute EC2;
- Systems Manager for operational access, with no SSH or bastion path;
- a private PostgreSQL RDS instance;
- an RDS DB subnet group spanning Private DB Subnet A and B;
- Single-AZ RDS unless a later decision explicitly changes it.

Do not draw two independent ALBs. Do not draw a Multi-AZ RDS standby. If the
selected RDS instance AZ is not confirmed, show it in the two-subnet DB subnet
group without inventing an active AZ.

## 9. Required entry and service flows

Preserve this public entry:

```text
User or Operator
→ Route 53 DNS alias
→ ALB HTTPS listener with ACM
→ Core EC2
→ backend-api or admin-mcp
```

Label Route 53 to ALB as DNS resolution rather than an application packet hop.

Target EC2 responsibilities:

- Core EC2: `backend-api`, `backend-batch`, `backend-worker`, `admin-mcp`
- Trading EC2: `market-gateway`, `trading-worker`
- Compute EC2: `backtest-api`, `backtest-worker`, `pipeline-worker`

Required logical flows include:

- market data provider → market-gateway → Redis → trading-worker;
- Queue → trading-worker;
- trading-worker → PostgreSQL;
- backend-api → backtest-api or Queue;
- Queue → backtest-worker;
- backtest-worker → PostgreSQL, Market Data S3, and Results S3;
- Queue or schedule → pipeline-worker;
- pipeline-worker → Market Data S3 and PostgreSQL.

PostgreSQL is the system of record. S3 stores bulk immutable or detailed data.
Redis must remain rebuildable and must not be shown as the official ledger.

## 10. Security and infrastructure omissions

Show or annotate:

- public 80/443 only at the ALB;
- HTTP to HTTPS redirect when HTTPS is enabled;
- ALB security group to Core security group only on the target port;
- no public inbound for Trading and Compute;
- PostgreSQL 5432 only from approved application security groups;
- Systems Manager operations;
- least-privilege IAM;
- Secrets Manager and Parameter Store for sensitive/configuration data;
- S3 public access blocking, encryption, versioning, and TLS enforcement.

Do not add undocumented resources merely because they are common best
practices. In particular, do not invent:

- NAT Gateway
- VPC endpoints
- CloudFront
- WAF
- API Gateway
- bastion host
- ECS or EKS
- Auto Scaling groups
- Multi-AZ RDS
- a disaster recovery Region

## 11. Editing, versioning, and validation

Do not overwrite an existing diagram version. Detect the highest version for
that diagram family and create the next version.

Create all of:

- editable `.drawio`;
- `.svg` with embedded diagram data;
- high-resolution `.png` with embedded diagram data.

Use the Draw.io Desktop CLI for export. Validate that the Draw.io XML opens and
that both exports render. Visually inspect the exported PNG or SVG and correct:

- clipped or unreadable text;
- overlapping nodes;
- connectors crossing labels or container titles;
- misleading containment;
- broken, stretched, or inconsistent icons;
- missing arrow direction or legend.

Use orthogonal connectors where practical and minimize crossings. Preserve user
changes unrelated to the requested diagrams.
