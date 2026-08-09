-- 감사 어휘 일관성 점검 (A90 / INT08).
--
-- 왜 필요한가
--
-- `operations.audit_events` 에는 봉투를 채우는 트리거가 없다. `outbox_messages` 는
-- `prepare_outbox_envelope_before_insert` 가 `payload_hash` 와 `producer_idempotency_key` 를
-- 한 곳에서 만들지만, 감사는 그렇지 않다 — 필수 필드 아홉 개가 전부 기본값 없이 NOT NULL 이고
-- **열 곳 이상의 어댑터가 직접 채운다.**
--
-- 그래서 누락은 일어나지 않는다(NOT NULL 이 막는다). 대신 일어나는 것은 **어휘의 분화**다.
-- 같은 사건을 한 곳은 `ACCOUNT_SANCTION_APPLY` 로, 다른 곳은 `SANCTION_APPLIED` 로 적으면
-- 제약은 통과하고 감사 검토는 두 사건을 다른 것으로 읽는다. 제약도 grep 도 그것을 잡지 못한다.
--
-- 이 질의는 판정하지 않는다. **읽을 사람에게 분포와 의심 지점을 보여 준다.** 어휘가 갈렸는지는
-- 사람이 판단한다.
--
-- 사용
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f db/reconciliation/audit-vocabulary.sql
--
-- AWS 에서는 RDS 가 VPC 안이므로 `idea2strategy-dev-core` 에서 SSM 으로 실행한다.
--
-- 표본이 작으면 아무것도 말해 주지 않는다. 마지막 섹션이 표본 크기를 함께 내므로, 행이 적을 때
-- "문제 없음" 으로 읽지 않는다.

\pset footer off

-- 1. action_type 분포. 같은 도메인 안에서 이름이 갈렸는지 눈으로 보는 것이 출발점이다.
SELECT '1. action_type' AS section,
       target_domain,
       action_type,
       count(*) AS events,
       count(DISTINCT actor_type) AS actor_types,
       min(occurred_at)::date::text AS first_seen,
       max(occurred_at)::date::text AS last_seen
  FROM operations.audit_events
 GROUP BY target_domain, action_type
 ORDER BY target_domain, count(*) DESC;

-- 2. reason_code 분포. action_type 하나에 이유 코드가 여럿인 것은 정상이다(거부 사유가 여러
--    가지일 수 있다). 반대로 **같은 이유를 다른 코드로 적는 것**이 문제다.
SELECT '2. reason_code' AS section,
       action_type,
       reason_code,
       count(*) AS events
  FROM operations.audit_events
 GROUP BY action_type, reason_code
 ORDER BY action_type, count(*) DESC;

-- 3. 의심 지점: 같은 도메인 안에서 접두가 같은 action_type 이 둘 이상.
--    예) OPERATOR_RBAC_READ_SELF 와 OPERATOR_RBAC_READ_CATALOG 는 정상적인 분화지만,
--        OPERATOR_RBAC_GRANT 와 OPERATOR_RBAC_GRANTED 가 함께 있으면 어휘가 갈린 것이다.
--    기계가 판정할 수 없으므로 **후보만** 내놓는다.
WITH prefixed AS (
    SELECT DISTINCT
           target_domain,
           action_type,
           split_part(action_type, '_', 1) || '_' || split_part(action_type, '_', 2) AS prefix
      FROM operations.audit_events
)
SELECT '3. 같은 접두 후보' AS section,
       target_domain,
       prefix,
       count(*) AS variants,
       string_agg(action_type, ' | ' ORDER BY action_type) AS action_types
  FROM prefixed
 GROUP BY target_domain, prefix
HAVING count(*) > 1
 ORDER BY count(*) DESC;

-- 4. 의심 지점: 과거형·현재형이 섞였는지. 같은 동작을 ...APPLY 와 ...APPLIED 로 적는 것이
--    가장 흔한 분화다.
SELECT '4. 시제 혼용 후보' AS section,
       a.action_type AS form_a,
       b.action_type AS form_b
  FROM (SELECT DISTINCT action_type FROM operations.audit_events) a
  JOIN (SELECT DISTINCT action_type FROM operations.audit_events) b
    ON b.action_type = a.action_type || 'D'
    OR b.action_type = a.action_type || 'ED'
    OR b.action_type = rtrim(a.action_type, 'E') || 'ED'
 WHERE a.action_type <> b.action_type
 ORDER BY 2;

-- 5. 보증 근거의 부재를 눈에 보이게 한다.
--    감사 행에 auth_time 이나 MFA 나이가 없으므로, "이 행위가 신선한 MFA 에 근거했는가" 를
--    사후에 답할 수 없다. 그 사실을 컬럼 목록으로 보여 준다 — INT08 항목이다.
SELECT '5. 보증 관련 컬럼' AS section,
       string_agg(column_name, ', ' ORDER BY ordinal_position) AS columns
  FROM information_schema.columns
 WHERE table_schema = 'operations' AND table_name = 'audit_events'
   AND (column_name ILIKE '%auth%' OR column_name ILIKE '%mfa%'
        OR column_name ILIKE '%assur%' OR column_name ILIKE '%session%');

-- 6. 표본 크기. 위 결과를 읽기 전에 이것을 본다 — 행이 적으면 "갈리지 않았다" 가 아니라
--    "아직 볼 것이 없다" 다.
SELECT '6. 표본' AS section,
       (SELECT count(*) FROM operations.audit_events) AS total_events,
       (SELECT count(DISTINCT action_type) FROM operations.audit_events) AS action_types,
       (SELECT count(DISTINCT target_domain) FROM operations.audit_events) AS target_domains,
       (SELECT count(DISTINCT actor_id) FROM operations.audit_events) AS actors,
       (SELECT coalesce(min(occurred_at)::date::text, '(없음)') FROM operations.audit_events) AS first_day,
       (SELECT coalesce(max(occurred_at)::date::text, '(없음)') FROM operations.audit_events) AS last_day;
