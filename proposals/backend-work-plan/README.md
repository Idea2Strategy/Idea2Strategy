# Backend work plan example

> 검토용 제안이다. 아직 정식 작업 정의, 담당자 배정, 작업 예약 또는 구현 시작으로 간주하지 않는다.

## 1. 나누는 기준

- 사람별로 거대한 도메인을 영구 배정하지 않는다.
- 사용자가 확인할 수 있는 결과 하나를 만드는 수직 작업을 기본 단위로 삼는다.
- 한 수직 작업이 지나치게 크면 도메인 기능 단위로 나누되, 제공자와 소비자의 계약 및 병합 순서를 함께 적는다.
- 모든 구현 작업은 최초 실패 테스트, 성공 조건, 실패 조건, 영향받는 DB 엔티티, 저장소, 선행 작업과 검증 증거를 가진다.
- 공통 기능은 한 명이 소유하거나 먼저 인터페이스를 고정한 뒤 여러 구현 작업이 소비한다.
- JPA는 Command의 일반적인 상태 변경에, jOOQ는 Query와 명시적인 원자적 SQL이 필요한 일부 Command에 사용한다.

## 2. 실행 프로그램 한 줄 설명

| 실행 프로그램 | 한 줄 책임 |
|---|---|
| `backend-api` | 사용자와 운영자의 동기식 명령 및 조회 API를 제공한다. |
| `backend-batch` | 방 일정 전환과 기한 만료처럼 정해진 시각의 일괄 업무를 실행한다. |
| `backend-worker` | Outbox, 알림과 비동기 후속 업무를 큐에서 처리한다. |
| `admin-mcp` | 권한 있는 운영 도구에 제한된 관리자 기능을 제공한다. |
| `market-gateway` | 외부 실시간 시세를 정규화하고 내부 시장 이벤트로 발행한다. |
| `trading-worker` | 잠긴 전략을 평가하고 예산·위험 검사 후 가상 주문·체결·원장을 기록한다. |
| `backtest-api` | 백테스트 작업 상태와 결과 조회를 제공한다. |
| `backtest-worker` | 잠긴 전략과 데이터 Manifest로 재현 가능한 백테스트를 계산한다. |
| `pipeline-worker` | 시장 데이터를 검증·조정·Parquet 압축하고 Manifest를 발행한다. |

## 3. 작업 그래프 예시

```text
W00 DBML·테이블 소유권 확정
 ├─ W01 저장소 실행 골격·공통 검증
 │   ├─ W02 인증 주체·권한 경계
 │   ├─ W03 전략 임시 저장·검증
 │   │   └─ W04A 전략 출시·백테스트 요청 계약
 │   │       └─ W04B 전략 출시·불변 스냅샷·요청 발행
 │   │           ├─ W05 자동 백테스트 실행
 │   │           │   └─ W06 백테스트 결과 조회
 │   │           └─ W07 봇 생성·출시
 │   │               └─ W09 봇 평가·주문·체결·원장
 │   │                   └─ W10 봇 중단·정산
 │   ├─ W08 실시간 시세 수신·시장 이벤트
 │   │   └─ W09 봇 평가·주문·체결·원장
 │   └─ W11 방 참여·평가 구간·성과 확정
 └─ W12 운영 감사·알림·계정 제재
```

`W00`은 현재 검토 중인 DBML 작업을 최신 137개 테이블과 실제 소유권에 맞게 정리하는 단계다. 이 작업이 끝나기 전에는 Flyway와 영속성 구현을 병렬로 시작하지 않는다.

## 4. 작업별 체크리스트 예시

### W01 저장소 실행 골격·공통 검증

- 결과: 네 백엔드 저장소가 빈 애플리케이션으로 기동되고 공통 CI 검증을 통과한다.
- 범위: Gradle 멀티 프로젝트, Python 패키지, Testcontainers PostgreSQL, Redis/Queue 테스트 대역, Flyway 단일 소유권.
- 최초 실패 테스트: 각 실행 앱의 context 또는 health 검증이 구현 전 실패한다.
- 성공: 앱별 독립 실행, JPA `ddl-auto=validate`, jOOQ 생성 검증, Python DB 연결 검증이 통과한다.
- 실패: 각 서비스가 자체 migration을 실행하거나 다른 서비스 소유 테이블을 임의 변경한다.
- 선행 작업: W00.

### W02 인증 주체·권한 경계

- 결과: 이메일 또는 소셜 로그인을 통해 생성된 인증 주체가 사용자 API와 운영자 API에서 서로 다른 권한으로 검증된다.
- 주요 DB: `identity.*`, `operations.operator_accounts`, `operations.roles`, `operations.permissions`.
- 최초 실패 테스트: 일반 사용자가 관리자 기능 또는 다른 사용자의 비공개 전략에 접근하면 반드시 거절된다.
- 성공: Command와 Query 모두 같은 인증 주체·권한 계약을 사용하고 감사 대상 작업이 기록된다.
- 실패: Git 사용자 정보나 클라이언트 입력만으로 운영 권한을 인정한다.
- 선행 작업: W01.

### W03 전략 임시 저장·검증

- 결과: Basic 또는 Pro 전략 문서를 임시 저장하고 타입·연결·필수 정책을 서버에서 검증할 수 있다.
- 주요 DB: `strategy.strategies`, `strategy.strategy_documents`, `strategy.strategy_edit_leases`, `strategy.validation_runs`.
- 최초 실패 테스트: 잘못된 연결, 순환 그래프 또는 누락된 필수 정책을 가진 문서는 출시 가능한 상태가 되지 않는다.
- 성공: 편집 순서와 lease를 검증하고 검증 결과를 재현할 수 있다.
- 실패: 임시 저장만으로 백테스트나 봇 실행이 시작된다.
- 선행 작업: W01, W02.

### W04A 전략 출시·백테스트 요청 계약

- 결과: backend 제공자와 backtest-engine 소비자가 함께 검증할 버전형 메시지·멱등성·실패 계약이 루트에 정의된다.
- 최초 실패 테스트: 필수 식별자나 계약 버전이 누락된 메시지가 계약 검증을 통과하지 못한다.
- 성공: 제공자와 소비자가 같은 fixture로 독립적인 계약 테스트를 실행할 수 있다.
- 실패: 구현 저장소가 서로 다른 메시지 의미를 자체 정의한다.
- 선행 작업: W00.

### W04B 전략 출시·자동 백테스트 요청

- 결과: 검증된 문서를 불변 출시 스냅샷으로 만들고 공식 백테스트 요청을 정확히 한 번 발행한다.
- 주요 DB: `strategy.strategies`, `strategy.strategy_documents`, `strategy.compiled_flow_plans`, `operations.outbox_messages`, `backtest.runs`.
- 최초 실패 테스트: 같은 출시 요청을 재시도해도 출시본과 공식 백테스트가 중복 생성되지 않는다.
- 성공: 출시 트랜잭션과 Outbox 기록이 원자적으로 저장되며 출시본 수정이 거절된다.
- 실패: 지원 불가능한 블록을 데이터 근사로 실행하거나 숨겨진 기본 정책을 적용한다.
- 선행 작업: W03, W04A.
- 병합 순서: backend 제공자 → backtest-engine 소비자 → 루트 서브모듈 포인터.

### W05 자동 백테스트 실행

- 결과: 출시 이벤트가 잠긴 전략과 데이터 Manifest를 사용한 공식 백테스트 한 건으로 처리된다.
- 주요 DB: `backtest.runs`, `backtest.run_attempts`, `backtest.input_datasets`, `backtest.input_bundles`, `backtest.performance_summaries`.
- 최초 실패 테스트: 동일 작업이 재전달되어도 공식 실행이 중복되지 않고 다른 Manifest로 몰래 교체되지 않는다.
- 성공: 성공·실패·백테스트 불가 상태가 명시적으로 기록되고 재현 입력이 고정된다.
- 실패: 필요한 시간 해상도가 없을 때 종가 등으로 근사한다.
- 선행 작업: W01, W04, 사용 가능한 데이터 Manifest.

### W08 실시간 시세 수신·시장 이벤트

- 결과: 지원 종목의 실시간 시세가 정규화·중복 제거·순서 검증된 내부 이벤트로 발행된다.
- 주요 DB: `market_data.*`; 최신 관측값과 스트림은 Redis.
- 최초 실패 테스트: 중복되거나 오래된 시세가 새 시장 이벤트로 처리되지 않는다.
- 성공: 외부 provider 형식이 내부 이벤트 계약으로 격리되고 재연결 후 순서가 검증된다.
- 실패: UI 연결 상태가 시장 데이터 처리 또는 봇 실행에 영향을 준다.
- 선행 작업: W01 및 시장 이벤트 계약.

### W09 봇 평가·주문·체결·원장

- 결과: 봇별 직렬 평가가 주문 후보를 하나의 최종 처리 단계로 모아 예산·위험 검사 후 소수점 가상 주문과 원장을 생성한다.
- 주요 DB: `bot.evaluation_runs`, `trading.*`, `operations.outbox_messages`.
- 최초 실패 테스트: 중복 시장 이벤트와 재시도에도 같은 판단에서 주문이 두 번 생성되지 않는다.
- 성공: 완료된 평가 결과의 주문 시점 유효성을 다시 검사하고 무효할 때만 버린 뒤 재평가한다.
- 실패: 사용자가 직접 주문 의도를 제출하거나 잠기지 않은 전략을 실행한다.
- 선행 작업: W07, W08 및 주문·체결 계약.

## 5. 6명 배치 기준

공통 선행 단계가 끝나면 다음 여섯 책임 묶음이 각자 독립적인 fixture와 fake adapter로 진행된다.

| 묶음 | 주 저장소 | 주 소유 영역 | 첫 독립 작업 |
|---|---|---|---|
| A — 계정·운영 | `backend` | identity, operations, security, notification | 이메일 가입·인증 fixture |
| B — 전략·봇 | `backend` | strategy, bot-control, CLI | Basic 전략 문서 lossless 저장 |
| C — 시장·평가 | `trading-engine` | market gateway, strategy runtime, evaluation | 녹화 시장 사건 정규화 |
| D — 데이터·백테스트 | `data-pipeline`, `backtest-engine` | storage, market_data, backtest | Alpaca 응답→Parquet→Manifest→재현 실행 |
| E — 방·성과 | `backend` | competition, performance | fake bot 사건 기반 방 수명주기 |
| F — 거래·원장 | `trading-engine` | order, execution, settlement, ledger | fake 주문 후보→멱등 주문 Intent |

같은 `backend` 저장소의 A·B·E는 공통 Gradle 골격을 먼저 병합한 뒤 서로 다른 도메인 package와 스키마를 소유한다. D는 두 Python 저장소를 함께 맡되 source code를 직접 공유하지 않고 버전형 Manifest·Parquet fixture로 연결한다. C는 주문 후보 생성까지, F는 예산·위험 검사 이후 주문·체결·원장을 소유하며 공통 candidate batch interface를 먼저 병합한다.

먼저 끝난 사람은 다른 담당자의 진행 중 카드를 수정하지 않는다. 원 담당자가 넘긴 미시작 카드만 별도 경로·DB 엔티티·계약 범위로 작업하고 원 담당자가 리뷰한다.

## 6. 정식 전환 시 필요한 결정

- 현재 DBML 검토 작업을 실제 canonical DB 변경을 포함하도록 갱신할지
- 위 작업 크기가 팀의 1회 작업 단위로 적절한지
- 첫 개발 흐름을 `전략 출시 → 자동 백테스트`로 할지 `봇 실행 → 가상 체결`로 할지
- Git-local 작업 상태를 유지할지 GitHub Issues를 유일한 외부 작업 상태로 연결할지
