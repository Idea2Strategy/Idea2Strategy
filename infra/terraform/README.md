# Idea2Strategy Terraform

배포 전 로컬/CI 검증과 AWS 작업자 체크리스트는 [deploy-readiness runbook](../../docs/infrastructure/deploy-readiness-runbook.md)을 따른다. 이 검증은 AWS 자격 증명이나 remote backend 없이 실행되며 실제 리소스를 변경하지 않는다.

현재 구축 대상은 개인 AWS 계정의 `Development` 환경 하나다. Production 리소스는 이 디렉터리에서 생성하지 않는다.

현재 구성의 24시간 월비용 추정은 [COST-ESTIMATE.md](COST-ESTIMATE.md)에서 확인한다.

## 단계별 생성 범위

`deployment_phase`로 지금 필요한 리소스와 향후 서비스 리소스를 구분한다.

- `market_data_bootstrap`(현재): 과거 시장 데이터 적재에 필요한 VPC, SSM 배치 EC2 1대, 비공개 RDS PostgreSQL 16, 비공개 Market Data S3, IAM·SSM·CloudWatch만 생성한다.
- `full`(향후): 위 구성에 서비스 EC2, ALB, Route 53, ACM, Results S3와 ECR을 추가한다.

현재는 `market_data_bootstrap`만 적용한다. 서비스 애플리케이션 배포 준비가 끝나기 전에는 `full`로 변경하지 않는다.

## 디렉터리

- `bootstrap/`: Terraform 원격 State용 S3 버킷을 로컬 State로 한 번 생성한다.
- `environments/development/`: 단계에 따라 Development의 최소 데이터 적재 기반 또는 전체 서비스 기반을 관리한다.

## 적용 순서

1. AWS CLI 임시 로그인

   ```powershell
   aws login --profile idea2strategy-dev --region ap-northeast-2
   aws sts get-caller-identity --profile idea2strategy-dev
   aws configure set region ap-northeast-2 --profile idea2strategy-terraform
   aws configure set credential_process "C:\PROGRA~1\Amazon\AWSCLIV2\aws.exe configure export-credentials --profile idea2strategy-dev" --profile idea2strategy-terraform
   aws sts get-caller-identity --profile idea2strategy-terraform
   ```

   `idea2strategy-dev`는 브라우저 로그인 세션이고 `idea2strategy-terraform`은 그 임시 자격 증명을 Terraform AWS Provider에 전달하는 로컬 프로필이다. 두 프로필 모두 장기 Access Key를 저장하지 않는다.

2. State 버킷 bootstrap

   ```powershell
   cd infra/terraform/bootstrap
   Copy-Item terraform.tfvars.example terraform.tfvars
   terraform init
   terraform plan -out bootstrap.tfplan
   terraform apply bootstrap.tfplan
   terraform output
   ```

3. `development/backend.hcl.example`을 `backend.hcl`로 복사하고 bootstrap 출력의 버킷 이름을 입력한다.

4. Development 초기화와 검증

   ```powershell
   cd ../environments/development
   Copy-Item terraform.tfvars.example terraform.tfvars
   Copy-Item backend.hcl.example backend.hcl
   terraform init -backend-config=backend.hcl
   terraform validate
   terraform plan -parallelism=1 -out market-data-bootstrap.tfplan
   ```

5. `terraform plan`과 비용 발생 리소스를 검토한 뒤에만 `terraform apply -parallelism=1 market-data-bootstrap.tfplan`을 실행한다.

AWS CLI `login`으로 발급되는 단기 세션은 만료 시간이 짧다. plan/apply 직전에 다시 로그인하고, 이 계정에서는 AWS API 서명 오류를 피하기 위해 Terraform 병렬도를 `1`로 제한한다.

## 로컬에서 Private RDS 접속

Session Manager Plugin을 설치한다.

```powershell
winget install --id Amazon.SessionManagerPlugin --exact
```

Development 디렉터리에서 Terraform 출력으로 대상만 가져온 뒤 로컬 포트 포워딩을 연다.

```powershell
$batchInstance = terraform output -raw batch_instance_id
$rdsHost = terraform output -raw rds_endpoint

aws ssm start-session `
  --target $batchInstance `
  --document-name AWS-StartPortForwardingSessionToRemoteHost `
  --parameters "host=$rdsHost,portNumber=5432,localPortNumber=15432" `
  --region ap-northeast-2 `
  --profile idea2strategy-dev
```

터널이 열린 동안 로컬 애플리케이션은 RDS 주소 대신 `127.0.0.1:15432`로 접속한다. 터널 터미널을 종료하면 외부에서 RDS로 들어가는 경로도 즉시 닫힌다.

## DNS 적용 순서

Terraform은 `ideatostrategy.com`의 Route 53 Hosted Zone을 새로 만들지만 Gabia 네임서버를 자동 변경하지 않는다.

1. 첫 plan/apply에서 Hosted Zone과 ACM DNS 검증 레코드를 만든다.
2. Terraform 출력의 Route 53 네임서버를 확인한다.
3. 기존 Gabia DNS 레코드를 새 Hosted Zone에 빠짐없이 복제한다.
4. 복제 결과를 검증한 뒤 Gabia에서 권한 네임서버를 변경한다.
5. ACM 인증서가 `ISSUED`가 되면 `enable_https = true`로 바꾸고 다시 plan/apply한다.

`enable_https = false`인 동안 ALB의 80번 Listener는 Caddy Target으로 전달한다. 애플리케이션 공개 전에는 반드시 HTTPS를 활성화하고 HTTP→HTTPS 전환을 확인한다.

## 안전 원칙

- `terraform.tfvars`, `backend.hcl`, State, plan 파일과 자격 증명은 Git에 저장하지 않는다.
- EC2에는 SSH 키를 두지 않고 SSM Session Manager만 사용한다.
- 전체 서비스 단계에서는 ALB만 인터넷 인바운드를 받고 서비스 EC2는 ALB Security Group의 8080 요청만 받는다.
- 배치 EC2와 RDS는 인터넷 인바운드를 받지 않는다.
- RDS는 Private DB Subnet에 두고 `Publicly Accessible=false`를 강제한다.
- S3는 Public Access Block, Versioning, 암호화와 TLS 강제를 사용한다.
- State 버킷은 애플리케이션 IAM Role에 권한을 부여하지 않는다.
