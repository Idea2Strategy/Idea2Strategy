# Idea2Strategy 아키텍처 구조도 해설

상태: **Draft — 3 EC2 백엔드·AWS 기준**

구조도에는 서비스명, 실행 경계와 연결선만 표시한다. 배치 이유와 데이터 저장 방식은 이 문서에서 설명한다.

## 구조도

- [전체 서비스 아이콘 구조도](diagrams/idea2strategy-icon-architecture.svg)
- [AWS 전용 구조도](diagrams/idea2strategy-aws-architecture.svg)

두 구조도는 현재 AWS에 모두 생성된 리소스가 아니라 최신 **목표 구조**다. 현재 실제 구축 범위는 배치 EC2 한 대, Private RDS, Market Data S3, Terraform State S3와 관리 서비스까지다.

## 서버 배치

### Core EC2

`backend` 리포의 `backend-api`, `backend-batch`, `backend-worker`, `admin-mcp`를 Docker 컨테이너로 실행한다. 외부 요청은 Route 53과 ALB를 거쳐 Core로만 전달한다. Core의 보안 그룹은 ALB 보안 그룹에서 온 애플리케이션 요청만 허용하고 인터넷의 직접 인바운드는 허용하지 않는다.

### Trading EC2

`trading-engine` 리포의 `market-gateway`와 `trading-worker`를 실행한다. 전자는 시장 데이터를 정규화·검증해 Redis에 발행하고, 후자는 전략 평가, 주문 후보, 가상 체결, 포지션과 원장을 처리한다.

### Compute EC2

`backtest-api`, `backtest-worker`, `pipeline-worker`를 별도 컨테이너로 실행한다. 백테스트와 Pipeline은 초기에는 한 EC2를 공유하고 병목이 확인되면 서로 다른 Compute EC2로 분리한다.

### Lambda

짧고 간헐적인 기업행사 조사, Pipeline Trigger와 작은 검증을 실행한다. 10년치 재처리, 장시간 압축과 백테스트는 Compute EC2가 수행한다.

## 서버 배포 방식

1. GitHub Actions가 리포별 테스트와 Docker 이미지 빌드를 실행한다.
2. Amazon ECR에 이미지를 올리고 Digest를 고정한다.
3. Flyway 전용 Migration 단계를 한 번 실행한다.
4. Systems Manager Run Command가 대상 EC2의 Docker Compose를 갱신한다.

EC2에서 브랜치를 직접 `git pull`하지 않는다. SSH 포트를 공개하지 않으며 운영 접속도 SSM을 사용한다.

## 설정과 모니터링

일반 환경 설정은 Parameter Store, DB 비밀번호와 외부 API Key 같은 민감 정보는 Secrets Manager에 둔다. EC2 IAM Role에는 각 실행 App에 필요한 경로와 Secret만 읽을 수 있는 최소 권한을 부여한다.

ALB, Core·Trading·Compute EC2와 RDS의 로그·지표는 CloudWatch로 모은다. 초기에는 별도 Grafana 서버를 운영하지 않고 CloudWatch Logs, Metrics와 Alarm을 사용하며, 실제 운영 요구가 생기면 Grafana를 후속 추가한다.

## RDS 저장 방식

| 영역 | 주요 데이터 |
|---|---|
| Backend | 사용자, 전략, 봇 제어, 대회, 성과, 운영 상태 |
| Trading | 봇 실행, 평가, 주문, 체결, 포지션, 복식 원장 |
| Backtest | 작업 상태, 사용 입력, 결과 요약 |
| Market Data | 데이터셋, Manifest, 기업행사와 계보 |
| Storage | S3 Object Key, Version ID, 해시와 메타데이터 |
| Operations | 감사, Outbox와 운영 사건 |

서비스마다 최소 권한 PostgreSQL 계정을 사용한다. 대용량 시장 데이터와 백테스트 상세 본문은 RDS에 넣지 않고, RDS는 정확한 S3 객체를 찾는 Object·Manifest·Lineage를 저장한다.

## S3 저장 방식

### Market Data S3

과거·실시간 시장 데이터, RAW·ADJUSTED·파생 Parquet, 압축 객체와 데이터셋 Revision을 저장한다. Pipeline은 객체의 행 수, 기간과 해시를 검증한 뒤 PostgreSQL에 새 Manifest를 발행하며 기존 객체를 덮어쓰지 않는다.

### Results S3

백테스트 거래·포지션 상세, 계산·재현 데이터와 장기 성과 시계열을 저장한다. RDS 실행 레코드는 전략 버전, 시장 데이터 Manifest와 결과 객체의 Version·해시를 연결한다.

### Terraform State S3

Development Terraform State와 잠금 객체만 저장하며 애플리케이션 EC2 역할에는 접근 권한을 부여하지 않는다.

모든 버킷은 Public Access를 차단하고 암호화, Versioning과 TLS 강제를 적용한다.

## Redis와 작업 전달

Redis는 Private Data Subnet의 공유 서비스로 배치한다. 실시간 시장 사건과 최신값 Cache에 사용하지만 공식 정본은 아니며 PostgreSQL, S3와 공급자 데이터로부터 재구축할 수 있어야 한다.

Queue는 봇 제어 명령, 백테스트 작업과 도메인 사건을 전달한다. Queue 제품과 배치 방식은 아직 확정하지 않았으므로 특정 AWS 서비스 아이콘을 사용하지 않고 `Queue — technology and placement TBD`로 표시한다. Redis Streams는 실시간 시장 사건에만 사용한다.

## Subnet 배치

ALB는 서로 다른 두 Availability Zone의 Public Subnet에 연결한다. 초기 Core·Trading·Compute EC2는 비용과 운영 복잡도를 줄이기 위해 Availability Zone A의 Public Application Subnet에 둔다. 다만 Public Subnet에 있다는 사실이 인터넷 직접 접속을 허용한다는 뜻은 아니다. Core는 ALB에서 온 요청만 받고 Trading·Compute는 공개 인바운드를 받지 않으며, 운영 접속은 SSM을 사용한다.

RDS와 Redis는 Private Data Subnet에 둔다. RDS Subnet Group은 향후 장애 대응을 위해 두 Availability Zone의 Private DB Subnet을 포함하지만 현재 RDS 인스턴스는 Single-AZ로 운영한다.

## 한 문장 설명

Idea2Strategy는 ALB로 외부 요청을 받아 사용자 API와 운영 배치를 Core EC2, 실시간 전략 평가와 가상 체결을 Trading EC2, 백테스트와 대용량 데이터 처리를 Compute EC2로 분리한다. 공식 상태는 PostgreSQL, 대용량 불변 데이터는 S3, 명령·작업은 별도 Queue, 재구축 가능한 실시간 사건과 최신값은 Redis에 둔다.
