# 인프라 질문 목록

상태: **Draft — 3 EC2 기준으로 재정렬**

세부 내용은 [백엔드·AWS 아키텍처 기준](backend-and-aws-architecture.md)을 따른다. 이전 2 EC2·ALB·로컬 Redis 전제의 질문은 최신 구조에서 다시 검토한다.

## P0 — 구현 전에 필요한 결정

| ID | 주제 | 질문 | 현재 상태 |
|---|---|---|---|
| INFRA-Q-001 | 공개 진입점 | ALB, API Gateway 또는 다른 Reverse Proxy 중 무엇을 사용할 것인가? | ALB 결정 |
| INFRA-Q-002 | Queue | SQS, Redis Streams 또는 다른 Broker 중 무엇을 사용할 것인가? | Redis Streams 결정 |
| INFRA-Q-003 | 전달 계약 | 재시도, DLQ, 순서, 중복, 멱등성과 전달 보장을 어떻게 정의할 것인가? | 미정 |
| INFRA-Q-004 | Redis | EC2 컨테이너, ElastiCache 또는 다른 Redis 호환 서비스 중 무엇을 사용할 것인가? | Redis 사용 확정, 운영 제품 후속 |
| INFRA-Q-005 | DB 권한 | 리포·App별 PostgreSQL Role과 테이블별 읽기·쓰기 권한을 어떻게 만들 것인가? | 미정 |
| INFRA-Q-006 | Flyway 통합 | 여러 리포의 Migration 번호 충돌을 어떻게 막고 어떤 순서로 적용할 것인가? | 미정 |
| INFRA-Q-007 | 네트워크 | Core·Trading·Compute EC2, RDS, Redis와 ALB를 어느 Subnet에 둘 것인가? | ALB는 2-AZ Public Subnet, EC2는 AZ A Public Application Subnet, RDS·Redis는 Private Data Subnet |
| INFRA-Q-008 | 보안 그룹 | 공개 진입, 내부 API, DB, Redis·Queue의 허용 주체와 포트를 어떻게 제한할 것인가? | 미정 |
| INFRA-Q-009 | 백업·복구 | RDS와 S3의 RPO·RTO, Backup 보존과 복원 시험 주기를 어떻게 정할 것인가? | 미정 |

## P1 — 처리량 측정 후 결정

| ID | 주제 | 질문 | 현재 상태 |
|---|---|---|---|
| INFRA-Q-010 | EC2 크기 | Core·Trading·Compute 각각의 CPU·메모리·디스크 크기는 얼마가 필요한가? | 부하 시험 필요 |
| INFRA-Q-011 | Trading 시간 | Trading EC2를 장 시작 전 언제 켜고 장 종료 후 언제 끌 것인가? | 미정 |
| INFRA-Q-012 | Gateway 확장 | Market Gateway 2개 운영 시 Active/Standby와 중복 제거를 어떻게 구현할 것인가? | 후속 |
| INFRA-Q-013 | Trading Shard | 봇 Shard와 종목별 시장 사건 Routing 기준은 무엇인가? | 후속 |
| INFRA-Q-014 | Compute Scheduler | Backtest와 Pipeline 우선순위, 동시 실행 수와 자원 격리를 어떻게 적용할 것인가? | 미정 |
| INFRA-Q-015 | Compute 분리 | 어떤 지표에서 Backtest와 Pipeline을 별도 EC2로 분리할 것인가? | 임계값 미정 |
| INFRA-Q-016 | Lambda 경계 | 작업 크기·시간·임시 공간 중 어떤 기준으로 Lambda와 Compute를 나눌 것인가? | 미정 |
| INFRA-Q-017 | Parquet | 압축 Codec, 물리 Partition 크기와 Compaction 주기는 무엇인가? | 미정 |

## P2 — 운영 정책

| ID | 주제 | 질문 | 현재 상태 |
|---|---|---|---|
| INFRA-Q-018 | 관측성 | 서비스별 로그·메트릭·Trace와 경보 기준을 어떻게 통합할 것인가? | 미정 |
| INFRA-Q-019 | 비용 | Free Plan·Credit 만료 후 월 비용 상한과 자동 중지 정책을 어떻게 둘 것인가? | 미정 |
| INFRA-Q-020 | Multi-AZ | 어떤 가용성 요구가 확인되면 단일 AZ 정책을 바꿀 것인가? | 후속 |
| INFRA-Q-021 | Production | 언제 Development와 격리된 Production VPC·RDS·S3·State를 생성할 것인가? | 후속 |
| INFRA-Q-022 | 시세 권리 | 라이브 원천 시세의 저장·재배포 범위가 공급 계약에 맞는가? | 법적 확인 필요 |

## 유지되는 결정

- 현재 환경은 Development 하나만 운영한다.
- 공식 관계형 상태는 RDS PostgreSQL 16에 저장한다.
- 대용량 불변 시장 데이터와 결과는 S3 Parquet로 저장한다.
- Redis는 공식 장기 정본으로 사용하지 않는다.
- DB Migration은 Flyway 하나로 통일하고 Alembic은 사용하지 않는다.
- EC2는 SSH 대신 Systems Manager로 관리한다.
- 배포 이미지는 ECR Digest로 고정하고 EC2에서 직접 `git pull`하지 않는다.
- Production이 필요해지면 Development와 별도 VPC, EC2, RDS, S3, 비밀과 Terraform State로 생성한다.
