# E02 competition·performance DBML 정합성 제안

상태: 제품 권한 승인 전 격리 제안. `db/schema.dbml`이나 운영 migration이 아니다.

## 확인한 충돌

현재 canonical DBML과 기존 재설계 proposal은 `competition.leaderboard_snapshots`와 `competition.leaderboard_entries`에 공개 점수·순위를 다시 저장한다. 반면 E02 실행 기준은 이 과거 구조를 재검토해 필요한 최소 구조만 남기도록 요구한다. 승인된 제품 의미는 봇 전용 익명 비교, 종료 결과의 재현성과 감사 가능성을 요구하지만 별도 리더보드 영속 테이블은 요구하지 않는다.

E01 병합 구현은 `competition.rooms`, `competition.room_rules`, `competition.room_schedules`, `performance.bot_current_projections`만 소비한다. 따라서 proposal에서 리더보드 중복 테이블을 제거해도 E01 JPA·jOOQ 경계에는 변경이 없다.

## 제안하는 최소 구조

- LIVE_PAPER 공식 점수 근거: 불변 `performance.bot_snapshots`.
- BACKTEST 공식 점수 근거: 검증·공개된 `competition.backtest_aggregate_results`.
- 참가 자격과 익명 별칭: `competition.participations` 및 append-only 사건.
- 방 종료 기준: terminal Participation 집합, Room 사건과 고정된 `ended_at`.
- 현재·최종 리더보드: 위 원본을 조인해 점수 템플릿의 결정론적 정렬·동점 규칙으로 계산하는 Query projection.

캐시 또는 검색 문서는 허용하되 원본 해시와 마지막 반영 위치로 전부 재구축할 수 있어야 한다. 캐시는 채점·종료·감사의 정본이 아니다.

## 유지·삭제 판단

| 대상 | 제안 | 근거 |
| --- | --- | --- |
| `performance.bot_snapshots` | 유지 | LIVE_PAPER 경계 성과의 불변 공식 증거 |
| `competition.backtest_aggregate_results` | 유지 | BACKTEST의 검증된 단일 집계 결과와 공식 점수 증거 |
| `competition.leaderboard_snapshots` | 제거 | 원본 집합과 종료 시각을 다시 복제하며 갱신·무효화 경로를 추가함 |
| `competition.leaderboard_entries` | 제거 | 점수·근거·순위를 중복 저장해 원본과 불일치할 수 있음 |
| `competition.leaderboard_status` | 제거 | 제거되는 snapshot 테이블 전용 enum |

## Migration과 rollback 영향

이 변경은 proposal 단계라 migration을 만들지 않는다. canonical 적용 승인이 나면 중앙 Flyway 통합 리뷰어와 다음 순서로 별도 계획한다.

1. 실제 운영 데이터 존재 여부와 리더보드 테이블 consumer를 감사한다.
2. Query를 공식 원본 기반으로 전환하고 동일 순위 결과를 비교 검증한다.
3. 캐시를 비우고 원본에서 재구축되는지 확인한다.
4. consumer가 모두 전환되고 보존 요구가 해결된 뒤에만 중복 테이블과 enum 제거 migration을 실행한다.

rollback은 테이블 복원이 아니라 이전 애플리케이션 Query 경로를 비활성화하고 원본 기반 projection을 forward-fix하는 방식이 기본이다. 운영 중복 테이블에만 존재하는 데이터가 발견되면 삭제를 중단하고 별도 보존·backfill 계획을 승인받는다.

## 승인 전 제한

`user:kcrmin`의 정확한 repository·HEAD·protected fingerprint 승인이 확인되기 전에는 이 제안을 canonical `db/schema.dbml`, `specs/**`, `contracts/**` 또는 Flyway migration에 적용하지 않는다. 승인 후에도 `Juwon-Na`의 migration 순서·충돌 검토와 전체 DBML·backend 통합 검증이 필요하다.
