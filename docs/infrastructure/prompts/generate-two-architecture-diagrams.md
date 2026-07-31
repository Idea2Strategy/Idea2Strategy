# Amazon Q task: generate two Idea2Strategy architecture diagrams

Analyze the latest Idea2Strategy infrastructure documents, ADRs, Terraform, and
diagram sources, then create two separate architecture diagrams.

The active Amazon Q project rule
`.amazonq/rules/infrastructure-diagram-rules.md` is mandatory.

## Goal

Create:

1. a logical `Service Flow` diagram;
2. an `AWS Physical Placement` diagram.

The two diagrams must use the same terminology, status vocabulary, and latest
official AWS Architecture Icons release, while serving different purposes.

## Required source context

Read at least:

- `docs/infrastructure/architecture.md`
- `docs/infrastructure/backend-and-aws-architecture.md`
- `docs/infrastructure/architecture-diagrams.md`
- `docs/infrastructure/questions.md`
- `docs/infrastructure/decisions/ADR-012-three-ec2-backend-aws-baseline.md`
- `docs/infrastructure/decisions/ADR-013-free-plan-batch-ec2-resize.md`
- `docs/infrastructure/diagrams/idea2strategy-server-flow-v3.drawio`
- `docs/infrastructure/diagrams/idea2strategy-service-flow-v3.drawio`
- `docs/infrastructure/diagrams/idea2strategy-aws-physical-placement-v1.drawio`
- `docs/infrastructure/diagrams/idea2strategy-server-flow-v2.drawio`
- `docs/infrastructure/diagrams/idea2strategy-server-flow-v2.png`
- `docs/infrastructure/diagrams/logo-sources.md`
- `infra/terraform/environments/development/`

Use the newest explicit user decision and newest diagram before older documents.
Terraform determines what may be labeled `Deployed`.

## Mandatory two-phase workflow

### Phase 1: audit and ask

Do not create, edit, download, or export files in this phase.

1. Compare the latest user decisions, Draw.io source, ADRs, documents, and
   Terraform.
2. Separate current deployment facts from target architecture.
3. Produce one proposed node-and-edge list for each diagram.
4. Identify conflicts or ambiguities that can change a product, placement,
   boundary, status, or arrow.
5. Ask the user concise questions about all material ambiguities.
6. Wait for the user's answer before Phase 2.

Do not ask about facts that can be discovered from the repository.

### Phase 2: create and verify

Start only after the user answers the Phase 1 questions.

1. Determine the latest official AWS Architecture Icons release from the
   official AWS source.
2. Verify whether existing repository icons match that release.
3. Create the next version of each Draw.io source without overwriting an
   existing file.
4. Export SVG and high-resolution PNG using the Draw.io Desktop CLI.
5. Embed diagram data in SVG and PNG exports.
6. Open or render the exports and visually inspect them.
7. Correct layout or semantic errors and re-export until verification passes.
8. Report created files, icon release, unresolved `TBD` items, and validation
   results.

## Diagram 1: Service Flow

### Purpose

Explain the logical target service and data flow. Prioritize readability of
actors, services, asynchronous work, real-time state, and storage.

Omit Availability Zone, route table, and detailed Subnet structure. A simple
`AWS Cloud / Seoul Region` boundary and an optional simplified
`Application VPC` boundary are sufficient.

### Required layout

Use a left-to-right layout:

```text
External actors and providers
→ DNS and entry
→ Core / Trading / Compute
→ Queue and Redis
→ PostgreSQL and S3
```

Keep the runtime plane visually separate from deployment/operations.

### Required nodes

External:

- User
- Operator
- real-time market data provider

Entry:

- Route 53
- ALB
- ACM

Core EC2:

- `backend-api`
- `backend-batch`
- `backend-worker`
- `admin-mcp`

Trading EC2:

- `market-gateway`
- `trading-worker`

Compute EC2:

- `backtest-api`
- `backtest-worker`
- `pipeline-worker`

Messaging and real-time state:

- `Queue — technology and placement TBD`
- `Redis — hosting model and placement TBD`

Storage:

- PostgreSQL
- Market Data S3
- Results S3

Operations/deployment, in a separate control-plane band:

- GitHub
- GitHub Actions
- ECR
- Systems Manager
- CloudWatch

### Required flows

Public entry:

```text
User → Route 53 DNS alias → ALB → backend-api
Operator → Route 53 DNS alias → ALB → admin-mcp
```

Route 53 to ALB must be labeled `DNS alias resolution`. ALB to Core must be
labeled HTTPS/application traffic.

Trading:

```text
Market data provider → market-gateway → Redis
Queue → trading-worker
Redis → trading-worker
trading-worker → PostgreSQL
```

Backtest:

```text
backend-api → backtest-api
backend-api or backtest-api → Queue
Queue → backtest-worker
backtest-worker → Market Data S3
backtest-worker → Results S3
backtest-worker → PostgreSQL
```

Pipeline:

```text
Queue or schedule → pipeline-worker
pipeline-worker → Market Data S3
pipeline-worker → PostgreSQL
```

Deployment and operations:

```text
GitHub → GitHub Actions → ECR
ECR image digest → Systems Manager → EC2 Docker Compose
EC2 / ALB / RDS → CloudWatch
```

Do not draw SSH deployment or EC2 `git pull`.

### Visual semantics

- solid dark line: synchronous HTTPS, API, or database access;
- dashed orange line: Queue or asynchronous work;
- solid red line: Redis real-time state/cache;
- solid green line: S3 object or Parquet flow;
- dotted gray line: deployment, operations, or observability.

Every arrow must have a direction and a meaningful label where the purpose is
not obvious.

## Diagram 2: AWS Physical Placement

### Purpose

Explain where AWS resources are placed in relation to Region, VPC,
Availability Zones, public/private Subnets, and managed-service boundaries.

This is the latest target placement view. Use `Deployed`,
`Terraform-defined`, `Target`, and `TBD` badges so target resources are not
mistaken for the current deployment.

Do not repeat detailed application flows from the Service Flow diagram.

### Required containment

```text
AWS Cloud
├── Route 53
└── Seoul Region (ap-northeast-2)
    ├── Development VPC (10.20.0.0/16)
    │   ├── Availability Zone A
    │   │   ├── Public Application Subnet A (10.20.0.0/24)
    │   │   └── Private DB Subnet A (10.20.10.0/24)
    │   └── Availability Zone B
    │       ├── Public Application Subnet B (10.20.1.0/24)
    │       └── Private DB Subnet B (10.20.11.0/24)
    └── Regional managed services
```

Read the CIDRs from Terraform again before drawing. If the repository values
have changed, use the current Terraform values.

Do not invent concrete AZ names. Use `AZ A` and `AZ B` unless an authoritative
AWS/Terraform value is available.

### Placement

Outside the Region/VPC:

- users and external market data provider;
- Route 53 as a global service.

Inside the Region but outside the VPC/Subnets:

- ACM;
- Market Data S3 and Results S3;
- ECR;
- CloudWatch;
- Systems Manager;
- Parameter Store;
- Secrets Manager;
- EventBridge;
- Lambda unless VPC attachment is explicitly confirmed.

At the VPC edge:

- Internet Gateway.

Across Public Application Subnet A and B:

- one logical ALB, not two separate ALBs.

Public Application Subnet A, target placement:

- Core EC2;
- Trading EC2;
- Compute EC2.

Private DB Subnet A and B:

- RDS DB subnet group spanning both Subnets;
- one private Single-AZ PostgreSQL RDS instance;
- no invented Multi-AZ standby.

If the active RDS AZ is not known, do not place the RDS instance in a guessed
AZ. Show it in the DB subnet group and label the active AZ as unspecified.

Outside settled Subnet placement with a `TBD` callout:

- Queue;
- Redis.

Do not choose a specific AWS Queue or Redis hosting product.

### Required network and security annotations

- public Subnet route: `0.0.0.0/0 → Internet Gateway`;
- private DB Subnets: no Internet Gateway or NAT default route;
- ALB: public HTTP 80 and HTTPS 443;
- HTTP 80 redirects to HTTPS when HTTPS is enabled;
- ACM certificate attaches to the ALB HTTPS listener;
- ALB target group contains Core EC2 only;
- Core accepts application traffic from the ALB security group only;
- Trading and Compute have no public inbound;
- RDS allows PostgreSQL 5432 only from approved application security groups;
- EC2 operations use Systems Manager;
- no SSH, key-pair access path, or bastion host.

Do not add NAT Gateway, VPC endpoints, WAF, CloudFront, API Gateway, ECS, EKS,
Auto Scaling, Multi-AZ RDS, or a DR Region unless a newer accepted source
explicitly requires one.

## Output names

Write files under `docs/infrastructure/diagrams/`.

Detect the highest existing version and increment it. Suggested families:

```text
idea2strategy-service-flow-vN.drawio
idea2strategy-service-flow-vN.svg
idea2strategy-service-flow-vN.png

idea2strategy-aws-physical-placement-vN.drawio
idea2strategy-aws-physical-placement-vN.svg
idea2strategy-aws-physical-placement-vN.png
```

Do not overwrite `idea2strategy-server-flow-v2.*` or any existing diagram.

## Draw.io CLI validation

Locate Draw.io Desktop before export. On Windows, check `Get-Command drawio`
and common installation paths such as:

```text
C:\Program Files\draw.io\draw.io.exe
C:\Users\<user>\AppData\Local\Programs\draw.io\draw.io.exe
```

Use equivalent commands:

```powershell
drawio -x -f svg -e -b 10 -o <output.svg> <input.drawio>
drawio -x -f png -e -b 10 -s 2 -o <output.png> <input.drawio>
```

The `-e` option embeds editable diagram data. Preserve the `.drawio` source
even when SVG and PNG exports are generated.

## Completion checklist

Before reporting completion, verify:

- exactly two diagram families were created;
- Service Flow emphasizes logical flows and does not contain detailed
  AZ/Subnet layout;
- AWS Physical Placement has correct Region/VPC/AZ/Subnet containment;
- Route 53 and S3 are outside the VPC;
- one ALB spans both public Subnets;
- only Core is an ALB target;
- Queue and Redis are separate and product-neutral;
- RDS is private and Single-AZ without an invented standby;
- direct public EC2 or SSH access is absent;
- target resources are not labeled Deployed;
- undocumented AWS services were not added;
- one latest official AWS icon release is used consistently;
- `.drawio`, `.svg`, and `.png` files render correctly;
- labels, icons, containers, and connectors do not overlap.
