# 출시 준비 실행 계획 (3인 배포용)

작성 기준: 2026-08-08, root `develop` = `8010e14`
서브모듈 gitlink: `backend 4afb611` · `backtest-engine 5613ce4` · `data-pipeline 509ba3a` · `trading-engine f806f0c` · `ui 4819725`

---

## 0. 이 문서를 쓰는 법

### 0.1 왜 지난 체크리스트로는 안 됐는가

`docs/backend-implementation-master-checklist.md`는 195개 중 176개가 완료 표시되어 있고, 남은 19개는 **Pro 보류 5개 + A90·A91 + INT01~INT12**뿐이다. 즉 **기능 구현은 실제로 거의 끝났다.** 그런데도 서비스가 안 되는 이유는 체크리스트가 다루지 않는 층에 있었다:

1. **로컬 조합이 제품을 실행할 수 없다.** 트레이딩 워커가 시장 이벤트를 하나도 소비하지 않는 설정으로 떠 있다(§2.1). 그래서 INT03·INT06을 "해봤는데 안 되네"로만 끝냈다.
2. **데이터가 없다.** 지표(feature) 시계열이 단 하나도 만들어진 적이 없다(§2.5). 시장 데이터 적재 경로가 둘로 갈라져 있고, 그중 실제로 돌린 쪽은 **제품 기본 시간대인 30분봉을 버린다**(§2.4).
3. **비즈니스 로직이 라이브와 백테스트에서 서로 달랐다.** 8건을 이번에 고쳤다(§4). 그중 2건은 해당 전략이 백테스트에서 아예 돌지 않는 수준이었다.

체크리스트는 "무엇을 만들 것인가"를 관리했고, 위 세 층은 "만든 것이 실제로 함께 도는가"다. 이 문서는 후자만 다룬다.

### 0.2 담당 배분 원칙

**리포지터리 단위로 나눈다.** 같은 파일을 두 사람이 만지지 않는 것이 이 문서의 최우선 제약이다.

| 담당 | 소유 리포지터리 | 이 문서의 담당 절 |
| --- | --- | --- |
| **P1 · kcrmin** | root 슈퍼프로젝트(`compose*.yml`, `infra/`, `scripts/`, `db/`, 포인터) + `backend/` | §2.1 §2.2 §2.3 §2.6 §5 §6 |
| **P2 · pjy008008** | `data-pipeline/` + `trading-engine/` | §2.4 §2.5 §3.1 |
| **P3 · hjcud** | `backtest-engine/` + `ui/` | §3.2 §3.3 |

교체할 경우 **절 단위로 통째로** 옮긴다. 절 안의 개별 항목만 옮기면 파일이 겹친다.

`db/schema.dbml`, `compose.back.yml`, 루트 포인터는 **P1만** 수정한다. P2·P3가 필요하면 P1에게 요청한다. 이것이 이 프로젝트에서 실제로 충돌이 나던 세 지점이다.

### 0.3 각 항목의 형식

각 작업은 다음을 갖는다. AI 에이전트에게 그대로 넣어도 되도록 썼다.

- **상태**: `확인됨`(이 문서 작성 중 코드로 검증) / `검증 필요`(가설, 먼저 확인할 것)
- **근거**: 파일:줄
- **완료 조건**: 실행해서 통과해야 하는 명령 또는 관찰 가능한 결과

### 0.4 병합 규약 (지키지 않으면 서로를 덮어쓴다)

1. 서브모듈은 `feature/<이슈>-<이름>` 브랜치 → 해당 `develop`에 **`--squash`** 병합(서브모듈은 머지 커밋을 거부한다).
2. 루트 포인터는 **별개 PR**이고 **머지 커밋**으로 병합한다.
3. `backend`·`trading-engine`·`backtest-engine`·`data-pipeline` gitlink를 옮기는 포인터 PR은 **같은 커밋에서** `scripts/refresh-flyway-ci-bundle.ps1`을 돌려야 한다. gitlink를 먼저 커밋한 뒤 스크립트를 돌린다(스크립트가 HEAD를 검증한다). 안 하면 `flyway-integration`이 깨진다.
4. 포인터 PR은 **한 번에 하나만** 열어 둔다.
5. v1.0.0 전까지 `specs/**`·`contracts/**`·`.harness/governance.yaml`·`docs/collaboration-policy.md`를 고칠 때는 제품 권한자(`kcrmin`·`pjy008008`·`Juwon-Na`·`hjcud`)의 지시를 PR 본문에 인용한다(`AGENTS.md` 참조). 그 외 경로는 이 규약과 무관하다.

### 0.5 v1.0 범위에서 빠지는 것 (확인 필요)

체크리스트에 `보류(Pro)`로 명시된 5건이다. **Pro 모드를 v1.0에서 뺀다는 전제**로 이 문서를 썼다. 전제가 틀리면 P1이 먼저 알려야 한다.

- B09 Pro 타입 그래프 검증 · B10 Pro 예산·배분·리밸런싱 · B13 Basic→Pro 복사 변환 · C15 Pro 실행기 · F06 주문 그룹·연계 주문

UI에는 이미 `ProEditorUnavailableView.tsx`가 있어 Pro 진입을 정직하게 막는다. 즉 코드는 이 전제와 이미 일치한다.

---

## 1. 지금 실제로 참인 것 (측정값)

착시를 줄이기 위해 먼저 사실만 적는다.

| 항목 | 값 | 비고 |
| --- | --- | --- |
| root open PR | 0 | 전부 병합됨 |
| root open issue | 8 | 에픽 6 + `#266`(조합 기동) + `#248`(feature 배선) |
| 체크리스트 | 176/195 | 남은 19 = Pro 5 + A90·A91 + INT01~12 |
| backend 테스트 | 888개, 실패 0, **skip 271** | skip은 전부 `@Testcontainers(disabledWithoutDocker = true)`. **CI(ubuntu-latest)에서는 실제로 돈다**; 이 PC는 Docker Desktop이 꺼져 skip |
| trading-engine | `./gradlew build` 성공 | |
| backtest-engine | 1,246 pass · ruff · mypy 통과 | |
| data-pipeline | 1,046 pass · ruff · mypy 통과 | |
| ui | 550 tests, CI green | 로컬은 느려서 `findBy` 타임아웃 flake 발생. CI는 5회 연속 green |
| 미완성 표식 | 프로덕션 코드 전체에 실질 TODO/FIXME **0건** | 남은 5건은 정당한 null-object·프로토콜 스텁 |

**해석: 코드 품질과 테스트는 문제가 아니다.** 문제는 (a) 조합 설정, (b) 데이터, (c) 두 런타임 간 의미 불일치였다. (c)는 이번에 8건 해소했다(§4).

---

## 2. P0 — 이것들이 안 되면 나머지를 시험조차 할 수 없다

순서대로 한다. 2.1이 안 끝나면 2.2 이후를 검증할 수 없다.

### 2.1 [P1] 로컬 조합에서 트레이딩 워커가 시장 이벤트를 소비하지 못한다 — **최우선**

**상태: 확인됨.**

`MarketEventTransportConfiguration`은 `@ConditionalOnProperty(prefix = "trading.market-events", name = "redis-uri")`이고 `matchIfMissing`이 없다.
근거: `trading-engine/apps/trading-worker/src/main/java/com/idea2strategy/trading/worker/market/MarketEventTransportConfiguration.java:35`

`compose.back.yml`의 `trading-worker` 서비스는 `environment: *spring-environment`만 받고, 그 앵커에 `TRADING_*`가 **하나도 없다**.
근거: `compose.back.yml:285-300`, `compose.back.yml:3-31`

**결과: 로컬 트레이딩 워커는 정상 기동하지만 시장 이벤트를 0건 소비한다.** 평가도, 주문 후보도, 체결도 발생하지 않는다. 이것이 INT03(가입→…→봇 실행→주문·체결)이 한 번도 통과하지 못한 직접 원인이다.

AWS는 설정되어 있다. `infra/terraform/environments/development/templates/ec2-user-data.sh.tftpl:578-580`:

```
TRADING_MARKET_EVENTS_REDIS_URI=rediss://${cache_endpoint}:6379
TRADING_MARKET_EVENTS_REDIS_KEY_PREFIX=i2s
TRADING_MARKET_EVENTS_CONSUMER_NAME=trading-worker-development-1
```

**할 일:** 위 세 값의 로컬 대응(`redis://redis:6379`, `i2s`, 임의 consumer 이름)을 `compose.back.yml`의 `trading-worker` `environment`에 넣는다. `rediss://`(TLS)가 아니라 `redis://`다.

**완료 조건:**
```bash
docker compose -f compose.back.yml --profile apps logs trading-worker | grep -i "market event"
```
market-gateway가 이벤트를 흘릴 때 워커 로그에 소비 흔적이 남고, `trading.evaluation_runs`에 행이 생긴다.

### 2.1b [P1] 생산자 쪽도 죽어 있다 — market-gateway가 로컬에서 아무것도 발행하지 않는다

**상태: 확인됨 (2차 감사에서 발견 — 2.1만 고치면 소비자는 살아나지만 흘러올 이벤트가 없다).**

게이트웨이의 Alpaca→Redis 발행 경로는 `market-gateway.redis-uri`가 설정될 때만 활성화되고, 자격증명·종목 매핑·권리 증빙이 없으면 fail-closed로 기동을 거부한다.
근거: `trading-engine/apps/market-gateway/src/main/resources/application.yaml:10-13` (전부 주석 처리된 기본값), `compose.back.yml:270-284`의 `market-gateway` 서비스는 `*spring-environment`만 받고 `MARKET_GATEWAY_*`·`ALPACA_*`가 하나도 없다.

AWS는 완전하다 (`ec2-user-data.sh.tftpl:564-576`). 로컬 대응이 필요한 것:

| 환경변수 | 로컬 값 | 비고 |
| --- | --- | --- |
| `MARKET_GATEWAY_REDIS_URI` | `redis://redis:6379` | TLS 아님 |
| `MARKET_GATEWAY_REDIS_KEY_PREFIX` | `i2s` | 2.1의 워커 prefix와 반드시 동일 |
| `MARKET_GATEWAY_ALPACA_FEED` | `sip` | |
| `ALPACA_API_KEY` / `ALPACA_API_SECRET` | `.env.docker` 로 주입 | **커밋 금지.** 추후 교체 예정이어도 저장소에 넣지 않는다 |
| `MARKET_GATEWAY_INSTRUMENT_MAPPING_PATH` | `/etc/market-gateway/instruments.json` | 아래에서 생성해 volume 마운트 |
| `MARKET_GATEWAY_RIGHTS_EVIDENCE_PATH` | `/etc/market-gateway/alpaca-sip-rights.json` | 동일 |
| `MARKET_GATEWAY_MATERIALIZATION_RECEIPT_PATH` | `/etc/market-gateway/materialization.properties` | 동일 |

**파일 3개의 출처 (AWS와 같은 방법으로 만든다):**
- `instruments.json` — DB 시장 카탈로그에서 symbol→instrument id 매핑을 뽑는다. 정확한 SQL과 검증(≥500 종목, 심볼/UUID 형식)은 `scripts/aws/development-database-bootstrap.sh:529-548`에 있다 — 그대로 로컬 postgres에 돌리면 된다. **선행: 시장 카탈로그가 시드되어 있어야 한다** (`scripts/invoke-development-market-catalog-bootstrap.ps1` 경로 확인). 종목이 500개 미만이면 게이트웨이가 기동을 거부한다(`minimum-instrument-count: 500`).
- `alpaca-sip-rights.json` — 같은 스크립트의 바로 아래 블록이 생성 방법이다. 권리 결정은 `specs/product/decisions/decision.data.providers-alpaca-sip.md`.
- `materialization.properties` — `scripts/deploy-development-core-runtime.ps1`이 AWS에서 만드는 수령증. 로컬 형식은 그 스크립트에서 확인.

**할 일:** 위 env를 `compose.back.yml`의 `market-gateway`에 추가하고, 파일 3개를 생성하는 로컬 스크립트(또는 dev.ps1 단계)를 만들어 volume으로 마운트한다.

**완료 조건:**
```bash
docker compose -f compose.back.yml --profile apps logs market-gateway | grep -iE "publish|candle"
```
정규장 중 실행 시 30분 경계마다 `MARKET_EVALUATION_READY`가 Redis에 발행되고, 그 직후 2.1의 완료 조건(워커 소비)이 함께 성립한다. 장외 시간에는 게이트웨이가 정상 기동만 해도 완료로 본다 — 발행은 세션이 열려야 생긴다.

### 2.2 [P1] 로컬 조합에 방(room)·운영자 경로가 꺼져 있다

**상태: 확인됨.**

`compose.back.yml`에 다음이 **전부 없다**. 각 애플리케이션 기본값은 `false` 또는 빈 문자열이다.

| 환경변수 | 기본값 | 없으면 | 근거 |
| --- | --- | --- | --- |
| `TRADING_ROOM_ACCOUNT_OPEN_ENABLED` | false | 방 참가 시 원장 계좌가 열리지 않음 | `trading-engine/apps/trading-worker/src/main/resources/application.yaml:21` |
| `ROOM_LEDGER_RESULT_CONSUMER_ENABLED` | false | 열림/거절 결과를 backend가 소비하지 않음 | `backend/apps/backend-worker/src/main/resources/application.yaml:25` |
| `ROOM_LEDGER_OPEN_REQUEST_QUEUE_URL` | 빈 값 | relay가 보낼 곳이 없음 | 같은 파일 `:21` |
| `ROOM_LEDGER_OPENED_QUEUE_URL` | 빈 값 | 위와 같음 | 같은 파일 `:22` |
| `ROOM_LEDGER_REJECTED_QUEUE_URL` | 빈 값 | 위와 같음 | 같은 파일 `:23` |
| `CORPORATE_ACTION_APPROVAL_QUEUE_URL` | 빈 값 | 기업행사 승인 이벤트가 파이프라인에 전달되지 않음 | 같은 파일 `:24` |
| `OPERATOR_AUTH_ENABLED` | false | 운영자 라우트 사용 불가 | `backend/apps/backend-api/src/main/resources/application.yaml:26` |
| `OPERATOR_RBAC_READ_ENABLED` | false | 운영자 RBAC 조회 불가 | 같은 파일 `:45` |
| `EMAIL_DELIVERY_ENABLED` | false | 메일 발송 없음 | 같은 파일 `:18`, batch `:11` |

**선행 조건이 있다. 플래그만 켜면 기동이 깨진다.**

- 방 큐 3개와 기업행사 큐가 localstack에 **생성되지 않는다.** `infra/docker/localstack/ready.d/10-create-queues.sh`가 만드는 큐는 `bot-commands`, `backtest-jobs`, `pipeline-jobs`, `domain-events`, `official-backtest-requests`, `backtest-{basic,custom,competition}`, `backtest-{basic,custom,competition}-request`뿐이다. → **먼저 큐를 추가**해야 한다.
- `OPERATOR_AUTH_ENABLED=true`는 운영자 OIDC IdP 설정을 요구한다. IdP 없이 켜면 fail-closed로 기동이 막힐 수 있다. → `ui/playwright.operator-oidc.config.ts`와 `scripts/`의 운영자 OIDC 하니스가 로컬에서 무엇을 요구하는지 먼저 확인한다.
- `EMAIL_DELIVERY_ENABLED=true`는 SES를 요구한다. 로컬에서는 켜지 말고 **INT05는 AWS에서** 검증한다.

**할 일:**
1. `10-create-queues.sh`에 `room-ledger-open-request`, `room-ledger-opened`, `room-ledger-rejected`, `corporate-action-approval` 추가(기존 `create_queue` 함수 사용 — DLQ까지 같이 생긴다).
2. `compose.back.yml`에 위 큐 URL과 `TRADING_ROOM_ACCOUNT_OPEN_ENABLED`, `ROOM_LEDGER_RESULT_CONSUMER_ENABLED` 추가.
3. `backend-worker`의 `SPRING_APPLICATION_JSON`은 `queues` 맵을 **키 단위로 병합**한다. 방·기업행사 이벤트 타입 4개가 그 JSON에 없으면 `application.yaml`의 빈 문자열이 남는다. JSON에 4개를 추가하거나, JSON을 지우고 전부 환경변수로 통일한다. **후자를 권한다** — 지금 한 서비스가 두 방식으로 설정돼 있어 읽는 사람이 매번 틀린다.
4. 운영자 플래그는 §5(INT05)에서 AWS로 검증하고, 로컬에서는 켜지 않는다.

**완료 조건:** `docker compose --profile apps up` 후 13개 서비스 전부 healthy, `backend-worker`·`trading-worker` 로그에 큐 URL 누락 경고 없음.

### 2.3 [P1] 로컬 조합을 띄우기 전에 서브모듈을 포인터에 정확히 맞춰야 한다 — 결함 아님, 운영 규칙

**상태: 확인됨. 코드는 올바르다.** 이 절은 고칠 것이 아니라 **알고 있어야 하는 것**이다. 여기서 막혀 시간을 버리는 일이 반복됐다.

`compose.back.yml:181`이 마운트하는 `./.harness/local/tmp/flyway-bundle`은 커밋되지 않는 로컬 산출물이다. 이걸 만드는 흐름은 이렇다.

1. `scripts/dev.ps1`의 `Initialize-FlywayBundle`이 `prepare-flyway-bundle.ps1`을 호출한다 — 단 **`-WithBackend`일 때만**(`scripts/dev.ps1:234-243`). `-WithBackend`는 기본값이 아닌 opt-in 스위치다(`:9`). 즉 `dev.ps1 up`만 하면 인프라만 뜨고 앱과 번들은 준비되지 않는다.
2. `prepare-flyway-bundle.ps1`은 `Assert-PinnedSubmodule`로 **모든 서브모듈이 루트 gitlink와 정확히 같은 커밋인지** 확인하고 다르면 던진다(`scripts/prepare-flyway-bundle.ps1:30-40`). `Assert-CleanContribution`으로 기여 디렉터리가 깨끗한지도 본다(`:132-134`).

**결과:** 개발 중 서브모듈이 포인터보다 앞서 있으면(흔한 상태) `dev.ps1 up -WithBackend`가 **명확한 오류로 멈춘다.** 조용히 잘못 적용되는 게 아니라 정직하게 실패한다 — 이건 올바른 설계다.

**운영 규칙:**
```bash
# 조합을 띄우기 전에 항상
git submodule update --init --recursive     # 포인터와 정확히 일치시킴
pwsh scripts/dev.ps1 up -WithBackend        # -WithBackend 없으면 앱이 안 뜬다
```
자기 브랜치 작업 중이라 포인터와 다르다면, 조합 검증은 **포인터 기준의 별도 워크트리**에서 한다. 같은 체크아웃에서 브랜치를 옮겨가며 하면 다른 세션과 HEAD를 다투게 된다.

**할 일: 이미 되어 있다.** `docs/development-start-guide.md:57`이 `dev.ps1 up -Scope all -WithBackend -NoBrowser`를 명시한다. 코드 변경도 문서 변경도 필요 없다 — 이 절은 알고 시작하라는 뜻으로만 남긴다.

### 2.4 [P2] 시장 데이터 적재 경로가 둘이고, 실제로 쓴 쪽이 제품 기본 시간대를 버린다

**상태: 확인됨. 비즈니스 로직 충돌.**

제품이 선언한 전략 시간대는 **30m·1h·4h·1d 네 개**이며 **UI 기본값은 30분봉**이다.
- `ui/src/views/StrategyViews.tsx:599-601` — `BASIC_TIMEFRAMES = ['30분봉','1시간봉','4시간봉','일봉']`, 기본값은 첫 번째
- `backend/db-migration/.../V20260808000000__backend_publish_live_strategy_timeframes.sql` — 라이브 4종
- `backend/db-migration/.../V20260808120000__backend_publish_production_backtest_resolutions.sql` — 백테스트 4종
- `data-pipeline/db/migration-contributions/migrations/V20260808120100__pipeline_seed_production_rsi_timeframes.sql` — RSI_14 정의·피드 4종

그런데 `../market_hist_script/`(리포지터리 밖, git 미추적)의 README는 이렇게 못박는다:

> 30분봉은 집계를 위한 임시 입력입니다. 디스크에는 저장하지 않으며 …

근거: `market_hist_script/README.md:17`, 출력 구조도 `1hour`·`4hour`·`1day`뿐(`README.md:31-40`).
추가로 **그 스크립트의 산출물이 아직 하나도 없다** — `*.parquet`·`*.csv` 0건.

정본 경로인 `data-pipeline`은 30m을 완전히 지원한다: `market_pipeline_lib/cli.py:57,112,147,273` 모두 `("30m","1h","4h","1d")`.

**결론: `market_hist_script`는 정본이 아니다.** 이걸로 적재하면 사용자가 기본값(30분봉)으로 만든 전략은 데이터가 없어 백테스트가 불가능하다.

**할 일:**
1. `market_hist_script`를 적재 경로에서 **제외**한다. 티커 유니버스 산출(S&P500 10년 편출입 + ETF 27종)만 쓸 값이 있다면 그 CSV만 `data-pipeline`으로 가져오고, 봉 수집·집계는 `data-pipeline` CLI로 통일한다.
2. `data-pipeline` CLI로 30m·1h·4h·1d **네 개 모두** 적재한다(`--resolution all`). Adjusted 레이어가 전략 입력이다.
3. `scripts/invoke-development-market-catalog-bootstrap.ps1`이 종목 카탈로그를 어떻게 적재하는지 확인하고 그 경로와 합친다.

**완료 조건:**
```sql
SELECT resolution, count(*) FROM market_data.dataset_manifests
WHERE status='AVAILABLE' GROUP BY resolution ORDER BY resolution;
```
네 해상도 모두 0보다 크고, 30m의 커버리지 시작이 다른 셋과 같다.

### 2.5 [P2] 지표(feature) 시계열이 단 하나도 만들어진 적이 없다

**상태: 확인됨.** root `#248`이 이 카드다.

RSI_14의 **정의와 출력 피드는 published**(위 마이그레이션)인데 **값이 없다.** 그래서 RSI 전략은 읽을 시계열은 있고 내용은 비어 있다.

계획 도구는 이번에 병합됐다: `data-pipeline` PR #45.

```bash
# 계획만 출력(DB 읽기만, 쓰기 없음)
python -m apps.pipeline_worker.backfill_features --database-url "$PIPELINE_WORKER_DATABASE_URL"

# 실제 전송
python -m apps.pipeline_worker.backfill_features \
  --database-url "$PIPELINE_WORKER_DATABASE_URL" \
  --send --queue-url "$PIPELINE_JOBS_QUEUE_URL"
```

**읽고 나서 보낼 것.** 계획은 다음을 이름으로 보고한다: `NO_INSTRUMENTS`(해당 시간대에 봉이 없음 — 2.4가 안 끝났으면 30m에서 이게 뜬다), `NO_COVERAGE`, `SOURCE_GAP`, `EMPTY_SPAN`, `PERIOD_SPLIT`.

`PERIOD_SPLIT`이 뜨면 **그냥 `--allow-holes`로 밀지 말 것.** 그건 이음새마다 앞 14봉의 RSI가 비는 것을 받아들이는 뜻이다. 원인은 한 기간의 소스 오브젝트가 512개(worker 상한)를 넘는 것이므로, 먼저 매니페스트 조각 크기를 확인한다.

**선행: `MATERIALIZE_FEATURE_OUTPUT`은 `PIPELINE_WORKER_FEATURE_OUTPUT`과 `PIPELINE_WORKER_DATABASE_URL`이 있어야 동작한다**(없으면 `PortNotConfiguredError`). 근거: `data-pipeline/apps/pipeline_worker/commands.py:124-125`. 로컬 조합에 이 두 값이 있는지 먼저 본다.

**완료 조건:**
```sql
SELECT d.resolution, count(*) FROM market_data.feature_materializations m
JOIN market_data.feature_definitions d ON d.id = m.feature_definition_id
WHERE m.status='SUCCEEDED' GROUP BY d.resolution ORDER BY d.resolution;
```
네 해상도 모두 종목 수만큼 존재. 그 다음 백테스트를 한 번 돌려 `FEATURE_SERIES_DATA_GAP`이 안 나오는 것까지 확인한다.

### 2.6 [P1] AWS에서 백테스트가 발송되지 않는다

**상태: 확인됨. 의도된 opt-in이지만 릴리스에서 반드시 켜야 한다.**

`infra/terraform/environments/development/variables.tf:417-421`:

```hcl
variable "enable_backtest_outbox_relay" {
  description = "... A full release candidate must explicitly set this true."
  type        = bool
  default     = false
}
```

이 값이 `BACKTEST_OUTBOX_RELAY_ENABLED`로 들어간다(`templates/ec2-user-data.sh.tftpl:410`). **false이면 전략을 출시해도 자동 공식 백테스트 요청이 큐로 나가지 않는다.**

로컬 조합은 이미 켜져 있다 — `backend-worker`의 `SPRING_APPLICATION_JSON`이 `outbox-relay.enabled=true`로 덮는다(`compose.back.yml:259-265`). **AWS만 문제다.**

**할 일:** 릴리스 후보의 `TF_VARS_JSON`에 `enable_backtest_outbox_relay = true`를 넣고, 세 백테스트 큐 URL이 실제로 채워지는지 확인한다(빈 URL이면 relay가 기동 시 실패하도록 설계돼 있다).

**완료 조건:** AWS에서 전략 1건 출시 → `backtest-basic-request` 큐에 메시지 도착 → 결과가 `backtest.run_outcomes`에 기록.

---

## 3. P1 — 비즈니스 로직 정합성

### 3.1 [P2] 라이브 재기동이 일정(SCHEDULE) 주기의 위상을 바꾼다

**상태: 확인됨. 설계 결정이 필요하다 — 코드만 고칠 수 없다.**

`EVERY_N_TRADING_DAYS`의 판정식은 두 런타임이 같다:
- 라이브 `BasicPlanInterpreter.java:514-515` — `newDay && interval > 0 && floorMod(dayIndex - 1, interval) == 0`
- 백테스트 `elements/catalog.py:546` — `new_day and interval > 0 and (day_index - 1) % interval == 0`

다른 건 `dayIndex`의 **출처**다.
- 라이브: `BasicMarketSignalState.tradingDayIndex`를 **관측한 거래일마다 증가**시킨다. 인메모리이고 봇 재등록 시 새로 만들어진다(`EvaluatingBotRuntime` `signalState()`의 `computeIfAbsent`).
- 백테스트: 고정된 세션 스케줄의 인덱스(`_schedule_values`의 `sessions.index(session) + 1`).

**결과 두 가지:**
1. **워커를 재기동하면 `tradingDayIndex`가 1로 돌아가 "N거래일마다" 주기의 위상이 바뀐다.** 5거래일 주기 봇이 배포 때마다 다른 날에 매수한다.
2 같은 이유로 180봉 롤링 윈도우도 비어서 다시 채워진다. 웜업(`StartupWarmupCoordinator`)은 지표 윈도우를 채우지만 이 카운터는 복원하지 않는다.

**권장 방향:** `tradingDayIndex`를 **관측 횟수가 아니라 고정 시장 캘린더와 봇 시작일로부터 계산**한다. 그러면 재기동이 값을 바꿀 수 없고 백테스트의 스케줄 기반 인덱스와 정의가 같아진다. 이 방향이 맞는지(=봇의 "1일차"가 봇 시작일인지 첫 관측일인지)는 제품 판단이므로 **먼저 합의하고 구현**한다.

**완료 조건:** 워커를 재기동해도 같은 봇의 `schedule.tradingDayIndex`가 연속이고, 같은 기간 백테스트의 값과 일치하는 테스트.

### 3.2 [P3] 백테스트·라이브 정합성 회귀 방지

§4에서 8건을 고쳤고 각각 테스트가 붙어 있다. P3는 **이 테스트들을 깨지 않게 유지**하고 새 요소를 추가할 때 같은 기준을 적용한다.

`backtest-engine/tests/test_live_parity.py`가 그 계약서다. 새 블록을 추가할 때 반드시 답할 것:
1. 라이브가 그 값을 어디서 얻는가, 백테스트는 어디서 얻는가?
2. 정밀도와 반올림이 `precision:1.0.0`(8자리 HALF_EVEN)을 따르는가? — 지표 계산은 `OfficialFeatureCatalog.WORKING_PRECISION`(34자리 HALF_EVEN) 후 8자리 양자화다.
3. 무한 재귀(EMA 계열)를 쓰는가? 쓰면 **입력 창을 180봉으로 묶어야** 재현된다(`LIVE_SERIES_BARS`).

**주의: 요소 카탈로그의 `_MATH = Context(prec=18, ROUND_HALF_UP)`(`elements/catalog.py:93`)는 라이브 `BasicPlanInterpreter.MATH`와 의도적으로 짝이다.** 이쪽을 "정규 정밀도"로 바꾸면 오히려 불일치가 생긴다. 건드리지 말 것.

### 3.3 [P3] UI 정리 (작지만 오해를 만든다)

**상태: 확인됨. 기능 문제 아님.**

UI는 실제로 프로덕션 배선이 되어 있고 정직하다. `mockData`는 `import.meta.env.MODE === 'test'`일 때만 쓰이고(`DashboardView.tsx:107`, `BotsView.tsx:439-449`), 계약이 없는 화면은 샘플 대신 오류 페이지를 띄운다(`DashboardView.tsx:111`). `RuntimeHonesty.test.tsx`가 이걸 고정한다. **이 부분은 문제 없음 — 시간 쓰지 말 것.**

정리할 것만:
1. `package.json`의 `"name": "idea2strategy-ui-prototypes"` → 실제 제품이므로 이름을 바꾼다.
2. `src/data/productionEmptyData.ts`는 **아무도 import하지 않는다.** 쓸 것이면 쓰고, 아니면 지운다. 남겨두면 다음 사람이 "프로덕션은 빈 데이터를 쓴다"고 오해한다.
3. 로컬 vitest가 느린 환경에서 `findBy*` 타임아웃으로 flake가 난다(2회 실행에서 서로 다른 테스트가 실패). CI는 green이다. 급하지 않지만 타임아웃을 올려두면 로컬 검증이 편해진다.

---

## 4. 이번에 고친 것 (참고 — 재작업 금지)

전부 병합됨. 각 항목에 해당 `develop`에서 실패하는 테스트가 붙어 있다.

| # | 불일치 | 영향 | PR |
| --- | --- | --- | --- |
| 1 | 고정 지표가 세션 마지막 짧은 봉을 못 읽음 | **4h·1d RSI 전략 백테스트 불가** | bt #68 |
| 2 | `1회만` 게이트가 포지션보다 오래 생존 | 매수-매도-매수가 1회 거래로 백테스트 | bt #68 |
| 3 | `holdingBars` 1 밀림 | "N봉 보유" 청산이 한 봉 늦게 | bt #68 |
| 4 | 주/월 첫날 플래그가 하루 종일 참 | 30분봉이면 월초 규칙 하루 13번 vs 운영 1번 | bt #68 |
| 5 | `session.close`가 시계 16:00 고정 | **조기 종료일 라이브 청산 미실행** | tr #150 |
| 6 | RSI_14 구현이 2개(정밀도 상이) | 임계값 근처 교차 판정 갈림 | tr #150 |
| 7 | 포지션 지표 반올림 HALF_UP vs HALF_EVEN | 9번째 소수 tie에서 수익률이 두 값 | bt #69 / tr #151 |
| 8 | 라이브 180봉 vs 백테스트 무제한 | **MACD 히스토그램이 영구 불일치** | bt #70 |

핵심 원인은 **6.5시간 세션이 1h·4h·24h로 나누어지지 않는다**는 것이었다. 매 세션 마지막 봉이 짧아 정규 격자를 가정한 조회가 실패했다.

부수 수정: `backtest-engine`의 vendored central-migration fixture에 data-pipeline 기여 파일이 섞여 있어 루트 체크아웃에서만 테스트가 깨졌다(서브모듈 CI는 skip). PR #70에서 제거.

감사 목록 중 **틀린 주장 2건**도 기록해 둔다. 다음 사람이 헛일하지 않도록:
- "라이브 균등배분이 항상 1/1" → **아니다.** `BasicStrategyExecutor.assignEqualBuyShares`는 이미 1/N이다.
- "`holdingTradingDays`가 1 밀렸다" → **아니다.** 양쪽 다 `max(0, count-1)`로 경과일 기준이고 일치한다. 그래서 카탈로그가 `당일 장 마감`을 별도 옵션으로 둘 수 있다.

---

## 5. INT01~INT12 — 통합 검증

**P0(§2)가 전부 끝난 뒤에 시작한다.** 그전에 하면 조합 결함을 도메인 결함으로 오진한다. 지난번이 그랬다.

각 카드는 **한 명이 끝까지** 수행한다. 여러 명이 같은 카드를 동시에 만지면 증거가 섞인다.

| 카드 | 담당 | 선행 | 비고 |
| --- | --- | --- | --- |
| INT02 최초 DB 구축·migration rehearsal | P1 | §2.3 | 빈 DB + 직전 스냅샷 양쪽. `scripts/aws/development-database-bootstrap.sh`가 커밋된 `db/flyway-ci-bundle`을 다이제스트 검증 후 적용한다 — 이 경로를 리허설한다 |
| INT01 계약 호환성 | P1 | INT02 | provider·consumer 버전·fixture 전수 |
| INT03 전체 사용자 E2E | P3 | §2.1 §2.4 §2.5 | 가입→전략→검증→출시→자동 백테스트→봇 실행→주문·체결→중단. **§2.5가 안 끝나면 RSI 전략에서 반드시 실패한다** |
| INT04 전체 방 E2E | P1 | §2.2 | 백테스트 결과가 방 점수에 섞이지 않는지 포함 |
| INT05 운영자 E2E | P1 | §2.2 | 운영자 OIDC·SES는 로컬에서 안 되므로 **AWS에서**. 시작 전 AWS 상태 2건 확인: SES가 아직 sandbox(PENDING)면 검증 메일이 안 나가고, Cognito 운영자 풀에 사용자 0명이면 로그인할 운영자가 없다(2026-08-06 기준 둘 다 미해결이었다) |
| INT06 장애·재기동·중복 전달 | P2 | §2.1 §3.1 | **§3.1이 여기 걸린다** — 재기동 위상 문제를 안 고치면 이 카드가 정직하게 통과할 수 없다 |
| INT07 성능·용량 | P2 | **차단됨** | §6 참조 — 목표치가 없어 합격 기준이 없다 |
| INT08 보안·개인정보·법적 표현 | P1 | INT10, A90 | 1차 검토 완료(`docs/reviews/int08-...md`). 잔여 3건이 각각 A90·INT10에 귀속되므로 그 둘이 끝나야 닫힌다 |
| INT09 백업·복구·원장 대사 | P1 | INT02 | |
| INT10 UI 계약 연결 | P3 | §2.1 | 1차 검증 완료. 잔여: 화면 전수 스위프(성과 카피 포함) |
| INT11 릴리스 후보 고정 | P1 | 위 전부 | 루트+서브모듈 정확한 커밋 하나로 고정 |
| INT12 v1.0 릴리스 | P1 | INT11 | `develop`→release→`main` |
| A90 전체 서비스 인증·감사 통합 | P1 | INT01 | B~F가 같은 인증 주체·RBAC·Outbox·감사 계약을 쓰는지 |
| A91 배포·복구·릴리스 파이프라인 | P1 | INT02 INT09 | migration 1회 실행 보장 포함 |

---

## 6. 출시를 막는 미결 제품 결정 1건

**`specs/product/open-questions/question.operations.slo.md` — `status: unknown`.**

> 어떤 가용성·지연·용량·보존·백업·복구·감사·지원 목표가 운영상 지속 가능한가?

나머지 4개 open question은 대응 결정이 존재한다(`decision.accounting.precision-v1`, `decision.data.providers-alpaca-sip`, `decision.strategy.basic-catalog-v1`, `decision.ui.partial-baseline`). **SLO만 답이 없다.**

**결과: INT07(성능·용량 시험)에 합격 기준이 없다.** 측정은 할 수 있지만 통과/실패를 판정할 수 없고, 따라서 INT11(릴리스 후보)도 정직하게 닫히지 않는다.

**할 일(P1, 제품 권한자 결정):** 최소한 다음 네 개만이라도 숫자로 정한다.
1. 정규장 중 평가 지연 상한(이벤트 도착 → 주문 후보 생성)
2. 동시 실행 봇 수 목표
3. 공식 백테스트 1건의 완료 시간 상한
4. RDS·S3 백업 주기와 복구 목표 시간(RPO/RTO)

v1.0.0 이전이므로 `AGENTS.md`의 pre-v1.0 자세에 따라 권한자 지시를 PR 본문에 인용하고 `specs/`에 직접 쓸 수 있다. `question.operations.slo.md`를 `decision.operations.slo.md`로 승격하는 형태를 권한다.

---

## 7. 사용 방법 — "지금 내 차례인가"는 스크립트가 답한다

이 문서의 의존성 그래프는 **`docs/launch-readiness-tasks.json`** 에 기계가 읽는 형태로 들어 있고, 각 작업에는 저장소를 검사해 완료를 판정하는 조건이 붙어 있다. 순서를 사람이 기억할 필요가 없다.

```bash
# 지금 내가 할 수 있는 것 하나를 알려준다
pwsh scripts/launch-status.ps1 -Owner hjcud     # kcrmin | pjy008008 | hjcud
```

**세션을 시작하는 법 — 위 스크립트 한 줄이 정식 경로다.**

`-Owner` 를 주면 스크립트가 **에이전트에 그대로 붙여넣을 프롬프트까지 출력한다.** 설치도, 슬래시 명령도 필요 없다. Claude·Codex·다른 도구·사람 전부 이 경로가 동작한다. 출력된 블록을 복사해 붙이면 끝이다.

슬래시 명령은 **선택적 편의**일 뿐이며, 없어도 아무 문제 없다:
- Claude Code — `/start-work hjcud`. 저장소의 `.claude/skills/start-work/` 를 읽으므로 pull 후 바로 뜬다.
- Codex — `/start-work hjcud`. `initialize-local-harness.ps1` 이 `.agents/prompts/start-work.md` 를 `$CODEX_HOME/prompts`(기본 `~/.codex/prompts`)에 복사한다. Codex 버전이 커스텀 프롬프트를 지원해야 뜨므로, **안 보이면 그냥 위 스크립트를 쓴다.**

어느 경로든 같은 원장(`docs/launch-readiness-tasks.json`)을 읽으므로 답이 갈릴 수 없다.
2. 스크립트가 지목한 작업의 절을 이 문서에서 읽고, `해줘`(또는 해당 절 번호를 프롬프트에) — **문서 전체를 넣지 않는다.** 남의 리포지터리 지시가 3분의 2다.
3. 완료 판정은 스크립트가 한다. `repo`/`db` 작업은 검사가 통과해야 끝난 것이고, `manual` 작업(INT 카드)은 `.harness/local/evidence/<ID>.md`에 무엇을 실행해 무엇을 관찰했는지 적어야 끝난 것이다. **검사를 통과시키는 것이 완료의 정의다** — 체크박스를 켜는 게 아니다.
4. 다 하면 스크립트를 다시 돌린다. 다음 작업이 나오거나, 누구를 기다리는지 나온다.

**지켜지는 규칙은 훅이 강제한다 (기억할 필요 없음).** `scripts/initialize-local-harness.ps1`이 추적되는 `.githooks/`를 이 체크아웃에 붙이므로, Claude든 Codex든 사람이든 동일하게:
- `develop`/`main` 직접 커밋 차단 → 작업 브랜치·워크트리 안내
- 서브모듈 gitlink 커밋에 Flyway 번들이 빠지면 차단 (CI에서 2분 뒤 아는 대신 지금)
- 비밀 스캐너가 오탐하는 `test_`+35자 식별자 차단

훅이 막았는데 정말 넘어가야 하면 `--no-verify` — 단 PR에 이유를 적는다.

참고용 전체 흐름 (원장과 동일):

```
kcrmin:    2.1(TRADING_*) → 2.2(방·운영자 큐) → 2.6(AWS relay) → INT02 → INT01 → …
pjy008008: 2.4(30m 시장 데이터) → 2.5(feature 백필) → 3.1(재기동 위상) → INT06 → INT07
hjcud:     3.3(UI 정리) · §6(SLO 결정) → INT03 · INT10
```

2.1과 2.4는 서로 독립이라 병행 가능하다. INT03은 2.1·2.4·2.5 전부에 의존한다. §6은 아무것도 기다리지 않으므로 **hjcud가 지금 바로** 할 수 있고, 늦어질수록 INT07→INT11이 밀린다.

## 8. 검증 명령 모음

```bash
# 서브모듈 테스트
cd backend && ./gradlew build                     # 888 tests (Docker 있으면 +271)
cd trading-engine && ./gradlew build
cd backtest-engine && python -m pytest tests -m "not docker"
cd data-pipeline && python -m pytest tests -m "not integration"
cd ui && npm run typecheck && npx vitest run

# 루트
pwsh scripts/initialize-local-harness.ps1 -Verify
pwsh scripts/verify-collaboration-policy.ps1
pwsh scripts/refresh-flyway-ci-bundle.ps1         # gitlink 옮긴 커밋마다
pwsh scripts/test-flyway-ci-bundle.ps1            # Docker 필요

# 조합
pwsh scripts/dev.ps1 up
pwsh scripts/verify-deployed-development.ps1
```

Docker Desktop이 꺼져 있으면 backend 271건과 `test-flyway-ci-bundle.ps1`이 조용히 skip/실패한다. **통합 검증 전에 Docker를 먼저 켠다.**

---

## 9. 비즈니스 로직 불변 규칙

작업 중 이 규칙을 깨면 조용히 잘못된 거래가 생긴다. §4의 8건은 전부 아래 규칙 중 하나를 어긴 것이었다. 새 코드를 넣기 전에 해당 항목을 확인한다.

### 9.1 제품의 성격

**가상 체결 기반 전략 경쟁 서비스다.** 실제 증권사 주문을 내지 않는다(에픽 F 제목이 "주문·**가상 체결**·공식 원장"). `VirtualFillConfiguration`이 제품이지 임시 대체물이 아니다. 실주문 어댑터를 찾지 말 것. INT08 검토도 "직접 주문 엔드포인트 부재"를 합격 근거로 삼는다.

`trading.fake-candidate.enabled`는 기본 false이고 배포 어디에도 설정되지 않는다(`trading-engine/apps/trading-worker/src/main/resources/application.yaml:16`). 이건 개발용 스텁이므로 켜지 말 것 — 가상 체결과 다른 것이다.

### 9.2 전략의 시계는 하나다

사용자가 고른 봉 주기(30m·1h·4h·1d 중 하나)가 **그 전략의 유일한 시계**다. 1분봉·5분봉·15분봉은 이 제품에 없다. 평가·지표·주문 판정이 모두 그 하나의 주기로 이뤄진다. 표시용 분봉이 전략 평가를 트리거해서는 안 된다.

정본: `specs/product/decisions/decision.strategy.basic-catalog-v1.md`, 카탈로그 이름 `basic-elements:2026-08-08`.

### 9.3 세션은 6.5시간이고 균등하게 나뉘지 않는다

정규장은 09:30–16:00 ET다. **1h·4h·24h로 나누어지지 않으므로 매 세션 마지막 봉이 짧다** — 일봉은 6.5시간, 두 번째 4시간봉은 2.5시간, 마지막 1시간봉은 30분. 30분봉만 정규 격자다.

여기에 더해 **조기 종료일**이 있다(추수감사절 다음날·크리스마스 이브·7월 3일 → 13:00 ET). 시계의 시(hour)를 하드코딩한 판정은 전부 틀린다. 세션 종료는 **캘린더**에서 온다 — 라이브는 일봉 확정(`closed1d`), 백테스트는 `session.closes_at`.

§4의 1·5번이 이 규칙 위반이었다.

### 9.4 `1회만`은 포지션 주기당 1회다

실행 모드 4종(`1회만`·`주기마다`·`대기 후 재진입`·`대기 후 재실행`)과 대기 모드 3종(`조건 재충족`·`N봉 이후`·`N거래일 이후`)의 카운터는 **포지션이 닫히면 초기화된다.** 봇 수명당 1회가 아니다. 매수-매도-매수는 이 모드가 존재하는 이유인 정상 케이스다.

라이브는 포지션 스냅샷이 바뀌면 게이트를 버리고, 백테스트는 `_retire_closed_position_gates`가 같은 일을 한다.

### 9.5 보유 기간의 두 단위는 기준이 다르다

- **봉 단위**: 진입 봉이 **1봉째**다. 진입 봉에서 `holdingBars = 1`.
- **거래일 단위**: 진입일이 **0일째**다(경과일 기준, `max(0, count-1)`).

일부러 다르다. 그래서 카탈로그가 `당일 장 마감`을 `1거래일`과 별도 옵션으로 둘 수 있다. 둘을 "통일"하지 말 것 — 그러면 `당일 장 마감`이 중복이 된다.

### 9.6 기간 플래그는 하루에 한 번만 참이다

`schedule.weekFirstTradingDay`·`monthFirstTradingDay`·`monthLastTradingDay`는 **그 날의 속성**이므로 그 날의 **첫 봉에서만** 참이다. 30분봉이면 하루 13봉이므로, 이걸 어기면 월초 규칙이 하루 13번 발동한다.

`EVERY_N_TRADING_DAYS`도 `newTradingDay`와 함께 판정한다. 단 위상 출처 문제가 남아 있다 — §3.1.

### 9.7 지표는 두 구현을 두지 않는다

`RSI_14`는 `OfficialFeatureCatalog`가 유일한 구현이고, 백테스트는 그 정의가 발행한 시계열을 읽는다. 정밀도는 **34자리 HALF_EVEN 계산 후 8자리 HALF_EVEN 양자화**다.

"값이 거의 같은 두 구현"은 같은 지표가 아니다. 임계값 근처에서 판정이 갈린다.

**단, 요소 카탈로그의 산술(`_MATH = prec 18, HALF_UP`)은 라이브 인터프리터의 `MATH`와 의도적으로 짝이다.** `PRICE_CHANGE_PERCENT` 같은 요소 계산은 이쪽을 쓴다. 지표(feature)와 요소(element) 산술을 섞지 말 것.

발행되는 포지션 지표(`position.returnPercent`·`peakReturnPercent`·`drawdownPercent`)는 `precision:1.0.0` = **8자리 HALF_EVEN**이다.

### 9.8 무한 재귀 지표는 입력 창을 묶어야 재현된다

라이브는 해상도별 **180봉** 롤링 윈도우만 본다(`LIVE_SERIES_BARS`). SMA·볼린저처럼 창이 유한한 지표는 무관하지만, **EMA 계열(MACD)은 이전 모든 봉에 의존**하므로 창 길이가 다르면 값이 영구히 다르다.

`OfficialFeatureCatalog`가 유한창 방식만 인정하는 이유가 이것이다. 새 지표를 추가할 때 무한 재귀라면 창을 명시적으로 묶는다.

### 9.9 매수 배분은 1/N이다

한 흐름(flow)에서 조건을 통과한 종목이 N개면 각 종목에 **1/N**을 배분한다(`BasicStrategyExecutor.assignEqualBuyShares`). 매도는 배분을 갖지 않고 보유 수량이 크기를 정한다.

컨테이너는 **한 방향에 하나**이고 그 안의 블록은 AND로 묶인다. 매수 컨테이너 + 매도 컨테이너 **두 개가 정상**이며 예외 케이스가 아니다.

### 9.10 출시된 전략은 불변이고 봇은 역참조를 갖지 않는다

전략을 출시하면 그 버전은 불변이다. 봇은 출시 시점의 계획을 고정해 들고 돌며, **봇에서 전략으로 돌아가는 역참조가 없다**(provenance-free). 전략을 나중에 고쳐도 이미 도는 봇이 바뀌지 않는다.

편집 동시성은 **계정 단위 edit lease** + `expectedEditSequence` 낙관적 잠금으로 지킨다.

### 9.11 의미 문서와 표현 문서는 서로 도출되지 않는다

전략은 두 문서를 갖는다. **semantic**은 실행의 정본이고, **presentation**은 편집기 복원의 정본이다. 어느 쪽도 다른 쪽에서 계산해 낼 수 없다(DMD-032). 표현 문서를 못 읽으면 의미 문서를 덮어쓰지 말고 실패를 알린다 — 그게 실제 데이터 손실 버그였다.

### 9.12 백테스트 결과와 방 점수는 섞이지 않는다

공식 백테스트 결과가 대회 방의 실시간 점수에 들어가서는 안 된다. INT04의 명시 확인 항목이다.
