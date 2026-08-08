# INT02 — 최초 DB 구축·migration rehearsal

카드 문구: "빈 PostgreSQL 과 직전 release snapshot 모두에서 migration, 권한과 rollback 절차를
검증한다."

`docs/evidence/INT02-partial.md` 와 `INT02-aws.md` 를 대체하지 않고 이어받는다. 두 파일은 그때
관찰한 값을 그대로 담고 있으므로 남겨 둔다. 이 파일은 남아 있던 세 항목을 마무리한다.

## 언제 · 어디서

- 2026-08-08
- 로컬: Docker(`postgres:16-alpine`, `redgate/flyway:11-alpine`)
- AWS: Development(`418553863687`, `ap-northeast-2`), RDS `idea2strategy-dev-postgres`,
  데이터베이스 `idea2strategy_runtime`
- 루트: `9cd194f`. 서브모듈 `backend 9eabcb1`, `backtest-engine 5613ce4`,
  `data-pipeline 89bc34e`, `trading-engine f806f0c`, `ui 3d121dd`
- 번들: `4100bd4de19f0537cacf9b77935ec8cef14b1dbee7b573fa027c946b9c33b51d`

---

# 1. 빈 PostgreSQL — 통과

```powershell
.\scripts\test-flyway-ci-bundle.ps1
```

```json
{"status":"passed","application_tables":179,"successful_migrations":53,"second_run_pending":0,
 "partial_fill_allocation_contract":"passed","trading_read_projection_contract":"passed",
 "runtime_grants_contract":"passed",
 "bundle_sha256":"4100bd4de19f0537cacf9b77935ec8cef14b1dbee7b573fa027c946b9c33b51d",
 "backend_revision":"9eabcb1e7b1e57fb70b24c12c2f27e6e89a3965e",
 "backtest_revision":"5613ce4f0ad49e45c644ad39da2f1643a040c952",
 "trading_revision":"f806f0cc272e7d9a172c58768cab196086f03a2f",
 "postgres":"16-alpine","flyway":"11-alpine"}
```

179 테이블, 53 마이그레이션, **두 번째 migrate 에서 pending 0**. 권한 쪽은
`runtime_grants_contract` 가 담당하고, 계약 둘(partial-fill allocation, trading read
projection)도 같이 통과한다.

오늘 이 시험을 네 번 돌렸다(포인터 변경마다 한 번). 네 번 모두 같은 값이다.

---

# 2. 권한(런타임 롤) — 통과

로컬은 위 `runtime_grants_contract` 가 검증한다. AWS 쪽은 부트스트랩 수령증이
`login_roles: 5` 를 기록한다 — `idea2strategy_backend_runtime`,
`_batch_runtime`, `_backtest_runtime`, `_trading_runtime`, `_pipeline_runtime` 다.

각 롤의 비밀번호 버전도 수령증에 있고(`secret_versions`), 릴리스의
`verify-development-database-bootstrap-receipt.ps1` 이 그 값이 현재 시크릿 버전과 같은지
매번 확인한다(`receipt_secret_versions_current: true`).

---

# 3. AWS RDS 리허설 — 통과

`INT02-aws.md` 는 릴리스 실행의 `bootstrap-database` 성공을 근거로 삼았는데, 그 실행은
`"reused": true` 였다. **재사용은 적용이 아니다.** 그러므로 그 실행은 이 항목을 덮지 않는다.

실제 적용은 루트 `5b11c2e7` 의 부트스트랩이며, 그 수령증을 이번에 직접 읽었다.

```powershell
aws s3 cp s3://idea2strategy-dev-418553863687-market-data/deployment-bootstrap/artifacts/`
23a582092b1658cc87c1f016ea8686c406145e097ef961a319aff5eafa4d3c9a/receipt.json - `
  --profile idea2strategy-terraform --region ap-northeast-2
```

수령증에서 그대로:

| 항목 | 값 |
| --- | --- |
| `status` | `passed` |
| `root_sha` | `5b11c2e76b4ccbc5df0c49bda5e8b65c6e4ca9d0` |
| `bundle_sha256` | `4100bd4de19f0537…` — **§1 로컬 증명과 같은 번들** |
| `database_name` | `idea2strategy_runtime` |
| `migrations` | **53** |
| `tables` | **179** |
| `login_roles` | **5** |
| `instrument_count` | 625 |
| `flyway_image` | `redgate/flyway@sha256:52cdd559…` (다이제스트 고정) |
| `policy_row_counts` | fee 1, buffer 1, execution 1 |
| `scoring_versions` | 4종(COMPOSITE_BALANCED, SINGLE_MAX_DRAWDOWN, SINGLE_SHARPE, SINGLE_TOTAL_RETURN) |

**같은 번들이 로컬과 AWS RDS 에서 같은 결과를 낸다** — 53 마이그레이션, 179 테이블. 이것이 이
항목이 요구한 것이다.

`flyway_image` 가 태그가 아니라 다이제스트로 고정되어 있다는 점도 기록해 둔다. 리허설과 실제
적용이 같은 Flyway 바이너리를 쓴다는 뜻이다.

## 이 항목에서 확인하지 못한 것

**테이블 행 수를 라이브로 조회하지 못했다.** RDS 는 VPC 안이라 이 기계에서 psql 이 닿지
않는다. 위 값은 부트스트랩이 스스로 검증해 기록한 것이다. 라이브 조회는 SSM Run Command 가
필요하고, 그것은 INT09(백업·복구·원장 대사)에서 어차피 하게 된다.

---

# 4. 직전 release snapshot 위에서의 마이그레이션 — 정의하고, 가드를 두었다

이 항목이 카드를 가장 오래 열어 두었다. 원장의 사유는 "v1.0 전이라 스냅샷 정의부터 필요" 였다.
정의를 확정했다.

**직전 릴리스 = 마지막으로 적용된 부트스트랩의 번들 상태다.** 저장소의 어느 커밋이 아니라
AWS 수령증의 `root_sha` 가 그것을 가리킨다. 지금은 `5b11c2e7` 이다.

그리고 그 상태에서 현재로 올라가는 경로를 시험하는 스크립트를 두었다.

```powershell
.\scripts\test-flyway-upgrade-rehearsal.ps1 -FromRef <직전 릴리스 커밋>
```

이전 번들을 빈 DB 에 적용 → 현재 번들을 그 위에 적용 → validate → 다시 migrate 해서 pending
0 확인 → **최종 상태가 새 설치와 수렴하는지** 비교(테이블 수, 성공 마이그레이션 수).

## 지금 이 시험이 무엇을 말하는가

```
.\scripts\test-flyway-upgrade-rehearsal.ps1 -FromRef 5b11c2e7
→ 5b11c2e7 의 마이그레이션 집합이 현재와 같다. 델타 0 리허설은 업그레이드 경로를
  증명하지 않으므로 거부한다.
```

**적용된 상태와 현재 번들이 같기 때문에 올라갈 델타가 없다.** 두 값이 실제로 같다 —
수령증의 `bundle_sha256` 과 현재 번들의 `bundle_sha256` 이 모두
`4100bd4de19f0537…` 이다.

그러므로 이 항목은 "아직 하지 않았다" 가 아니라 **"지금 시험할 대상이 존재하지 않는다"** 다.
새 마이그레이션을 담은 첫 릴리스가 나오는 순간 델타가 생기고, 그때 이 스크립트가 그것을
시험한다. 지어낸 스냅샷으로 통과 도장을 찍는 것보다 이 편이 정직하다.

## 그 사이에 이 시험이 실제로 잡은 것

만들면서 `-FromRef fcede15` 로 돌려 보니
`V20260808120000__backend_publish_production_backtest_resolutions.sql` 의 내용이 달랐다
(`8feaed28…` → `94ae5725…`).

**결함이 아니다.** 그 파일을 수정한 `3b17699` 이 `5b11c2e7` 의 조상이므로 AWS 는 수정된 버전만
적용했다.

```bash
git merge-base --is-ancestor 3b17699 5b11c2e7   # 조상이다
```

즉 아직 어디에도 적용되지 않은 마이그레이션을 고친 것이고 정당하다. 이 판정이 스크립트가
`-FromRef` 를 자동으로 고르지 않는 이유다 — "번들이 다른 가장 가까운 조상" 은 개발 중간
상태이고, 그것을 릴리스 경계로 착각하면 정당한 작업을 결함으로 신고한다.

같은 검사가 반대 경우도 잡는다. 수정 커밋이 적용된 루트의 조상이 **아니면** 적용된
마이그레이션이 나중에 수정된 것이고, 그때는 배포를 멈춰야 한다.

---

# 5. rollback 절차 — 문서로 존재한다

`docs/database-rollback-procedure.md`.

적용된 Flyway 마이그레이션은 불변이고 `undo` 스크립트도 두지 않으므로, 되돌리기는 스키마
되돌리기가 아니라 **스냅샷 복원**이다. 그래서 절차의 절반이 "무엇을 잃는지 먼저 센다" 에
쓰인다 — 복원은 그 시점 이후의 모든 쓰기를 버리고, 거기에 라이브 주문·체결·원장 항목이
포함된다.

문서가 근거로 삼은 설정값은 모두 `infra/terraform/environments/development/database.tf` 에서
읽었다.

| 항목 | 값 |
| --- | --- |
| `backup_retention_period` | 7 일 (PITR 포함) |
| `backup_window` | `18:00-18:30` UTC |
| `deletion_protection` | `true` |
| `skip_final_snapshot` | `false` |
| `copy_tags_to_snapshot` | `true` |
| `storage_encrypted` | `true` |
| `multi_az` | `false` — 복원 = 다운타임 |

## 통과하지 못한 것

**실제 복원을 수행하지 않았다.** 복원은 새 RDS 인스턴스를 만드는 일이고, 그 드릴은
INT09(백업·복구·원장 대사)의 몫이다. INT02 는 절차가 존재하고 각 단계의 전제가 확인되었기를
요구하며, 위 표가 그 확인이다.

INT09 에서 확인할 것 셋을 문서에 적어 두었다. 복원본이 스키마 검증을 통과하는가, 전환 후
애플리케이션이 도는가, 그리고 **전환 뒤 다음 Terraform apply 가 엔드포인트를 되돌리지
않는가.** 세 번째가 예상되는 실패 지점이다.

---

# 요약 — 카드를 닫는 근거

| 항목 | 상태 | 근거 |
| --- | --- | --- |
| 빈 PostgreSQL migration | 통과 | §1 — 179 테이블, 53 마이그레이션, 2회차 pending 0 |
| 런타임 권한 | 통과 | §2 — `runtime_grants_contract`, 수령증 `login_roles: 5` |
| AWS RDS 리허설 | 통과 | §3 — 같은 번들이 RDS 에서 같은 53/179 |
| 직전 release snapshot | 정의 완료 + 가드 | §4 — 델타 0. 첫 릴리스에서 자동으로 시험된다 |
| rollback 절차 | 문서 완료 | §5 — 드릴은 INT09 |

두 항목에 "실제로 돌리지 못한 것" 이 남아 있고 그것을 위에 명시했다. 남은 것은 둘 다
**대상이 아직 존재하지 않아서**이고(첫 릴리스 이전, 복원 대상 인스턴스 미생성), 어느 쪽도 이
카드에서 만들 수 있는 것이 아니다. 각각 첫 릴리스와 INT09 로 넘긴다.

## 부수 발견 — INT03·INT04 를 막던 것

이 카드를 하다가 로컬 조합이 실행 불가 상태였음을 알았다. 기록해 둔다.

**로컬 backend 이미지가 2026-08-05 빌드였다.** `/api/v1/auth/*`, `/api/v1/bots`,
`/api/v1/dashboard` 가 모두 404 였는데 그 코드가 없는 이미지였다. 라우팅 문제처럼 보이는
모양이라 오래 헤맬 수 있다.

다시 빌드하니 **기동 자체가 실패했다.** `.env.docker.example` 의 identity crypto 키 다섯 개가
전부 URL-safe Base64 인데 코드는 `Base64.getDecoder()`(표준)로 읽는다. 둘은 32바이트 미만이었다.
예시대로 새로 설치한 사람은 아무도 backend-api 를 띄울 수 없었다. PR #415 로 고쳤고, 고친 뒤
`/actuator/health` 200 과 `POST /api/v1/auth/signup` 202 를 확인했다.

**아직 남은 것:** 로컬에서 이메일 검증을 완료할 방법이 없다. 토큰은 인프로세스 이벤트로만
나가고, 받는 쪽 SES 설정에 `endpointOverride` 가 없어 LocalStack 을 가리킬 수 없으며,
`identity.email_verification_requests` 는 `token_digest` 만 저장한다. INT03·INT04 가 둘 다
인증된 계정을 필요로 하므로 별도 변경으로 잇는다.
