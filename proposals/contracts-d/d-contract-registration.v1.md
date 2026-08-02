---
schema_version: 1
id: proposal.contracts.d-contract-registration
kind: proposal
status: proposal-only-governance-unknown
revision: 1
refs:
  - contracts/registry.yaml
  - .harness/governance.yaml
  - docs/collaboration-policy.md
  - db/schema.dbml
---

# proposal.contracts.d-contract-registration

D 묶음(`data-pipeline`, `backtest-engine`) 재구축으로 확정된 계약 사실을 기록하고,
루트 `contracts/` 등록이 필요한 항목을 제안한다.

**이 문서는 승인·통합·릴리스된 변경이 아니다.** `contracts/registry.yaml`은 보호 정본이고
canonical-write gate는 fresh provider 관찰이 제품 권한자를 승인자로 확인할 때만 수정을
허용한다. 현재 관찰은 확보되지 않았으므로 정본을 수정하지 않고 이 제안만 작성한다.

- 상태: 제안만 작성 — provider 승인 관찰 미확보
- 작성일: 2026-08-03
- 기준 저장소: `Idea2Strategy/Idea2Strategy`
- 기준 브랜치: `develop`
- 기준 커밋: `7950a78`
- 관련 머지: data-pipeline PR #17, backtest-engine PR #34 (둘 다 각 repo `develop`에 머지됨)

---

## 1. 배경

감사 결과 D 담당 이슈 D19~D30이 CLOSED 상태였으나 실제 로직·영속성·통합이 없었다.
전면 재구축을 수행했고 두 PR이 머지되었다. 그 과정에서 **계약 관련 사실 세 가지**가 확정되었다.

### 1.1 루트 `contracts/registry.yaml`은 여전히 비어 있다

```yaml
contracts: []
```

전 프로젝트를 통틀어 등록된 계약이 0건이다. D가 소비·발행하는 계약도 등록되어 있지 않다.
governance가 fail-closed이므로 D가 등록할 수 없다.

### 1.2 계약 소유 관계 (재구축으로 확정)

| 계약 | 소유 | D의 역할 |
|---|---|---|
| `strategy-bot.v1` `OFFICIAL_BACKTEST_REQUESTED` | **B (backend)** | 소비. 재정의하지 않는다. |
| `strategy-bot.v1` `basic-compiled-plan` | **B (backend)** | 소비. `planChecksum` 검증 필수. |
| `market-data.v1` dataset-manifest | **D (data-pipeline)** | 발행 |
| `backtest.v1` result event | **D (backtest-engine)** | 발행 |

D가 이전에 들고 있던 평면 snake_case `com06.*` 검증기는 **아무도 발행하지 않는 형식**이었고
폐기했다. B의 실제 형식은 `metadata` 봉투 + camelCase + `sha256:` 접두 해시다.

검증은 손으로 쓴 파이썬 `if`문이 아니라 버전화된 JSON Schema(Draft 2020-12)로 수행한다.
스키마는 producer repo에 1부만 둔다.

### 1.3 실제로 발생한 계약 드리프트

재구축 도중 B가 `strategy-bot.v1`을 변경했다 — `backend@904a1f6`
*"feat: pin bot warmup snapshot requirements (#113)"*, `requiredFeatures` 블록 추가 및
`planChecksum` 재계산. `backtest-engine`이 들고 있던 사본은 변경 이전 것이었고,
로더는 B가 더 이상 발행하지 않는 형식에 맞춰 만들어져 있었다.

바이트 동일성 테스트가 이를 잡아냈다. 현재 D의 체크섬 구현은 B의 발행값을 정확히 재현한다.

```
computed : sha256:88d61198d46dce161c2a929702a7fd1cee5c9b044c470d2590b96f3825fcacb3
published: sha256:88d61198d46dce161c2a929702a7fd1cee5c9b044c470d2590b96f3825fcacb3
```

이전에도 같은 계열 사고가 있었다. COM06 fixture 두 사본이 어긋나 **producer 자신의
fixture를 consumer 검증기가 거부**하는 상태였는데, 각 repo CI는 자기 사본만 보므로
어느 쪽도 이를 볼 수 없었다.

---

## 2. 제안

### 2.1 `contracts/registry.yaml` 등록 (권한자 승인 필요)

아래 네 항목의 등록을 제안한다. 소유자는 1.2절 표를 따른다.

- `strategy-bot.v1` — 소유 B, 소비자에 D 추가
- `market-data.v1` dataset-manifest — 소유 D
- `backtest.v1` result event — 소유 D
- 각 항목에 producer 저장소 내 스키마 경로와 fingerprint를 함께 등록

D는 이 파일을 수정하지 않았다. 승인 관찰 확보 후 권한자가 반영해야 한다.

### 2.2 교차 저장소 계약 정합 스크립트 (이 제안과 함께 추가)

`scripts/validate_d_contract_parity.py`를 추가한다. 서브모듈을 동시에 보유한 것은
슈퍼프로젝트뿐이므로, 저장소 간 합의를 확인할 수 있는 것도 슈퍼프로젝트뿐이다.

검사 항목:

1. `backtest-engine`이 vendoring한 `strategy-bot/v1` fixture 6개가 `backend` 정본과 동일한지
2. 두 D repo가 vendoring한 central-migration 번들의 기록과 실제 구성원이 일치하는지

비교는 **git blob object id**로 한다. 워킹트리 바이트 비교는 쓰지 않는다.
두 저장소의 `.gitattributes` 규칙이 다르기 때문에(해시 이식성을 위해 일부 경로가 `-text`)
git 상으로 동일한 파일이 체크아웃에서 서로 다른 줄바꿈으로 놓일 수 있다.
바이트를 비교하면 이를 드리프트로 오보하고, 읽는 사람을 존재하지 않는 계약 버그로 보낸다.
blob id는 git 자신의 내용 동일성이며 `core.autocrlf`에 의존하지 않는다.

검증 결과 (`--rev origin/develop`, 머지된 상태 대상):

```
ok    strategy-bot.v1 fixtures (B -> backtest-engine): 6 file(s) identical to backend/...
ok    data-pipeline vendored bundle: 3 vendored file(s) recorded and present
ok    backtest-engine vendored bundle: 3 vendored file(s) recorded and present

3 parity check(s) passed.
```

**CI 게이트로 배선하지 않았다.** 루트 CI의 모든 job은 `submodules: false`이고,
루트 Flyway CI에 fine-grained PAT를 만들지 않는다는 방침에 따라 비공개 서브모듈 체크아웃은
credential-free 고정 번들 검증으로 대체되어 있다. 서브모듈 내용 없이는 이 검사를 수행할 수 없다.

따라서 다음 중 하나를 권한자가 선택해야 한다.

- 자격증명을 가진 별도 스케줄 job에서 실행
- 현행 유지: 각 repo가 자기 절반을 자체 CI에서 이미 검증한다
  (`backtest-engine`의 바이트 동일성 테스트, 각 repo gate8의 vendored digest 검증)
- 검사 대상 fixture를 루트에 고정 번들로 vendoring

**동작하지 못할 job을 추가하지 않았다.** 영구히 실패하거나 조용히 통과하는 게이트는
둘 다 검증하지 않는 것보다 나쁘다. 스크립트는 검사를 하나도 수행하지 못하면
"No check ran at all; that is not agreement."로 exit 2 한다.

---

## 3. 중앙 조치가 필요한 항목 (D 권한 밖)

재구축 중 발견했으나 D가 수정할 수 없는 항목이다. 각 PR 본문에도 기록했다.

### 3.1 DatabaseAccessPolicy 위반

`backend`가 `backtest.runs`에 직접 INSERT 한다
(`ImmutableStrategyReleaseJooqCommandAdapter.java:207`). `backtest` 스키마는 D 소유다.
같은 SQL에서 `slippage_rate_bps`가 리터럴 `5`로 하드코딩되어 있다 — 정책 값이 코드에 박혀 있다.

### 3.2 DatabaseAccessPolicy가 런타임에서 아무것도 막지 못한다

단위테스트 전용 정적 헬퍼이고, V1 마이그레이션에 role `GRANT`가 전혀 없다.
스키마 소유 경계가 문서상으로만 존재한다.

### 3.3 `storage` 스키마 소유가 모순 상태다

`DatabaseAccessPolicy.java:36`은 `SHARED`로 등록하고 구현 체크리스트는 D 소유라고 쓴다.
D는 이 모순을 해소할 권한이 없어 **`storage`에 새 DDL을 만들지 않았다**.
기여 검증기가 이를 문서가 아니라 규칙으로 강제한다(소유하지 않은 스키마를 대상으로 하는
DDL 문장을 거부).

### 3.4 빈 매니페스트의 `dataset_hash` 유니크 충돌

QUARANTINED로 끝난 객체 0개 매니페스트 둘은 같은 빈 리스트를 해시하므로
`uq_dataset_manifests_dataset_hash`에서 충돌한다(`LocalCatalog`에는 해당 제약이 없다).
해결에는 `dataset_hash`의 의미를 바꾸거나 인덱스를 좁혀야 하고, 둘 다 D의 결정이 아니다.
`data-pipeline`의 `db/tables.py::SCHEMA_CONTRADICTIONS`에 기록했다.

### 3.5 `stream_watermarks` 키가 `feed_id` 단독이다

shard별 진행 지점을 저장하려면 `(feed_id, shard_key)`가 필요하다.
정본 DDL을 D가 바꾸지 않고, 대신 완료 floor 투영으로 구현했으며
선언되지 않은 shard 키는 암묵 등록이 아니라 hard error로 처리했다.

### 3.6 `quality_incidents.instrument_id` FK 선행 조건

`market_data.instruments`를 참조하지만 파이프라인이 이 테이블을 채우지 않는다.
종목별 incident 기록은 D04 종목 등록이 들어와야 실제로 동작한다.

### 3.7 `feature_snapshot_batches.row_count`

카탈로그에서 유도할 수 없다(materialization별 row count 컬럼이 없다).
`seal()`은 전달된 결과를 저장된 해시와 교차검증하는 방식으로 우회했다.
전용 컬럼이 있으면 더 깔끔하다.

### 3.8 `feature_definitions.element_catalog_version_id`

`db/tables.py:446`은 FK가 의도적으로 선언되지 않았다고 기술하지만,
적용된 DDL(`V1:3328`)에는 `strategy.element_catalog_versions`로의 실제 FK가 존재한다.
기술과 제약이 어긋난다.

---

## 4. 보호 경로 미수정 확인

이 제안은 `.harness/governance.yaml`, `docs/collaboration-policy.md`, `db/schema.dbml`,
`specs/**`, `contracts/**` 중 어느 것도 수정하지 않는다.
`node scripts/validate-proposal-boundary.mjs`가 이를 검증한다.
