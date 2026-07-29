# Performance schema PostgreSQL implementation requirements

상태: DBML 재설계 격리 제안. 제품 정본 승인 또는 운영 마이그레이션이 아니다.

## 현재 성과 Projection 순서 보장

`performance.bot_current_projections`는 일반 `UPDATE`를 허용하지 않는다. 애플리케이션 역할은 전용 PostgreSQL 함수만 호출하며, 함수는 다음 조건부 UPSERT와 동일한 의미를 보장한다.

```sql
ON CONFLICT (bot_id) DO UPDATE
SET ...
WHERE performance.bot_current_projections.last_event_sequence
    < EXCLUDED.last_event_sequence;
```

동일하거나 더 작은 `last_event_sequence`는 성공으로 멱등 처리하되 기존 행을 변경하지 않는다. Projection 재구축은 별도 운영 권한과 감사 사건으로만 수행한다.

## 불변 행 보호

`performance.bot_snapshots`와 `performance.series_manifests`는 생성 후 일반 `UPDATE`와 `DELETE`를 거절하는 trigger를 설치한다. 시계열 매니페스트는 S3 업로드와 객체 검증이 끝난 뒤 `available_at`을 포함한 완성 행으로 한 번만 삽입한다. 정정된 성과 파일은 기존 매니페스트를 변경하지 않고 같은 논리 파트의 `revision_number`를 증가시킨 새 행을 만들고 `supersedes_manifest_id`로 교체 계보를 남긴다.

## ET 주 경계 검증

`performance.series_manifests` INSERT trigger는 `period_start`와 `period_end`를 `America/New_York`로 변환하여 다음을 확인한다.

- `week_start_date`가 해당 ET 주의 월요일이다.
- 기간이 `week_start_date`부터 다음 월요일 직전까지의 범위를 넘지 않는다.
- `available_at` 설정 시 연결된 `storage.objects`가 검증 완료 상태이고 `series_hash`가 객체 내용 해시와 일치한다.
- `supersedes_manifest_id`가 있으면 직전 행과 봇·시계열 종류·주·파트가 같고 `revision_number`가 정확히 1 증가한다.

DBML의 행 내부 CHECK만으로 다른 테이블의 객체 상태·해시와 ET DST 경계를 완전하게 검증할 수 없으므로 이 항목은 migration trigger가 필요하다.

## 핵심 지표와 확장 문서

`equity_amount`, `total_return_pct`, `max_drawdown_pct`, `sharpe_ratio`는 정렬·필터·리더보드 계산에 사용하는 타입 컬럼이다. `metrics_document`에는 이 값들을 다시 복제하지 않고 실현 손익 등 확장 지표만 저장한다. `projection_hash`와 `snapshot_hash`는 타입 컬럼, 확장 문서, 입력 해시와 계산 규칙 버전을 모두 포함하여 계산한다.
