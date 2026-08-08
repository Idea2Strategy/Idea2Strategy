-- 거래 원장 대사 (INT09).
--
-- 왜 이것이 제약과 중복이 아닌가
--
-- `trading.ledger_entries` 에는 `ledger_entry_balanced_deferred` 트리거가 있고
-- `ledger_transactions` 에도 짝이 되는 것이 있다. 둘 다 DEFERRABLE INITIALLY DEFERRED 이므로
-- **커밋 시점에만** 검사한다. 즉 이미 저장된 행에는 아무 힘이 없다.
--
-- 그래서 다음 경우에 불균형이 조용히 남는다.
--   * 스냅샷 복원 -- 복원은 트리거를 다시 돌리지 않는다. 복원본의 균형은 검증된 적이 없다.
--   * `SET CONSTRAINTS ALL DEFERRED` 아래의 대량 적재나 마이그레이션
--   * 트리거가 존재하기 전에 들어간 행
--
-- INT09 가 백업·복구와 원장 대사를 한 카드로 묶은 이유가 이것이다. 복원한 원장이 여전히
-- 균형인지는 복원 뒤에 세어 봐야만 알 수 있다.
--
-- 사용
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f db/reconciliation/trading-ledger.sql
--
-- 출력은 검사당 한 행이며 `failures` 가 0 이 아니면 그 검사가 실패다. 마지막 행은
-- 표본 크기(`transaction_count`, `entry_count`)를 보고한다 -- **원장이 비어 있으면 모든
-- 검사가 0 이 되므로, 표본 크기를 보지 않고 통과로 읽으면 안 된다.**
-- scripts/reconcile-trading-ledger.ps1 이 그 판정을 대신 해 준다.

\pset footer off

WITH
-- 부호를 붙인 금액. DEBIT 을 +, CREDIT 을 - 로 둔다. 이중부기에서 한 거래의 합은 0 이다.
signed_entries AS (
    SELECT
        e.id,
        e.bot_id,
        e.partition_id,
        e.transaction_id,
        e.ledger_account_id,
        e.direction,
        e.amount,
        e.entry_hash,
        CASE WHEN e.direction = 'DEBIT' THEN e.amount ELSE -e.amount END AS signed_amount
    FROM trading.ledger_entries e
),

-- 1. 거래별 균형. 트리거가 커밋 시점에 보장했어야 하는 것.
transaction_imbalance AS (
    SELECT transaction_id, sum(signed_amount) AS net
    FROM signed_entries
    GROUP BY transaction_id
    HAVING sum(signed_amount) <> 0
),

-- 2. 봇별 균형. 거래별 균형이 모두 맞으면 자동으로 맞지만, 어긋나면 어느 봇이 영향받는지
--    알려 준다. 복구 판단에 필요한 정보다.
bot_imbalance AS (
    SELECT bot_id, sum(signed_amount) AS net
    FROM signed_entries
    GROUP BY bot_id
    HAVING sum(signed_amount) <> 0
),

-- 3. 헤더 없는 항목. FK 가 막지만 복원본에서는 재검증되지 않는다.
orphan_entries AS (
    SELECT s.id
    FROM signed_entries s
    LEFT JOIN trading.ledger_transactions t ON t.id = s.transaction_id
    WHERE t.id IS NULL
),

-- 4. 계정 없는 항목.
entries_without_account AS (
    SELECT s.id
    FROM signed_entries s
    LEFT JOIN trading.ledger_accounts a ON a.id = s.ledger_account_id
    WHERE a.id IS NULL
),

-- 5. 금액이 양수가 아닌 항목. 방향이 부호를 담으므로 금액 자체는 항상 양수여야 한다.
nonpositive_amounts AS (
    SELECT id FROM signed_entries WHERE amount IS NULL OR amount <= 0
),

-- 6. 되돌림 대상이 없는 되돌림 거래.
dangling_reversals AS (
    SELECT r.id
    FROM trading.ledger_transactions r
    LEFT JOIN trading.ledger_transactions o ON o.id = r.reversal_of_transaction_id
    WHERE r.reversal_of_transaction_id IS NOT NULL AND o.id IS NULL
),

-- 7. 되돌림이 원거래를 계정 단위로 정확히 뒤집는지. 합계만 0 이어도 계정별로 어긋나면
--    잔액이 계정 사이로 옮겨간 것이므로 대사가 실패해야 한다.
reversal_mismatch AS (
    SELECT r.id AS reversal_id
    FROM trading.ledger_transactions r
    JOIN trading.ledger_transactions o ON o.id = r.reversal_of_transaction_id
    WHERE EXISTS (
        SELECT 1
        FROM (
            SELECT ledger_account_id, sum(signed_amount) AS net
            FROM signed_entries WHERE transaction_id = r.id
            GROUP BY ledger_account_id
        ) rev
        FULL OUTER JOIN (
            SELECT ledger_account_id, sum(signed_amount) AS net
            FROM signed_entries WHERE transaction_id = o.id
            GROUP BY ledger_account_id
        ) orig ON orig.ledger_account_id = rev.ledger_account_id
        WHERE coalesce(rev.net, 0) <> -coalesce(orig.net, 0)
    )
),

-- 8. 항목의 통화가 그 계정의 통화와 다른 경우. 계정이 통화를 정하므로 어긋나면 서로 다른
--    통화를 한 잔액에 섞은 것이다.
currency_mismatch AS (
    SELECT s.id
    FROM signed_entries s
    JOIN trading.ledger_accounts a ON a.id = s.ledger_account_id
    JOIN trading.ledger_transactions t ON t.id = s.transaction_id
    WHERE btrim(a.currency_code) <> btrim(t.currency_code)
),

-- 9. 감사 해시가 없는 항목. 있어야 나중에 행이 바뀌었는지 판별할 수 있다.
missing_entry_hash AS (
    SELECT id FROM signed_entries WHERE entry_hash IS NULL OR btrim(entry_hash) = ''
),

-- 10. 닫힌 계정에 기록된 항목. 거래 시각을 기준으로 본다.
entries_after_close AS (
    SELECT s.id
    FROM signed_entries s
    JOIN trading.ledger_accounts a ON a.id = s.ledger_account_id
    JOIN trading.ledger_transactions t ON t.id = s.transaction_id
    WHERE a.closed_at IS NOT NULL AND t.occurred_at > a.closed_at
),

-- 11. 봇 파티션이 항목과 헤더 사이에서 어긋나는 경우. 복합 FK 가 막지만 복원본에서는
--     재검증되지 않으며, 어긋나면 한 봇의 원장이 다른 봇의 거래를 담는다.
partition_mismatch AS (
    SELECT s.id
    FROM signed_entries s
    JOIN trading.ledger_transactions t ON t.id = s.transaction_id
    WHERE s.bot_id <> t.bot_id OR s.partition_id IS DISTINCT FROM t.partition_id
)

SELECT check_name, failures, detail FROM (
    SELECT 1 AS ord, 'transaction_balanced'      AS check_name, (SELECT count(*) FROM transaction_imbalance)    AS failures, (SELECT coalesce(string_agg(transaction_id::text || ' net=' || net::text, '; '), '') FROM transaction_imbalance) AS detail
    UNION ALL SELECT 2, 'bot_balanced',            (SELECT count(*) FROM bot_imbalance),           (SELECT coalesce(string_agg(bot_id::text || ' net=' || net::text, '; '), '') FROM bot_imbalance)
    UNION ALL SELECT 3, 'no_orphan_entries',       (SELECT count(*) FROM orphan_entries),          (SELECT coalesce(string_agg(id::text, '; '), '') FROM orphan_entries)
    UNION ALL SELECT 4, 'entries_have_accounts',   (SELECT count(*) FROM entries_without_account), (SELECT coalesce(string_agg(id::text, '; '), '') FROM entries_without_account)
    UNION ALL SELECT 5, 'amounts_positive',        (SELECT count(*) FROM nonpositive_amounts),     (SELECT coalesce(string_agg(id::text, '; '), '') FROM nonpositive_amounts)
    UNION ALL SELECT 6, 'reversals_target_exists', (SELECT count(*) FROM dangling_reversals),      (SELECT coalesce(string_agg(id::text, '; '), '') FROM dangling_reversals)
    UNION ALL SELECT 7, 'reversals_mirror',        (SELECT count(*) FROM reversal_mismatch),       (SELECT coalesce(string_agg(reversal_id::text, '; '), '') FROM reversal_mismatch)
    UNION ALL SELECT 8, 'currency_agrees',         (SELECT count(*) FROM currency_mismatch),       (SELECT coalesce(string_agg(id::text, '; '), '') FROM currency_mismatch)
    UNION ALL SELECT 9, 'entry_hash_present',      (SELECT count(*) FROM missing_entry_hash),      (SELECT coalesce(string_agg(id::text, '; '), '') FROM missing_entry_hash)
    UNION ALL SELECT 10, 'no_entries_after_close', (SELECT count(*) FROM entries_after_close),     (SELECT coalesce(string_agg(id::text, '; '), '') FROM entries_after_close)
    UNION ALL SELECT 11, 'partition_agrees',       (SELECT count(*) FROM partition_mismatch),      (SELECT coalesce(string_agg(id::text, '; '), '') FROM partition_mismatch)
    -- 표본 크기. 실패 수가 아니라 세어 본 대상의 크기다. 0 이면 위의 0 들은 아무것도
    -- 증명하지 않는다.
    UNION ALL SELECT 90, 'sample_transaction_count', (SELECT count(*) FROM trading.ledger_transactions), ''
    UNION ALL SELECT 91, 'sample_entry_count',       (SELECT count(*) FROM trading.ledger_entries), ''
    UNION ALL SELECT 92, 'sample_bot_count',         (SELECT count(DISTINCT bot_id) FROM trading.ledger_entries), ''
) AS checks
ORDER BY ord;
