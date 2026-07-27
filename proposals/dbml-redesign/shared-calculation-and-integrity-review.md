# 공통 계산 재사용 및 DB 무결성 검토 제안

> 상태: 격리된 제안서. `stackcord governance check --json` 결과가 `unknown`이므로 이 문서와
> `schema.draft.dbml`은 승인된 정식 제품 명세나 운영 마이그레이션이 아니다.

## 1. 확정해서 반영한 계산 경계

서버 전체에서 재사용할 수 있는 계산은 봇과 무관한 순수 시장 계산으로 제한한다.

- 공통 계산 입력: 계산기 버전, 정규화된 파라미터, 해상도, 거래소 달력·정밀도 의미,
  종목, 정확한 원천 데이터 집합과 watermark
- 공통 계산 출력: 가격·캔들로부터 얻는 이동평균, 변동성 등 봇과 무관한 파생 피처
- 봇별 계산 입력: 봇 예산, 파티션 예산 상한, 포지션, 미체결 주문과 예약금, 전략 런타임
  상태, `RISK_POLICY`, 충돌 해결 정책
- 금지: 사용자 ID, 봇 ID, 비공개 전략 ID, 예산 또는 포지션을 공통 피처 캐시 키에 포함하거나,
  공통 시장 피처를 `bot.runtime_state_values`에 복제하는 것

처리 흐름은 다음과 같다.

1. 완성된 전략의 `semantic_document`를 검증한다.
2. `market_data.feature_definitions`의 불변 정의로 피처 요구사항을 정규화한다.
3. `bot.strategy_feature_requirements`에 전략·종목별 정확한 요구 집합을 저장한다.
4. 동일한 `definition_hash + instrument + exact input`은 서버에서 한 번만 계산한다.
5. 과거 시계열은 `feature_materializations`가 S3의 `DERIVED` dataset manifest를 가리킨다.
6. 실시간 값은 stream/cache로 fan-out하고 여러 snapshot을 한 microbatch 객체로 봉인한다.
7. 봇 평가는 `feature_snapshot_batch_id + feature_snapshot_key + hash`를 소비하고 봇 고유
   연산만 수행한다.
8. 백테스트는 `input_feature_materializations`로 동일한 과거 피처 결과를 고정하여 재사용한다.

`strategy.compiled_execution_plans`는 동일한 전략 의미를 서버 실행 명령으로 다시 컴파일하지
않기 위한 content-addressed 인프라 캐시다. 사용자 전략의 재사용, 복사 출처 또는 버전 관계가
아니며, 복사된 전략 행은 계속 독립된 새 객체다.

## 2. 이번에 수정한 논리 오류

- 기존 `input_market_hash`만으로는 실제 공통 입력을 FK로 추적할 수 없었다. 평가 실행이 공유
  feature snapshot batch를 명시적으로 참조하도록 보강했다.
- snapshot마다 PostgreSQL 행과 S3 객체를 하나씩 만들 수 있던 초기 초안을 폐기했다. RDB에는
  microbatch metadata만 두고 본문은 묶어서 object storage에 저장한다.
- 자유 형식 `scope_type/scope_id`는 다른 봇 또는 공통 시장 상태가 런타임 상태에 섞일 수 있었다.
  명시적인 bot/partition/strategy/block/instrument 소유권으로 바꿨다.
- 평가 결과가 다른 봇의 전략을 참조할 수 있던 단일 FK를 bot/partition 소유권 복합 FK로
  바꿨다.
- 상태 변경 event와 상태 값이 서로 다른 봇일 수 있던 관계를 `bot_id` 복합 FK 두 개로 막았다.
- 평가의 trigger/result event가 다른 봇일 수 있던 관계를 bot 소유권 복합 FK로 막았다.
- 최초 상태 생성은 이전 값이 없으므로 `previous_value_hash`가 nullable이어야 한다.
- 파티션 예산 상한은 0보다 크고 100% 이하여야 하며, 형제 합계 100% 이하는 deferred aggregate
  constraint/trigger로 검사해야 한다.
- 고정 슬리피지는 launch configuration에서 정확히 5 bps인지 CHECK로 검사한다.
- 성공한 공통 계산 결과는 output manifest 또는 batch object와 hash가 모두 있어야 한다.

## 3. 저장소별 책임

| 저장소 | 운영 책임 | 금지 사항 |
| --- | --- | --- |
| PostgreSQL | 불변 계산 정의, 전략 요구사항, 실행·manifest metadata, hash·lineage, 공식 봇 상태와 거래 원장 | 대용량 캔들·피처 시계열 본문, 일회성 배치 payload |
| S3 호환 저장소 | 주 단위 Parquet 원천·파생 시계열, live feature microbatch, 백테스트·성과 상세 | 검색 가능한 관계와 현재 업무 상태를 객체 key만으로 관리 |
| Stream | live market event 전달과 공통 피처 fan-out | 공식 상태의 유일한 원장 역할 |
| NoSQL/Cache | 활성 feature demand set, 최신 공통 피처, 재생성 가능한 조회 projection | 예산·예약·주문·체결·원장·감사 증거의 최종 진실 |

cache key에는 최소 `feature definition hash`, `instrument`, `source watermark/input hash`가
들어가야 한다. TTL 만료는 계산의 무효화 근거일 뿐 공식 증거 삭제가 아니다. cache miss 시에는
동일 키 single-flight/분산 lock과 idempotency key로 중복 계산 폭주를 막는다.

## 4. 아직 정식 production 승인을 막는 정책 항목

아래 값은 임의로 확정하면 제품 의미가 바뀌므로 DB 구조만 실패 차단 형태로 준비하고 값은
승인 전까지 운영 기본값으로 간주하지 않는다.

- Buying Power 예약 완충 `buffer_bps`의 정확한 값과 반올림 순서
- 수수료·가격·수량·손익의 종목/거래소별 정밀도와 반올림 규칙
- 실제 시장데이터 공급자, 재배포 권리와 보존·삭제 기간
- 공통 feature catalog의 정확한 계산식, warm-up, 결측·수정 데이터 처리와 calendar version
- 성과 및 대회 점수 공식
- PII, 주문, 체결, 감사, S3 객체의 보존·법적 hold 기간
- RPO/RTO, 처리량·지연 SLO, 물리 파티셔닝 도입 임계치
- 여전히 자유 문자열인 일부 운영 status/code의 허용 vocabulary

정식 마이그레이션에서는 DBML에 모두 표현할 수 없는 다음 항목이 필수다: RLS, 불변 설정
update/delete guard, 형제 파티션 예산 합계 deferred constraint, JSON Schema 검사, null-safe unique
index, append-only trigger, double-entry balance constraint, outbox consumer idempotency, S3 객체 검증,
retention job, backup/restore 및 부하 시험 증거.

## 5. DBML 검토용 Records

모든 테이블에는 컬럼을 명시한 가상 `Records` 행을 하나씩 넣었다. 모든 UUID를 동일한 검토용
값으로 맞춰 ERD에서 FK 흐름을 빠르게 따라갈 수 있다. 이 값은 문서용이며 production seed,
fixture 또는 migration으로 사용하면 안 된다. 종료·철회처럼 정상 진행 예시와 모순되는 선택
필드는 `null`로 표시했다.
