# 인프라 결정 기록

상태: **작업 중(Working Draft)**

인프라 구조, 공급자, 데이터 저장, 보안, 배포 또는 운영 비용에 장기 영향을 주는 선택은 Architecture Decision Record(ADR)로 남긴다.

## 결정 목록

| ID | 상태 | 제목 |
|---|---|---|
| [ADR-001](ADR-001-mvp-availability-and-data-protection.md) | Accepted | MVP 가용성과 데이터 보호 수준 |
| [ADR-002](ADR-002-managed-postgresql-and-flyway-lifecycle.md) | Proposed | 관리형 PostgreSQL과 Flyway 스키마 수명주기 |
| [ADR-003](ADR-003-aws-development-single-ec2.md) | Proposed | 개인 AWS의 단일 EC2 Development 환경 |
| [ADR-004](ADR-004-aws-development-two-ec2-role-separation.md) | Proposed | Development EC2 2대 역할 분리 |
| [ADR-005](ADR-005-spring-multi-module-shared-rds-cqrs-lite.md) | Proposed | Spring 실행 모듈 분리와 공용 RDS·CQRS-lite |
| [ADR-006](ADR-006-market-data-runtime-and-redis-placement.md) | Proposed | 시장 데이터 실행 경계와 Redis 배치 |
| [ADR-007](ADR-007-leaderboard-and-live-performance-projection.md) | Proposed | 리더보드와 개인 실시간 수익률 투영 |
| [ADR-008](ADR-008-full-supported-universe-sip-subscription.md) | Proposed | 지원 종목 전체 SIP 공용 구독 |
| [ADR-009](ADR-009-public-compute-private-rds-network.md) | Proposed | Public ALB·EC2와 Private RDS 네트워크 |
| [ADR-010](ADR-010-same-account-isolated-environments.md) | Proposed | 같은 AWS 계정의 환경 격리와 S3 저장 경계 |
| [ADR-011](ADR-011-three-s3-bucket-boundaries-per-environment.md) | Superseded | ADR-010에 통합된 환경별 S3 버킷 3개 경계 |
| [ADR-012](ADR-012-three-ec2-backend-aws-baseline.md) | Proposed | Core·Trading·Compute 3 EC2 백엔드·AWS 기준 |

## 파일 규칙

- 파일명: `ADR-NNN-short-title.md`
- 새 문서는 [template.md](template.md)를 복사해 작성한다.
- 번호는 기존 최대 번호 다음 값을 사용한다.
- 처음 상태는 `Proposed`이며 팀 합의 후에만 `Accepted`로 바꾼다.
- 기존 결정을 바꿀 때 원문을 지우지 않고 새 ADR에서 `Supersedes`로 연결한다.

## 승인 기준

ADR에는 최소한 다음 내용이 있어야 한다.

- 해결하려는 질문과 정량 요구
- 비교한 선택지와 제외 근거
- 보안, 개인정보, 데이터 권리 영향
- 비용과 운영 책임
- 장애·복구·관측 방법
- 마이그레이션과 롤백 방법
- 승인자와 승인일

보호된 `specs/**`, `contracts/**`, DBML의 의미를 바꾸는 결정은 ADR 승인만으로 완료되지 않는다. 해당 정본 변경에 필요한 거버넌스 절차를 별도로 통과해야 한다.
