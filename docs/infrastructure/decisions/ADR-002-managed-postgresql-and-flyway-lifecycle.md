# ADR-002: 관리형 PostgreSQL과 Flyway 스키마 수명주기

- 상태: Proposed
- 작성일: 2026-07-29
- 결정자: 인프라 담당자
- 관련 질문: INFRA-Q-003, INFRA-Q-007, INFRA-Q-010, INFRA-Q-011
- 관련 정본 ID: decision.data.hybrid, quality.auditability, quality.reproducibility
- Supersedes:

## 맥락

관계형 시스템 오브 레코드는 계정, 전략 버전, 봇 설정, 공식 주문·체결·원장과 객체 무결성 메타데이터를 보유한다. 핵심 영속 데이터의 목표 RPO는 최대 15분이며, MVP는 무중단보다 단순한 운영과 실제 복원 가능성을 우선한다.

스키마 개발은 반복되지만 Development와 Production의 변경 이력은 재현 가능해야 한다. 신규 Production RDS는 검증된 운영 기준 스키마에서 시작하고, 이후에는 Development에서 먼저 검증한 동일 변경만 순차 적용해야 한다.

## 선택지

### 선택지 A: EC2 내부 PostgreSQL 컨테이너

- 장점: 초기 리소스 수와 직접 비용이 적다.
- 단점: 애플리케이션 장애·디스크 장애와 DB 장애가 같은 호스트에 결합된다.
- 비용: 관리형 DB 비용은 없지만 백업·복원·패치 운영 시간이 필요하다.
- 운영·보안·복구 영향: RPO와 복원 시험을 직접 구현하고 검증해야 한다.

### 선택지 B: Production 직전에 RDS로 이전

- 장점: 초기 Development 비용을 줄일 수 있다.
- 단점: 운영 직전에 엔진 설정·네트워크·백업·마이그레이션 차이가 한꺼번에 발생한다.
- 비용: 초기 비용은 낮지만 이관과 검증 비용이 뒤로 밀린다.
- 운영·보안·복구 영향: Development 검증 결과가 Production RDS 환경을 충분히 대표하지 못할 수 있다.

### 선택지 C: Development부터 Amazon RDS for PostgreSQL 사용

- 장점: 운영 후보와 같은 관리형 엔진에서 백업·복원·연결·마이그레이션을 일찍 검증할 수 있다.
- 단점: 개발 초기부터 RDS 비용과 네트워크 구성이 필요하다.
- 비용: 최소 사양으로 시작하고 실제 사용량을 측정해 확장한다.
- 운영·보안·복구 영향: Public access를 차단하고 저장 암호화, 자동 백업과 시점 복구를 적용한다.

## 결정

인프라 담당자는 선택지 C를 선택했다. 팀 합의와 세부 사양 검증 전까지 이 ADR은 `Proposed`로 유지한다.

- Development의 관계형 시스템 오브 레코드는 Amazon RDS for PostgreSQL을 사용한다.
- 로컬 개발은 호환 PostgreSQL 컨테이너를 사용할 수 있지만 같은 Flyway 이력과 설정 계약을 검증한다.
- Flyway Versioned Migration은 Development RDS에 먼저 적용하고 검증한 뒤 같은 불변 아티팩트를 Production RDS에 순차 적용한다.
- 공유 환경에 성공 적용된 Versioned Migration은 수정·삭제·재정렬하지 않는다.
- 최초 Production RDS는 검토된 `B` Baseline Migration으로 생성한다. 기존 DB를 표시하는 Flyway `baseline` 명령은 신규 Production 생성에 사용하지 않는다.
- 기존 `V` 이력은 유지하며 신규 Production은 승인된 Baseline보다 높은 `V` 마이그레이션만 적용한다.
- Development 배포에서는 루트 GitHub Actions가 SSM Run Command를 통해 모의투자 서비스 EC2의 Flyway 전용 일회성 작업을 정확히 한 번 실행한다.
- Flyway 작업 성공 후에만 Spring 애플리케이션을 배포한다. 실패 시 애플리케이션 배포를 중단하고 스키마 자동 롤백은 시도하지 않는다.
- Spring 애플리케이션 시작 시 자동 Migration은 비활성화하고, 런타임 계정에는 DDL 권한을 부여하지 않는다.

## 근거

- 승인된 하이브리드 데이터 결정은 관계형 정본과 외부 불변 객체 저장소의 경계를 요구한다.
- ADR-001은 핵심 영속 데이터 RPO 최대 15분과 실제 복원 시험을 요구한다.
- Flyway Baseline Migration은 신규 환경을 누적 스키마에서 시작하게 하면서 기존 Versioned Migration 이력을 유지할 수 있다.
- 인프라 질의응답에서 Development부터 RDS를 사용하는 선택지 C와 검토된 `B` Baseline Migration 방식이 선택되었다.

## 결과와 영향

- 기대 효과: Development에서 Production 후보 DB 동작, Flyway 이력, 백업과 복원을 조기에 검증한다.
- 감수하는 단점: RDS 고정 비용과 VPC·보안 그룹·자격 증명 관리가 개발 초기부터 필요하다.
- 구현·마이그레이션 순서: 정본 DBML 승인 → Flyway 이력 작성 → Development 검증 → 빈 PostgreSQL에서 Baseline 검증 → Production RDS 생성 → Baseline 이후 마이그레이션 순차 적용.
- 관측 및 검증: Flyway `validate`, 적용 전·후 버전, checksum, 소스 커밋, 통합 테스트와 실제 RDS 복원 시험을 기록한다.
- 롤백: 스키마 변경은 기본적으로 새 전진 수정 마이그레이션으로 처리한다. 데이터 손상 또는 복구가 필요한 실패는 적용 전 백업과 RDS 시점 복구 절차를 사용하며 정확한 기준은 후속 결정으로 정한다.

## 후속 작업

- [ ] PostgreSQL 메이저 버전, RDS 클래스, 스토리지와 Single-AZ·Multi-AZ 결정
- [ ] 백업 보존 기간, 삭제 방지, 최종 스냅샷과 복원 시험 주기 결정
- [x] Development Flyway 실행 주체와 애플리케이션 배포 게이트 결정
- [ ] Production Flyway 실행 위치, 자격 증명과 승인 절차 결정
- [ ] 애플리케이션과 스키마의 선행·후행 호환 규칙 및 실패 기준 결정
- [ ] 정본 DBML 승인 전 격리 제안 스키마를 RDS에 적용하지 않는 CI 검증 추가
