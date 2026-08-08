# INT09 — 복구 드릴 결과: 복원한 데이터베이스에 접속할 수 없다

INT09 완료 증거가 **아니다**. 원장이 INT09 를 완료로 세는 파일은 `docs/evidence/INT09.md` 이고,
이 파일은 드릴에서 나온 결과와 그 때문에 카드가 아직 닫히지 않는 이유를 적는다.

## 언제 · 어디서 · 무엇을 썼는가

- 2026-08-08. AWS Development(`418553863687`, `ap-northeast-2`).
- 원본 `idea2strategy-dev-postgres` (`db.t4g.small`, 20GB gp3, single-AZ).
- 스냅샷 `rds:idea2strategy-dev-postgres-2026-08-07-18-04` (자동, 암호화).
- 복원본 `idea2strategy-dev-postgres-restore` — 같은 서브넷 그룹·보안 그룹,
  `--no-publicly-accessible`, `--no-deletion-protection`,
  태그 `Purpose=int09-restore-drill`, `Ephemeral=true`.
- 검증은 VPC 안에서 SSM Run Command 로 수행했다. RDS 는 VPC 안이라 로컬에서 닿지 않는다.
- 실제 비용: 인스턴스가 약 25분 존재했다. `db.t4g.small` + 20GB 기준 **$0.05 미만**.
  드릴 종료 시 삭제했다(아래 §정리).

## 백업이 실제로 있다 — 실측

```
RDS idea2strategy-dev-postgres
  BackupRetentionPeriod  7
  PreferredBackupWindow  18:00-18:30 (UTC)
  DeletionProtection     true
  MultiAZ                false
  LatestRestorableTime   2026-08-08T11:03:23Z   ← 조회 3분 전. PITR 이 살아 있다.
자동 스냅샷 5일치 (08-03 ~ 08-07) 전부 status=available, Encrypted=true
S3 idea2strategy-dev-418553863687-market-data   Versioning: Enabled
```

`LatestRestorableTime` 이 조회 직전이라는 것이 중요하다. 보존 설정만 켜져 있고 실제로는 트랜잭션
로그가 쌓이지 않는 경우가 있는데, 이 값이 그것을 배제한다.

## 복원 자체는 문제없다

```
20:20:43 creating
20:23:51 configuring-enhanced-monitoring
20:24:53 backing-up
20:25:55 modifying
20:26:57 rebooting
20:27:59 available     ← 약 8분
엔드포인트 idea2strategy-dev-postgres-restore.…rds.amazonaws.com (10.20.11.144)
```

8분이면 RTO 4시간 목표(`decision.operations.slo`)에 여유가 크다.

## 그런데 복원본에 접속할 수 없다

애플리케이션 자격증명으로 붙지 않는다. 같은 자격증명이 **라이브에는 붙는다** — 대조군을 같은
명령 안에서 함께 돌렸다.

```
-- restored instance --
psql: error: … FATAL:  password authentication failed for user "idea2strategy_backend_runtime"

-- live instance (same credential, control) --
1
```

원인은 추측하지 않고 확인했다.

| | 시각 (UTC) |
| --- | --- |
| 스냅샷 생성 | `2026-08-07T18:04:09Z` |
| 런타임 시크릿 5개 마지막 변경 | `2026-08-08T02:28:4x~5xZ` |

`backend-runtime`, `batch-runtime`, `backtest-runtime`, `trading-runtime`,
`pipeline-runtime` **다섯 개가 모두** 스냅샷 이후에 바뀌었다. 시각이 루트 `5b11c2e7` 의
데이터베이스 부트스트랩과 일치한다(같은 실행의 수령증이 `rights_expires_at` 를
`2026-09-07T02:28:53Z` 로 기록한다).

즉 **데이터베이스 부트스트랩이 런타임 롤 비밀번호를 회전시킨다.** 스냅샷 안의 롤은 회전 이전
비밀번호를 들고 있고, Secrets Manager 는 회전 이후 값을 들고 있다. 그래서 복원본과 시크릿이
서로 맞지 않는다.

## 이것이 왜 중대한가

**복원이 성공해도 서비스가 살아나지 않는다.** 데이터는 온전한데 어느 런타임도 접속할 수 없으므로,
복구 절차에 자격증명을 맞추는 단계가 없으면 장애 상황에서 그 자리에서 막힌다. RTO 를 4시간으로
잡아 두었지만, 이 단계를 처음 겪으면서 알아내는 시간은 그 예산 안에 들어 있지 않다.

`docs/database-rollback-procedure.md` 3단계에 "시크릿의 비밀번호가 그 사이 회전되었다면 접속이
실패한다" 는 주의를 적어 두었다. 드릴이 그것을 **가정이 아니라 실제로** 확인했고, 주의로 남길
것이 아니라 필수 단계여야 한다는 것도 함께 보여 주었다.

## 원장 대사는 복원본에서 수행하지 못했다

이것이 이 카드를 닫지 못하는 지점이다.

`scripts/reconcile-trading-ledger.ps1` 과 `db/reconciliation/trading-ledger.sql` 의 본래 용도가
바로 복원본이다. `trading.ledger_entries` 의 균형 트리거는 `DEFERRABLE INITIALLY DEFERRED` 라
커밋 시점에만 돌고, 복원은 트리거를 다시 돌리지 않는다 — 복원된 원장의 균형은 아직 아무것도
검증한 적이 없다.

그런데 위 인증 실패로 복원본에 질의를 보낼 수 없었다. 붙으려면 복원본의 롤 비밀번호를 현재
시크릿에 맞춰 다시 설정해야 하고, 그것은 **마스터 자격증명**을 요구한다. 마스터 시크릿은
설계상 EC2 롤도 읽을 수 없다.

```
User: …assumed-role/idea2strategy-dev-service-ec2-role/i-044… is not authorized to perform:
secretsmanager:GetSecretValue on resource: …secret:rds!db-44df2634-…
```

이 거부는 옳다 — 애플리케이션 호스트가 마스터 자격증명을 읽을 이유가 없다. 다만 그 결과로
**에이전트가 이 드릴을 끝까지 수행할 수 없다.** 마스터 자격증명을 다루는 일은 사람이 한다.

## 남은 일 (담당 `kcrmin`)

1. 복원본을 다시 만든다(같은 명령, 약 8분).
2. 마스터 자격증명으로 복원본에 접속해 런타임 롤 다섯 개의 비밀번호를 현재 시크릿 값과 맞춘다.
   `scripts/aws/development-database-bootstrap.sh` 의 런타임 자격증명 단계가 하는 일과 같으므로,
   그 경로를 복원본에 겨누는 것이 가장 안전하다 — 손으로 `ALTER ROLE` 하지 않는다.
3. 복원본에 원장 대사를 돌린다.
   ```powershell
   .\scripts\reconcile-trading-ledger.ps1 -DatabaseUrl <복원본 연결 문자열>
   ```
   현재 원장이 비어 있으면 `vacuous` 가 나온다. 그 경우는 INT03·INT04 가 거래를 만든 뒤에
   다시 돌려야 의미가 있다.
4. 스키마 대조: 성공 마이그레이션 53, application 테이블 179, 로그인 롤 5.
5. 복원본 삭제 후 `docs/evidence/INT09.md` 를 쓴다.

## 절차 문서에 반영해야 할 것

`docs/database-rollback-procedure.md` 3단계의 주의를 **필수 단계로 올린다.** 문구는 이
드릴에서 나온 사실을 그대로 쓴다 — 부트스트랩이 런타임 롤 비밀번호를 회전시키므로, 부트스트랩
이전에 뜬 스냅샷은 현재 시크릿으로 접속할 수 없다. 별도 변경으로 넣는다.

## 정리

```
aws rds delete-db-instance --db-instance-identifier idea2strategy-dev-postgres-restore \
  --skip-final-snapshot --delete-automated-backups
→ status: deleting
```

원본은 건드리지 않았다. 엔드포인트 전환도 하지 않았으므로 개발 환경은 드릴 내내 정상이었다.
`deletion_protection` 이 원본에 켜져 있어 실수로 지울 수도 없었다.

## 통과하지 못한 것 — 요약

| 항목 | 상태 |
| --- | --- |
| 백업 존재·유효성 | 통과 (실측) |
| PITR 살아 있음 | 통과 (`LatestRestorableTime` 3분 전) |
| 스냅샷 복원 가능 | 통과 (8분) |
| 복원본 접속 | **실패 — 자격증명 회전 때문** |
| 복원본 스키마 대조 | 미수행 (접속 실패로 차단) |
| 복원본 원장 대사 | 미수행 (접속 실패로 차단) |
| 엔드포인트 전환 후 Terraform plan 확인 | 미수행 (접속부터 막혀 진행하지 않음) |

앞의 세 개가 통과했고 뒤의 넷이 한 원인으로 막혔다. 그 원인이 이 드릴의 결과물이다.
