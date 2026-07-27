# DBML 재설계에 따른 제품 의미 변경 제안

- 상태: 격리된 제안 — 제품 정본 아님
- 작성일: 2026-07-23
- 기준 저장소: `Idea2Strategy/Idea2Strategy`
- 기준 브랜치: `develop`
- 기준 커밋: `6a53eb36a0cc9769f0220c8e3ea4a7d26036f34c`
기준 Stackcord fingerprint: `sha256:3cb632a0a1d1b75fd1e879be6da23c95d884a8250e4da3aba22f94cf5e59d7f2`
DBML 초안: `proposals/dbml-redesign/schema.draft.dbml`

## 문서 목적

이 문서는 DBML 재설계 대화에서 사용자가 선택한 내용 중 현재 `specs/`와 `contracts/`의 제품 의미를 바꾸거나 보완해야 하는 항목을 운영자 컴퓨터로 전달하기 위한 제안서다.

- 이 문서는 제품 정본을 대체하지 않는다.
- 이 문서의 내용은 승인·통합·출시 가능한 변경으로 표현하지 않는다.
- 운영자 컴퓨터에서 실제 저장소와 provider 상태를 다시 확인한 뒤 영향받는 정본 문서를 수정한다.
- 정본 수정 전 `stackcord governance check --json`을 실행하고 정확한 저장소, HEAD와 보호 fingerprint에 대해 `user:kcrmin`의 fresh provider 승인이 확인돼야 한다.
- Git 사용자 이름과 이메일은 제품 권한 증명이 아니다.

세부 데이터 모델 결정과 DBML 반영 계획은 `db/data-model-decisions.md`가 소유한다.

## 제안된 제품 의미

### 1. 봇·파티션·전략 계층

제안 구조는 `봇 1 ─ N 파티션 1 ─ N 전략`이다.

- 전략은 정확히 하나의 파티션에 종속된다.
- 다른 파티션이 같은 전략 행이나 전략 버전을 공유하지 않는다.
- 봇 또는 파티션을 복사할 때 전략과 블록 문서를 새 식별자로 깊은 복사한다.
- 원본 런타임 상태, 현금, 주문, 체결, 포지션, 원장과 성과는 복사하지 않는다.

현재 정본과의 차이:

- 현재 정본은 계정 소유의 독립 전략 작업본·출시 버전·재사용 흐름을 전제로 한다.
- 제안은 전략을 파티션 종속 구성으로 바꾸므로 전략 라이브러리, 출시 여정, 복사와 자동 백테스트 의미를 함께 재검토해야 한다.

### 2. 종목 선택 책임

- 파티션은 종목이나 종목군을 직접 소유하지 않고 예산 상한, 위험 정책과 내부 전략 실행 범위를 소유한다.
- 각 전략이 자신의 매매 대상 종목 또는 종목군을 선택한다.
- 같은 파티션 또는 다른 파티션의 여러 전략이 같은 종목을 선택할 수 있다.

### 3. 예산 계층

- 봇 초기 자본을 기준으로 파티션별 백분율 상한을 둔다.
- 파티션 상한 합계는 100% 이하이며 미배정 자금은 봇 현금으로 남는다.
- Basic은 파티션 예산을 내부 전략에 균등 배분한다.
- Pro는 각 전략에 부모 파티션 예산 대비 백분율 상한을 두며 합계는 100% 이하이다.
- 사용하지 않은 예산을 형제 파티션·전략이 빌려 쓰지 않는다.
- 보유 금액과 미체결 주문 예약액을 모두 단계별 상한 사용량에 포함한다.

### 4. 시장가·Buying Power

- 시장가 주문을 IOC 시장성 지정가로 변환하지 않는다.
- 랜덤 슬리피지를 사용하지 않는다.
- 매수에는 `+0.05%`, 매도에는 `-0.05%`의 고정 슬리피지를 사용한다.
- 별도 Buying Power 완충액은 미체결 자금 예약에만 사용하고 체결가격, 손익과 성과에는 반영하지 않는다.
- 완충액은 플랫폼이 관리하는 버전 고정 `buffer_bps`를 기준 주문금액에 적용해 계산한다.
- 체결 시 최신 유효 가격에 고정 슬리피지와 수수료를 적용해 다시 검사한다.
- 예약이 남으면 차액을 해제하고 부족하면 체결 전에 수량을 축소하거나 주문을 거절한다.

추가 근거가 필요한 항목:

- 정확한 `buffer_bps`
- 호가 기준면
- 가격·수수료·수량 정밀도와 반올림

### 5. 동일 종목 주문 충돌

- 같은 평가 주기의 전략들은 동일한 입력 스냅샷을 사용한다.
- 전략별 원래 주문 의도와 판단 근거는 보존한다.
- 봇·종목 단위로 같은 방향 의도는 합산하고 반대 방향은 결정론적으로 상계한다.
- 상계 후 실제 체결분만 승인된 의도에 따라 전략·파티션으로 귀속한다.
- 상계는 예산, 현금, 포지션 lot 또는 손익을 형제 범위로 이전하지 않는다.

### 6. 편집과 실행 잠금

- 별도의 봇 구성·파티션·전략 버전 테이블을 만들지 않는다.
- 편집 중에는 현재 행과 전략 JSONB 문서를 직접 수정한다.
- 실행 시 봇 전체 계층을 한 트랜잭션에서 검증하고 같은 행을 잠근다.
- 잠긴 실행 의미 열과 자식 행은 수정·삭제할 수 없다.
- 변경하려면 전체 계층을 깊은 복사해 새 봇을 만든다.

현재 정본과의 차이:

- 현재 정본은 별도의 불변 전략 출시 버전을 요구한다.
- 제안은 실행 시 현재 구성 행을 잠그므로 출시·보관·자동 백테스트와 UI의 버전 표시 의미를 다시 정의해야 한다.

### 7. 공식 자동 백테스트

- 공식 자동 백테스트는 개별 전략이 아니라 잠긴 봇 전체 구성을 입력으로 한다.
- 잠긴 봇마다 최대 한 번 생성한다.
- 모든 파티션, 전략, 예산, 동일 종목 상계, Buying Power, 슬리피지, 수수료와 회계 규칙을 함께 재현한다.
- 대용량 거래·재생 원장·포지션·계산 시계열은 S3 불변 객체에 두고 PostgreSQL에는 실행 상태, 잠긴 입력, 요약과 무결성 매니페스트를 둔다.
- 라이브 봇의 현금·주문·원장과 백테스트 상태를 공유하지 않는다.

현재 정본과의 차이:

- 현재 정본은 출시 전략 버전당 최대 한 번의 공식 자동 백테스트를 요구한다.
- 자동 백테스트 UI, 출시 실패, 백테스트 불가, 보관과 조회 관계를 봇 전체 구성 기준으로 다시 작성해야 한다.

### 8. 백테스트와 봇 실행의 독립성

- 구성 잠금이 성공하면 자동 백테스트를 큐에 넣고 봇은 백테스트 완료를 기다리지 않고 예정 시각에 실행한다.
- 구성 검증, 자격, 라이브 데이터와 실행 인프라 준비 실패는 봇 시작을 차단한다.
- 백테스트 지연·실패·불가는 사용자에게 표시하지만 봇 상태나 라이브 공식 원장을 바꾸지 않는다.
- 봇 중단도 이미 시작한 백테스트를 취소하거나 결과를 숨기지 않는다.

## 정본 영향 후보

운영자 컴퓨터에서 다음 문서의 실제 최신 상태와 의미 중복을 다시 확인한다.

- `specs/product/summary.md`
- `specs/product/capabilities/capability.strategy.basic.md`
- `specs/product/capabilities/capability.strategy.pro.md`
- `specs/product/capabilities/capability.backtest.automatic.md`
- `specs/product/capabilities/capability.bot.server-execution.md`
- `specs/product/journeys/journey.strategy.author.md`
- `specs/product/journeys/journey.bot.operate.md`
- `specs/scenarios/scenario.strategy.release.md`
- `specs/scenarios/scenario.bot.evaluate.md`
- `specs/policies/policy.strategy.immutable-release.md`
- `specs/product/decisions/decision.data.hybrid.md`
- `specs/ui/ui.strategy.authoring.md`
- `specs/ui/ui.backtest.results.md`
- `specs/ui/ui.bot.operations.md`
- `contracts/business/index.md`
- `contracts/behaviors/index.md`
- `contracts/data/index.md`

## 운영자 컴퓨터 적용 전 체크리스트

1. 저장소·브랜치·HEAD·dirty 상태를 다시 확인한다.
2. `stackcord status --json`으로 실제 정본과 영향 관계를 갱신한다.
3. `stackcord governance check --json`에서 정확한 HEAD와 보호 fingerprint에 대한 `user:kcrmin` 승인을 확인한다.
4. 이 제안과 최신 `db/data-model-decisions.md`, `db/schema.dbml`의 차이를 함께 검토한다.
5. 제품 의미를 먼저 정본 문서에 반영하고 계약·실패 동작·UI 의무를 같은 변경에서 맞춘다.
6. DBML과 마이그레이션은 승인된 정본을 참조하도록 조정한다.
7. 변경된 불변 조건에 대한 실패 우선 테스트와 롤백 계획을 준비한다.
8. fresh exact-commit 승인을 다시 확인한 뒤에만 통합·릴리스 상태로 전환한다.
