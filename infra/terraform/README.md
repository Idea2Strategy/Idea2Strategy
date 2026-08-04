# Idea2Strategy Terraform

이 디렉터리는 개인 AWS 계정의 `Development` 환경만 관리한다. Production
리소스와 애플리케이션 공개 release는 여기서 생성하지 않는다. 배포 전 검증과
승인 절차는 [deploy-readiness runbook](../../docs/infrastructure/deploy-readiness-runbook.md),
월비용과 민감도는 [COST-ESTIMATE.md](COST-ESTIMATE.md)를 따른다.

## 단계별 생성 범위

`deployment_phase`는 두 단계만 허용한다.

- `market_data_bootstrap`: VPC, public/private DB subnet, private RDS
  PostgreSQL, private Market Data S3, IAM, SSM, CloudWatch 등 공유 데이터
  기반을 관리한다.
- `full`: 위 기반에 private Frontend/Results S3, CloudFront, WAF, Route 53,
  ACM, ECR, 고정 EIP Core `t4g.medium`, 예약 실행 Trading `c7g.xlarge`,
  scale-to-zero Backtest `t4g.medium`, desired-zero ARM64 Fargate Spot Pipeline,
  Valkey Serverless와 durable SQS/DLQ를 추가한다.

`full`에는 NAT Gateway와 ALB가 없다. EC2는 ARM64이고 SSH를 열지 않으며,
Core 443은 AWS 관리 CloudFront origin-facing prefix list에서만 받는다.

현재 EC2 bootstrap은 host 보안·관측·SSM·Core origin proxy뿐 아니라 immutable
digest Compose와 systemd 기반 Core/Trading/Backtest 실행, `backtest-api`,
root-only secret env, version/checksum-pinned runtime artifact materialization까지
구현한다. 다만 5개 최소권한 DB LOGIN/secret bootstrap, 실제 정책 artifact,
검증된 image digest, Flyway, frontend upload/invalidation과 full plan 검토가 끝나기
전에는 Deploy Ready 또는 apply 가능 상태로 취급하지 않는다.

Backtest ASG는 `min=0`, `desired=0`, `max=1`이다. 한 호스트 안에서 Basic 2,
Custom 1, Competition 1, 전체 4개의 실행 slot을 사용하며 초과 요청은 각 SQS
lane에 남는다. main/DLQ URL과 lane 제한은 SSM Parameter Store에서 부팅 시
`/etc/idea2strategy/runtime.env`로 주입된다. `t4g.medium`은 Standard CPU
credit을 사용하고 CPU, credit balance, memory, queue 지연 alarm으로 증설 근거를
수집한다.

## 디렉터리

- `bootstrap/`: Terraform remote state용 S3 bucket을 로컬 state로 한 번
  생성한다.
- `environments/development/`: Development 공유 기반과 전체 서비스 기반을
  관리한다.

## 로컬 검증

Terraform 1.15.x를 사용한다.

```powershell
./scripts/test-full-terraform-architecture.ps1
./scripts/test-terraform-readiness.ps1
tflint --chdir=infra/terraform/bootstrap
tflint --chdir=infra/terraform/environments/development
checkov --directory infra/terraform --config-file infra/terraform/checkov.yaml
```

Terraform이 로컬에 없으면 Docker 검증을 사용한다.

```powershell
./scripts/test-terraform-readiness-docker.ps1
```

## AWS 인증과 plan

장기 Access Key를 만들지 않고 AWS CLI의 단기 browser login을 사용한다.

```powershell
aws login --profile idea2strategy-dev --region ap-northeast-2
aws sts get-caller-identity --profile idea2strategy-dev
aws configure set region ap-northeast-2 --profile idea2strategy-terraform
aws configure set credential_process "C:\PROGRA~1\Amazon\AWSCLIV2\aws.exe configure export-credentials --profile idea2strategy-dev" --profile idea2strategy-terraform
aws sts get-caller-identity --profile idea2strategy-terraform
```

remote state bootstrap과 Development 초기화는 다음 순서다.

```powershell
cd infra/terraform/bootstrap
Copy-Item terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -out bootstrap.tfplan

cd ../environments/development
Copy-Item terraform.tfvars.example terraform.tfvars
Copy-Item backend.hcl.example backend.hcl
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -parallelism=1 -out development.tfplan
```

`terraform.tfvars.example`의 account ID, phase, 실제 immutable image digest 9개,
실제 frontend release ID와 DNS 입력을 확정해야 한다. 0 digest나
`preapproval-plan-only`를 사용한 검토 plan은 절대 apply하지 않는다.

## apply 전 필수 절차

1. 최신 provider 관찰과 governance/review 조건을 확인한다.
2. 실제 ARM64 image 9개를 build, test, scan하고 ECR digest를 고정한다.
3. 실제 frontend artifact와 release ID를 고정한다.
4. 현재 legacy EC2의 100 GiB root EBS snapshot을 만들고 복구 가능성을 확인한다.
5. 실제 digest/release ID로 plan을 다시 만들고 create/update/delete를 검토한다.
6. 비용 추정과 DNS delegation 절차를 승인받은 뒤에만 저장된 exact plan을
   `terraform apply`한다.

현재 legacy EC2 삭제가 포함되므로 snapshot 근거 없는 apply는 금지한다. AWS CLI
단기 session은 plan/apply 직전에 갱신하고 이 계정에서는 API 서명 오류를 줄이기
위해 Terraform 병렬도를 `1`로 제한한다.

## Private RDS 접속

`full` 적용 후 Core EC2를 SSM port-forwarding 경유지로 사용할 수 있다.

```powershell
winget install --id Amazon.SessionManagerPlugin --exact

$serviceInstance = terraform output -raw service_instance_id
$rdsHost = terraform output -raw rds_endpoint
aws ssm start-session `
  --target $serviceInstance `
  --document-name AWS-StartPortForwardingSessionToRemoteHost `
  --parameters "host=$rdsHost,portNumber=5432,localPortNumber=15432" `
  --region ap-northeast-2 `
  --profile idea2strategy-dev
```

터널이 열린 동안에만 `127.0.0.1:15432`로 접속한다. bootstrap-only 단계에는
상시 bastion이 없으며, 임시 host 추가는 별도 plan과 승인이 필요하다.

## DNS와 HTTPS 순서

Terraform은 Route 53 hosted zone과 DNS record를 관리하지만 외부 registrar의
nameserver delegation은 변경하지 않는다.

1. 기존 DNS record를 inventory하고 새 hosted zone으로 빠짐없이 복제한다.
2. Route 53 nameserver와 ACM validation record를 확인한다.
3. 외부 registrar에서 권한 nameserver를 변경한다.
4. ACM `ISSUED`, CloudFront 배포, Core origin certificate와 secret-header 검증을
   확인한다.
5. HTTPS frontend/API health check가 모두 통과한 뒤 공개 검증을 진행한다.

## 안전 원칙

- `terraform.tfvars`, `backend.hcl`, state, plan, credential은 Git에 저장하지 않는다.
- EC2 SSH와 광범위한 public ingress를 만들지 않는다.
- RDS는 private DB subnet과 `publicly_accessible=false`를 유지한다.
- S3는 Public Access Block, versioning, encryption, TLS 강제를 사용한다.
- runtime IAM role에는 remote state bucket 권한을 부여하지 않는다.
- AWS resource 변경, DNS delegation, credential 변경과 공개 배포는 별도 승인된
  exact plan/절차 없이는 실행하지 않는다.
