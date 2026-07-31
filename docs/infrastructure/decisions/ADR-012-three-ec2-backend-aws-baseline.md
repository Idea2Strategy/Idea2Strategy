# ADR-012: Core·Trading·Compute 3 EC2 백엔드·AWS 기준

상태: **Proposed**

날짜: 2026-07-30

## 배경

기존 제안은 서비스·모의투자 EC2와 배치·백테스트 EC2 두 대를 사용하고, 하나의 Spring 백엔드를 세 실행 모듈로 나누는 구조였다. 이후 백엔드 책임과 언어 경계가 구체화되면서 사용자 API·운영 배치, 실시간 거래 처리, CPU 집약 백테스트·시장 데이터 Pipeline을 서로 다른 장애·자원 경계로 분리할 필요가 생겼다.

## 제안

- Core EC2: `backend-api`, `backend-batch`, `backend-worker`, `admin-mcp`
- Trading EC2: `market-gateway`, `trading-worker`
- Compute EC2: `backtest-api`, `backtest-worker`, `pipeline-worker`
- `backend`와 `trading-engine`: 서로 다른 Java·Spring Boot Git 리포
- `backtest-engine`과 `data-pipeline`: 서로 다른 Python Git 리포
- PostgreSQL: 공식 상태·요약·Manifest
- S3: 대용량 불변 객체
- Redis: 실시간 사건·최신값
- Public Ingress: 두 Availability Zone의 Public Subnet을 사용하는 ALB
- EC2 Subnet: 초기에는 Availability Zone A의 Public Application Subnet
- Queue: Redis와 분리한다. 제품과 배치 방식은 후속 결정으로 남긴다.
- Flyway: 유일한 DB Migration 도구

## 미확정 항목

이 제안은 다음 세부 구현을 확정하지 않는다.

- ElastiCache, EC2 컨테이너 또는 다른 Redis 호환 운영 방식
- Queue 제품·배치 방식과 재시도·DLQ·순서·멱등 계약
- Redis Stream Key, 보존 시간, Consumer Group과 장애 복구 방식
- EC2 사양과 Compute 동시 실행 수
- 애플리케이션 EC2의 Multi-AZ 확장 시점

## 기존 ADR과의 관계

승인되면 ADR-004의 2 EC2 배치, ADR-005의 세 Spring 실행 App 배치, ADR-006의 실시간 Worker·Redis 동거 배치, ADR-009의 ALB 확정과 두 EC2 네트워크 배치를 대체한다.

ADR-001·002의 데이터 보호와 Flyway, ADR-007·008의 Projection과 SIP 구독, ADR-010·011의 환경·S3 경계는 유지한다.

## 영향

- EC2가 목표 기준 두 대에서 세 대로 늘어난다.
- 실시간 거래, Core API와 Compute 자원 고갈의 영향 범위가 분리된다.
- Git 리포, Docker 이미지, IAM Role, DB Role과 배포 대상이 증가한다.
- ALB가 공개 HTTPS 진입점이 되고 Core에만 요청을 전달한다.
- Queue와 Redis를 분리하여 명령·작업과 실시간 사건·Cache의 운영 계약을 독립적으로 관리한다.
- Redis 운영 제품과 Queue 전달 보장 세부 계약은 별도로 결정해야 한다.
- 현재 Terraform Market Data Bootstrap은 유지하고 새 목표 구조는 후속 단계에서 구현한다.

## 검증 조건

- Core 장애가 Trading 프로세스를 직접 종료시키지 않는다.
- Compute 장시간 작업이 Trading 지연과 Core 응답 시간을 직접 잠식하지 않는다.
- UI가 Trading·Backtest·Pipeline Worker를 직접 호출할 수 없다.
- 각 서비스 DB 계정이 다른 서비스 소유 테이블을 임의로 변경할 수 없다.
- S3 객체 검증 전에는 새 Manifest가 발행되지 않는다.
- Redis 운영 제품처럼 아직 미확정인 항목을 Terraform이나 다이어그램에서 확정된 것처럼 표현하지 않는다.
