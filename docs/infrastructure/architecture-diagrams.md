# Idea2Strategy 아키텍처 구조도 해설

상태: **Draft — 3 EC2 백엔드·AWS 기준**

구조도에는 서비스명, 실행 경계와 연결선만 표시한다. 배치 이유와 데이터 저장 방식은 이 문서에서 설명한다.

## 구조도

- [전체 서비스 아이콘 구조도](diagrams/idea2strategy-icon-architecture.svg)
- [AWS 전용 구조도](diagrams/idea2strategy-aws-architecture.svg)

두 구조도는 현재 AWS에 모두 생성된 리소스가 아니라 최신 **목표 구조**다. 현재 실제 구축 범위는 배치 EC2 한 대, Private RDS, Market Data S3, Terraform State S3와 관리 서비스까지다.

## 서버 배치

### Core EC2

`backend` 리포의 `backend-api`, `backend-batch`, `backend-worker`, `admin-mcp`를 Docker 컨테이너로 실행한다. 외부 UI와 운영자 도구가 직접 접근할 수 있는 서버 실행 경계는 Core뿐이며 공개 진입점 제품은 아직 결정하지 않았다.

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

## Redis와 Queue

Redis는 실시간 시장 사건과 최신값 Cache에 사용하지만 공식 정본은 아니다. Redis 운영 제품은 아직 미정이다.

Queue는 봇 제어 명령, 백테스트 작업과 도메인 사건을 전달한다. 운영은 AWS SQS, 로컬은 LocalStack SQS를 사용한다. Standard Queue가 기본이며 순서 보장이 계약인 경로만 FIFO를 사용하고, consumer는 중복 전달에 멱등하게 동작한다. Redis Streams는 실시간 시장 사건에만 사용한다.

## 한 문장 설명

Idea2Strategy는 사용자 API와 운영 배치를 Core EC2, 실시간 전략 평가와 가상 체결을 Trading EC2, 백테스트와 대용량 데이터 처리를 Compute EC2로 분리하고, 공식 상태는 PostgreSQL, 대용량 불변 데이터는 S3, 재구축 가능한 실시간 전달과 최신값은 Redis에 두는 구조다.
