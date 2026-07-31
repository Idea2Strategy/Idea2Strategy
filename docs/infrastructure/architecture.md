# Idea2Strategy 인프라 아키텍처

상태: **Draft — 최신 백엔드·AWS 배치 기준 반영**

이 문서는 인프라 전체 구조를 빠르게 이해하기 위한 요약이다. 세부 실행 App, 리포지토리 구조, 통신과 DB 접근 기준은 [백엔드·AWS 아키텍처 기준](backend-and-aws-architecture.md)을 따른다. 제품·데이터 의미의 정본은 `specs/`, `docs/product-discovery.md`, `db/schema.dbml`이며 이 문서는 배포 완료 상태를 뜻하지 않는다.

최신 구조도는 다음 두 파일에서 확인한다.

- [전체 서비스 아이콘 구조도](diagrams/idea2strategy-icon-architecture.svg)
- [AWS 전용 구조도](diagrams/idea2strategy-aws-architecture.svg)
- [구조도 해설](architecture-diagrams.md)
- [아이콘 출처](diagrams/logo-sources.md)

## 1. 현재 실제 구축 상태

현재 AWS에는 완성된 서비스가 아니라 과거 시장 데이터 적재를 위한 Development 기반만 있다.

- 서울 리전 Development VPC
- Public Subnet 두 개와 Private DB Subnet 두 개
- 외부 인바운드와 SSH Key Pair가 없는 배치 EC2 한 대
- Private RDS PostgreSQL 16.13 Single-AZ
- Private Market Data S3와 별도 Terraform State S3
- Systems Manager, Parameter Store, Secrets Manager, CloudWatch
- 위 리소스를 다시 만들 수 있는 Terraform 코드

다음 목표 구조의 Core·Trading·Compute EC2, Lambda, Queue, Redis 서비스와 공개 진입점은 아직 모두 배포된 상태가 아니다.

## 2. 최신 목표 구조

현재 목표 배치는 단일 Availability Zone과 EC2 세 대를 전제로 한다.

| 실행 경계 | 실행 단위 | 주 책임 |
|---|---|---|
| Core EC2 | `backend-api`, `backend-batch`, `backend-worker`, `admin-mcp` | 사용자 API, 운영 배치, Outbox·알림, 관리자 작업 |
| Trading EC2 | `market-gateway`, `trading-worker` | 실시간 시장 데이터 수신, 전략 평가, 주문·가상 체결·원장 |
| Compute EC2 | `backtest-api`, `backtest-worker`, `pipeline-worker` | 백테스트, 대용량 시장 데이터 처리, Parquet·Manifest 발행 |
| Lambda | 기업행사 조사, Pipeline Trigger, 경량 검증 | 짧고 간헐적인 조사·제어 작업 |

브라우저는 전략 평가, 주문, 가상 체결, 백테스트와 배치를 실행하지 않는다. UI는 `backend-api`와 허용된 관리자 진입점만 호출하고 실제 업무 실행은 서버가 담당한다.

### 리포지토리 경계

| 리포지토리 | 기술 | 배포 대상 |
|---|---|---|
| `backend` | Java, Spring Boot, Spring Batch | Core EC2 |
| `trading-engine` | Java, Spring Boot | Trading EC2 |
| `backtest-engine` | Python, FastAPI, Polars, PyArrow | Compute EC2 |
| `data-pipeline` | Python, Polars, PyArrow, Lambda Handler | Compute EC2와 Lambda |

서로 다른 Git 리포는 JPA Entity나 Java 도메인 코드를 직접 공유하지 않는다. API, 이벤트, 전략 문서, DBML과 Flyway SQL을 계약 경계로 사용한다.

## 3. 주요 통신 흐름

### 사용자 요청

```text
Web UI → 공개 진입점(제품 미정) → backend-api → PostgreSQL 또는 작업 Queue
```

공개 진입점을 ALB, API Gateway 또는 다른 Reverse Proxy 중 무엇으로 구현할지는 아직 결정하지 않았다.

### 실시간 트레이딩

```text
Market Data Provider → market-gateway → Redis Streams·Cache
  → trading-worker → PostgreSQL 주문·체결·포지션·원장
```

Market Gateway는 처음 한 개로 시작한다. 이후 부하와 장애 요구가 확인되면 Active/Standby 또는 중복 제거 계약과 함께 두 개 운영을 검토한다.

### 백테스트

```text
backend-api → 작업 Queue → backtest-worker
  → PostgreSQL 실행 상태·요약 + S3 상세 Parquet
```

FastAPI 기반 `backtest-api`는 내부 작업 접수·상태·진단 경계다. CPU 집약 계산은 HTTP 요청이나 FastAPI `BackgroundTasks`가 아니라 별도 Worker가 실행한다.

### 시장 데이터 Pipeline

```text
실시간·과거 시장 데이터 → pipeline-worker → 검증·조정·집계·압축
  → S3 새 Parquet 객체 → PostgreSQL Object·Manifest·Lineage
```

Pipeline은 기존 객체를 덮어쓰지 않는다. 객체 검증을 완료한 후 새 Manifest를 발행하며 기존 백테스트가 잠근 Manifest를 몰래 교체하지 않는다.

### 기업행사 조사

```text
EventBridge Scheduler → Lambda → 기업행사 공식 정보원·AI 조사
  → 관리자 검토 후보 → 결정론적 공식 반영
```

AI 조사는 후보와 공식 근거를 제출할 뿐 adjusted 데이터나 공식 원장을 직접 변경하지 않는다.

## 4. 데이터 저장 원칙

### RDS PostgreSQL

PostgreSQL은 사용자·전략·봇, 주문·체결·포지션·원장, 백테스트 상태·요약, 대회·성과, S3 Object·Manifest·Lineage와 Transactional Outbox를 저장한다.

Java 서비스는 CQRS-lite를 적용한다. Command는 주로 JPA, Query는 jOOQ를 사용한다. Python 서비스는 자신이 소유한 일부 스키마에 SQLAlchemy Core로 접근한다. 모든 Migration은 Flyway 하나로 관리하고 Alembic은 사용하지 않는다.

### S3

S3에는 과거·실시간 시장 데이터 Parquet, RAW·ADJUSTED·파생 데이터, 백테스트 상세 결과, 계산·재현 데이터와 Terraform State를 저장한다.

업무 데이터는 Market Data와 Results 저장 경계로 나누고 Terraform State는 애플리케이션 역할이 접근할 수 없는 별도 버킷으로 유지한다. 기존 세 버킷 경계는 최신 기준의 “S3 1개 이상” 조건과 충돌하지 않으므로 유지한다.

### Redis

Redis는 실시간 시장 사건 전달과 종목별 최신값 Cache에 사용한다. 공식 장기 정본으로 사용하지 않으며 PostgreSQL, S3와 공급자 데이터로부터 재구축할 수 있어야 한다.

Redis를 EC2 컨테이너, ElastiCache 또는 다른 Redis 호환 서비스 중 무엇으로 운영할지는 아직 결정하지 않았다.

### Queue

Backend의 봇 제어 명령, 백테스트 작업과 일반 도메인 사건은 운영 AWS SQS, 로컬 LocalStack SQS로 전달한다. SQS Standard를 기본으로 사용하고 순서 보장이 실제 계약인 경로만 FIFO를 사용한다. at-least-once 전달을 전제로 consumer 멱등성을 강제하며, 재시도 횟수·visibility timeout·DLQ redrive 값은 부하·장애 시험으로 확정한다. Redis Streams는 실시간 시장 사건에만 사용하고 durable command/job queue로 사용하지 않는다.

## 5. 배포와 운영

```text
GitHub → GitHub Actions → 테스트·Docker 이미지 빌드 → Amazon ECR
  → AWS Systems Manager → EC2별 Docker Compose 갱신
```

- EC2에서 저장소를 직접 `git pull`하지 않는다.
- 배포할 이미지 Digest를 고정한다.
- EC2 SSH 포트를 공개하지 않고 운영 접속과 배포는 SSM을 사용한다.
- Flyway는 배포 Pipeline의 전용 Migration 단계에서 한 번 실행한다.
- EC2 로컬 디스크를 공식 영속 데이터의 기준으로 사용하지 않는다.

## 6. 확장 방향

1. Market Gateway 이중화와 중복 제거 방식 결정
2. Trading Worker 봇 Shard와 시장 사건 Routing 결정
3. Backtest·Pipeline Worker 동시 작업 수 확대
4. Compute 병목 시 Backtest와 Pipeline을 별도 EC2로 분리
5. 사용자 API 부하 증가 시 `backend-api`만 별도 확장
6. 실제 가용성 요구가 생길 때 Multi-AZ 재검토

현재 단일 AZ 정책에서는 Multi-AZ 장애 복구를 보장한다고 표현하지 않는다.

## 7. 아직 확정하지 않은 항목

- EC2 인스턴스 타입과 CPU·메모리
- 공개 진입점 제품
- SQS 경로별 재시도·DLQ·FIFO 적용 계약
- Redis 운영 제품
- Trading EC2 시작·종료 시간
- 백테스트·Pipeline 동시 실행 수와 자원 한도
- Lambda와 Compute Worker 사이의 작업 크기 기준
- Parquet 최종 압축 Codec과 파티션 크기
- 실시간 원천 시세 저장·재배포 범위
- 서비스별 PostgreSQL Role과 테이블 권한
- 관측성, 장애 알림, Backup과 복구 목표

현재 질문과 결정 순서는 [인프라 질문 목록](questions.md)에서 관리한다.
