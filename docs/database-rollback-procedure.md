# 데이터베이스 되돌리기 절차

## 되돌리기는 스키마를 되돌리는 것이 아니다

적용된 Flyway 마이그레이션은 불변이다. `undo` 스크립트도 두지 않는다. 그러므로 잘못된
릴리스를 되돌리는 방법은 **스냅샷 복원**이며, 그것은 데이터를 그 시점으로 되감는 일이다.

이 구분이 절차 전체를 정한다. 스키마만 되돌리는 것이라면 "마이그레이션 하나 취소" 로 끝나지만,
스냅샷 복원은 복원 시점 이후에 들어온 **모든 쓰기를 버린다**. 라이브 주문·체결·원장 항목이
포함된다. 그래서 아래 절차의 절반이 "무엇을 잃는지 먼저 확정한다" 에 쓰인다.

## 먼저 되돌리지 않는 길을 확인한다

복원은 마지막 수단이다. 그 전에 두 가지를 본다.

**하나 — 앞으로 고칠 수 있는가.** 마이그레이션은 불변이지만 **새 마이그레이션을 더할 수는
있다.** 잘못 만든 제약을 풀거나, 틀린 seed 행을 고치거나, 컬럼을 다시 채우는 일은 거의 항상
다음 마이그레이션으로 해결된다. 데이터 손실이 0 이므로 가능하면 이 길로 간다.

**둘 — 애플리케이션만 되돌리면 되는가.** 스키마 변경이 하위 호환이면(컬럼 추가, 테이블 추가,
nullable 확대) 이전 이미지가 새 스키마 위에서 그대로 돈다. 그 경우 릴리스 파이프라인으로
이미지 digest 만 앞 릴리스로 되돌리면 끝이고 데이터베이스는 손대지 않는다.

**복원이 필요한 경우는 좁다** — 마이그레이션이 데이터를 파괴적으로 바꿨고(컬럼 삭제, 손실 있는
타입 변경, 되돌릴 수 없는 백필), 그 결과가 이미 커밋되었을 때다.

## 현재 갖춰진 것

`infra/terraform/environments/development/database.tf` 기준.

| 항목 | 값 | 뜻 |
| --- | --- | --- |
| `backup_retention_period` | `7` 일 (`var.rds_backup_retention_days`) | 자동 백업과 PITR 보존 7일 |
| `backup_window` | `18:00-18:30` UTC | 자동 스냅샷 창 |
| `deletion_protection` | `true` (`var.rds_deletion_protection`) | 실수로 인스턴스를 지울 수 없다 |
| `skip_final_snapshot` | `false` | 인스턴스를 지우면 최종 스냅샷을 남긴다 |
| `copy_tags_to_snapshot` | `true` | 스냅샷이 태그를 물려받는다 |
| `storage_encrypted` | `true` | 복원본도 암호화된다 |
| `multi_az` | `false` | Development 는 단일 AZ. 복원 = 다운타임 |

보존 7일이 곧 되돌릴 수 있는 창이다. 7일보다 오래된 시점으로는 돌아갈 수 없다.

`multi_az = false` 이므로 복원 중 서비스는 내려간다. Development 에서는 감수하지만, 운영
환경으로 이 절차를 옮길 때 가장 먼저 바뀌어야 할 값이다.

## 릴리스 직전 스냅샷 — 왜 자동 백업으로 부족한가

자동 백업의 창은 `18:00-18:30` UTC 하루 한 번이다. 릴리스를 그 창 밖에서 하면, 가장 가까운
자동 스냅샷이 최대 24시간 전일 수 있다. PITR 로 임의 시점을 고를 수는 있으나 PITR 복원은
느리고, "릴리스 직전" 이라는 시점을 사람이 초 단위로 기억하지 못한다.

그래서 **파괴적 마이그레이션을 포함한 릴리스는 직전에 수동 스냅샷을 만든다.** 수동 스냅샷은
보존 기간에 묶이지 않으므로 7일 뒤에도 남는다.

```bash
aws rds create-db-snapshot \
  --db-instance-identifier idea2strategy-dev-postgres \
  --db-snapshot-identifier idea2strategy-dev-prerelease-<루트-SHA-앞7자리> \
  --region ap-northeast-2
aws rds wait db-snapshot-available \
  --db-snapshot-identifier idea2strategy-dev-prerelease-<루트-SHA-앞7자리> \
  --region ap-northeast-2
```

스냅샷 이름에 루트 커밋 SHA 를 넣는 것이 요점이다. 나중에 "어느 릴리스 전으로 돌아가는가" 를
추측하지 않아도 된다.

## 복원 절차

### 1. 무엇을 잃는지 확정한다

복원 대상 시점 `T` 를 정하고, `T` 이후에 들어온 쓰기를 센다. 최소한 다음 넷은 반드시 본다 —
버리면 사용자에게 보이는 것들이다.

```sql
SELECT count(*) FROM trading.orders            WHERE created_at > '<T>';
SELECT count(*) FROM trading.executions        WHERE created_at > '<T>';
SELECT count(*) FROM operations.outbox_messages WHERE created_at > '<T>';
SELECT count(*) FROM identity.accounts          WHERE created_at > '<T>';
```

**하나라도 0 이 아니면 복원은 제품 판단이다.** 에이전트나 배포 담당자가 단독으로 결정하지
않는다. 숫자를 그대로 적어 제품 권한자에게 올린다.

### 2. 새 인스턴스로 복원한다 — 기존 인스턴스를 덮지 않는다

RDS 는 제자리 복원을 하지 않고, 하려 해도 해서는 안 된다. 잘못된 시점을 골랐을 때 원본이
남아 있어야 다시 시도할 수 있다.

```bash
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier idea2strategy-dev-postgres-restore \
  --db-snapshot-identifier <스냅샷-ID> \
  --db-subnet-group-name <원본과 같은 서브넷 그룹> \
  --vpc-security-group-ids <원본과 같은 SG> \
  --no-publicly-accessible \
  --region ap-northeast-2
```

임의 시점으로 가려면 스냅샷 대신 PITR 을 쓴다.

```bash
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier idea2strategy-dev-postgres \
  --target-db-instance-identifier idea2strategy-dev-postgres-restore \
  --restore-time '<T ISO8601 UTC>' \
  --db-subnet-group-name <원본과 같은 서브넷 그룹> \
  --vpc-security-group-ids <원본과 같은 SG> \
  --no-publicly-accessible \
  --region ap-northeast-2
```

서브넷 그룹과 보안 그룹을 원본과 같게 두는 이유는, 복원본이 같은 VPC 안에 있어야 애플리케이션이
닿고 또 인터넷에 노출되지 않기 때문이다. `--no-publicly-accessible` 을 빼지 않는다.

### 3. 복원본을 검증한다 — 전환 전에

복원본이 기대한 스키마인지 먼저 본다. 잘못된 스냅샷을 골랐다면 여기서 드러난다.

```sql
SELECT count(*) FROM flyway_schema_history WHERE success;   -- 기대한 릴리스의 마이그레이션 수
SELECT count(*) FROM information_schema.tables
  WHERE table_schema IN ('identity','strategy','bot','storage','market_data',
                         'trading','backtest','performance','competition','operations')
    AND table_type = 'BASE TABLE';
SELECT max(installed_on) FROM flyway_schema_history;        -- 복원 시점과 맞는가
```

런타임 롤이 복원본에도 있는지 확인한다. 스냅샷은 롤을 포함하지만, 시크릿의 비밀번호가 그
사이 회전되었다면 접속이 실패한다.

```sql
SELECT rolname FROM pg_roles WHERE rolcanlogin AND rolname LIKE 'idea2strategy%' ORDER BY rolname;
```

### 4. 전환한다

애플리케이션이 보는 엔드포인트를 복원본으로 바꾼다. 이 저장소는 DB 호스트를 SSM 파라미터로
주므로, 그 값을 바꾸고 런타임을 재기동한다.

```bash
aws ssm put-parameter --name /idea2strategy/dev/database/host \
  --value <복원본 엔드포인트> --overwrite --region ap-northeast-2
```

그다음 서비스를 재기동한다. Terraform 이 이 파라미터를 관리하므로, 다음 `apply` 가 값을
되돌리지 않도록 **같은 변경에서 Terraform 입력도 함께 맞춘다.** 이것을 빼먹으면 다음 릴리스가
조용히 옛 인스턴스로 되돌린다 — 되돌리기가 되돌려지는 가장 흔한 방식이다.

### 5. 정리

- 원본 인스턴스는 **최소 보존 기간 동안 남긴다.** 복원 판단이 틀렸을 때 유일한 되돌릴 길이다.
- 지울 때도 `deletion_protection` 을 끄고 최종 스냅샷을 남긴다(`skip_final_snapshot=false`
  가 이미 그렇게 되어 있다).
- 복원 시점, 버린 행 수, 승인한 사람, 전환 시각을 기록한다. INT09(백업·복구·원장 대사) 의
  증거가 된다.

## 이 절차의 상태

**문서로만 존재하고 실제 복원은 수행하지 않았다.** 복원은 새 RDS 인스턴스를 만드는 일이라
비용과 시간이 들고, 실제 드릴은 INT09(백업·복구·원장 대사) 의 몫이다. INT02 는 이 절차가
존재하고 각 단계의 전제가 확인되었음을 요구한다 — 위 표의 설정값은 모두 트래킹되는 Terraform
소스에서 읽은 것이다.

INT09 에서 드릴을 돌릴 때 확인할 것은 셋이다. 복원본이 3단계 검증을 통과하는가, 4단계 전환
후 애플리케이션이 정상 동작하는가, 그리고 **전환 뒤 다음 Terraform apply 가 엔드포인트를
되돌리지 않는가.** 세 번째가 이 문서가 예상하는 실패 지점이다.

## 스키마 되돌리기가 필요해 보일 때

거의 항상 새 마이그레이션이 답이다. 그런데도 되돌려야 한다고 판단되면 그것은 마이그레이션
설계가 파괴적이었다는 뜻이므로, 복원과 별개로 그 마이그레이션을 기록에 남긴다. `db/schema.dbml`
이 정본이고 적용된 마이그레이션은 불변이라는 규칙은 복원 뒤에도 그대로다 — 복원했다고 해서
그 마이그레이션 파일을 지우거나 고치지 않는다. 지우면 다음 새 설치와 복원본이 갈린다.
