# INT02 (AWS) — 정본 런타임 DB 는 이미 최신이다

## 언제 · 어디서

- 2026-08-08
- 환경: AWS Development (`418553863687`, `ap-northeast-2`)
- 트리거: [development-release run 31249771785](https://github.com/Idea2Strategy/Idea2Strategy/actions/runs/31249771785)
  (`apply_reviewed_plan=false` — 배포하지 않음)
- 루트 커밋: `c4b78e7`

## 실행한 명령

```bash
gh workflow run development-release.yml --ref develop \
  -f release_authorization=PREPARE_DEVELOPMENT_RC \
  -f database_bootstrap_authorization=BOOTSTRAP_DEVELOPMENT_DATABASE \
  -f apply_reviewed_plan=false -f force_rebuild_all_images=false
```
```powershell
aws s3 cp s3://.../deployment-bootstrap/artifacts/23a5820.../receipt.json - --profile idea2strategy-terraform
```

## 관찰한 결과

`bootstrap-database` 잡 성공, `build` 잡 성공. 부트스트랩은 **기존 영수증을 재사용**했다:

```json
{"status":"passed","requested_root_sha":"c4b78e7f...","receipt_root_sha":"5b11c2e7...",
 "reused":true,"bundle_sha256":"4100bd4de19f0537...","migrations":53,
 "instrument_count":625,"rights_expires_at":"09/07/2026 02:28:53"}
```

영수증 본문(S3, 2026-08-08 02:29 UTC):

| 항목 | 값 |
| --- | --- |
| `migrations` | **53** |
| `tables` | **179** |
| `database_name` | **`idea2strategy_runtime`** |
| `root_sha` | `5b11c2e7` |
| `bundle_sha256` | `4100bd4d…` — **현재 develop 과 동일** |
| `login_roles` | 5 |
| `instrument_count` | 625 |

재사용은 지문이 일치했기 때문이며, 지문이 일치한다는 것은 **적용해야 할 것이 이미 적용되어
있다는 뜻**이다. 로컬에서 검증한 것과 같은 53개 마이그레이션, 같은 179개 테이블이다.

## 이 증거가 정정하는 것

`docs/evidence/2.4-aws-state.md` 는 "AWS RDS 가 최신 마이그레이션을 받지 않았다(
`feature_definitions` 가 1개)" 고 적었다. **틀렸다.** 그 수치는 2026-08-05 의
market-catalog 영수증에서 온 것이고, 그 영수증이 말하는 대상은 레거시 DB `idea2strategy` 다.
정본 런타임 DB 는 `idea2strategy_runtime` 이며 이쪽은 53개 마이그레이션이 적용되어 있다.

따라서 **2.5(지표 백필)의 선행 조건은 이미 충족되어 있다.** 프로덕션 RSI 정의 4종을 만드는
`V20260808120100__pipeline_seed_production_rsi_timeframes.sql` 이 53개 안에 포함된다.
백필을 막는 것은 마이그레이션이 아니라 백필 자체를 아직 돌리지 않은 것뿐이다.

종목 수도 다르다 — market-catalog 영수증은 725, 배포 부트스트랩 영수증은 625. 서로 다른
DB 를 세고 있으므로 모순이 아니다. 게이트웨이의 최소 요구치 500 은 양쪽 다 넘는다.

## 통과하지 못한 것

1. **테이블 행 수를 직접 조회하지 못했다.** RDS 는 VPC 안이라 이 기계에서 psql 이 닿지
   않는다. 위 값은 영수증이 기록한 것이며 부트스트랩이 검증한 값이다. 라이브 조회는 SSM
   Run Command 가 필요하다.
2. **`prepare-and-plan` 은 두 번째 환경 승인 대기 중이다.** Terraform plan 이 저장되면
   A91(배포 파이프라인)의 증거가 된다.
3. **rollback 절차와 직전 release snapshot 리허설은 여전히 미검증** —
   `docs/evidence/INT02-partial.md` 에 적은 그대로다. 이 실행은 "빈 DB 에서의 적용" 이 아니라
   "이미 적용된 상태의 확인" 이므로 그 두 항목을 덮지 않는다.
