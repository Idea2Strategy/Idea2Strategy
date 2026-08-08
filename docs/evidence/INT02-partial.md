# INT02 — 최초 DB 구축·migration rehearsal

## 언제 · 어디서

- 2026-08-08
- 환경: 로컬 Docker (Docker Engine 29.6.2 / linux), PostgreSQL 16.14 컨테이너, Flyway 11.20.3
- 루트 커밋: `a74b4a5` (develop)
- gitlink: `backend 4afb611` · `backtest-engine 5613ce4` · `data-pipeline 509ba3a` · `trading-engine f806f0c` · `ui 4819725`

## 실행한 명령

```powershell
.\scripts\test-flyway-ci-bundle.ps1
.\scripts\test-development-database-bootstrap.ps1
cd backend; .\gradlew test --rerun-tasks
```

## 관찰한 결과

### 1. 빈 PostgreSQL 에 정본 번들 적용 — 통과

```json
{"status":"passed","application_tables":179,"successful_migrations":53,
 "second_run_pending":0,"partial_fill_allocation_contract":"passed",
 "trading_read_projection_contract":"passed","runtime_grants_contract":"passed",
 "bundle_sha256":"4100bd4de19f0537cacf9b77935ec8cef14b1dbee7b573fa027c946b9c33b51d",
 "postgres":"16-alpine","flyway":"11-alpine"}
```

- 빈 스키마에서 시작해 53개 마이그레이션이 순서대로 적용되고 애플리케이션 테이블 179개가 생겼다.
- `second_run_pending: 0` — 두 번째 실행이 아무것도 적용하지 않았다(멱등).
- `bundle_sha256` 가 커밋된 `db/flyway-ci-bundle/source-revisions.json` 의 값과 일치한다.
- 번들에 `V20260805153000__trading_add_candidate_batch_processing.sql` 이 포함되어 적용됐다.
  루트 #266 의 1번 항목(trading-worker 가 정본 DB 에서 Hibernate validate 실패)이 실제로
  해소되어 있음을 이 실행이 보인다.

### 2. 런타임 권한 — 통과

`runtime_grants_contract: passed`. 스크립트가 런타임 role 을 만들어 접근을 확인하고
(`CREATE ROLE` → `count 0` → `DROP ROLE`) 정리했다. 권한 baseline 이 적용된 스키마와 맞는다.

### 3. 부트스트랩 경계 계약 — 통과

```json
{"status":"passed","protected_secret_metadata":true,
 "terraform_secret_versions":false,"dedicated_bootstrap_boundary":true,"consumers":5}
```

### 4. backend 전체 테스트 (Docker 있는 상태) — 통과

```
BUILD SUCCESSFUL in 13m 35s
backend: tests=897 failures=0 skipped=0
```

이 값이 중요하다. Docker 가 없을 때는 같은 스위트가 **271건을 조용히 skip** 했고
(`@Testcontainers(disabledWithoutDocker = true)`), 그 271건이 전부 실제 PostgreSQL 을 쓰는
persistence 통합 테스트다. 이번 실행에서 skip 이 0 이 되었고 실패도 0 이다 — 즉 backend
persistence 계층이 정본 스키마에 대해 처음으로 전수 검증됐다.

## 통과하지 못한 것

**이 카드는 아직 완료가 아니다.** 카드 문구는 "빈 PostgreSQL과 직전 release snapshot 모두에서
migration, 권한과 rollback 절차를 검증한다" 인데, 위 증거는 앞의 두 개(빈 DB, 권한)만 덮는다.

1. **직전 release snapshot 위에서의 마이그레이션 — 미검증.** v1.0 이전이라 이전 릴리스
   스냅샷이 존재하지 않는다. 무엇을 스냅샷으로 볼지(예: 첫 AWS 부트스트랩 시점의 RDS
   스냅샷) 정하고 그 위에서 한 번 더 돌려야 한다. INT09(백업·복구)와 겹치는 부분이 있다.
2. **rollback 절차 — 미검증.** 적용된 Flyway 마이그레이션은 불변이므로 되돌리기는 스키마
   되돌리기가 아니라 스냅샷 복원이다. 그 절차가 문서로도 스크립트로도 아직 없다.
3. **AWS RDS 에서의 리허설 — 미검증.** 위는 전부 로컬 컨테이너다. AWS 경로는
   `scripts/aws/development-database-bootstrap.sh` 가 같은 커밋된 번들을 다이제스트 검증 후
   적용하도록 되어 있으나, 이번에 실행하지는 않았다.

## 부수 발견

Docker 를 켠 뒤 `data-pipeline` 의 integration 표식 테스트에서 **105 errors** 가 나왔다.
원인은 하나다 — vendored `central-migration` fixture 가 backend 중앙 세트(42개)가 아니라
조립된 번들에서 갱신되어 자기 기여인 `V20260808120100__pipeline_seed_production_rsi_timeframes.sql`
이 섞였고, `conftest._cross_check` 가 그것을 잡는다. Docker 가 없을 때는 이 테스트들이 skip
되어 보이지 않았다. 원장 작업 **2.7**(owner `pjy008008`)로 기록했다. backtest-engine 의 같은
결함은 root #70 에서 이미 고쳤다.
