-- Publishes the disclosure a customer reads before delegating Basic strategy editing
-- to an external tool.
--
-- identity.delegated_authorizations.disclosure_policy_document_id is NOT NULL with a
-- foreign key here, and this table had no rows and no migration that wrote one, so no
-- delegation could ever be granted. The text is the product decision that unblocks it:
-- what the delegation permits, what it can never do, that every change is reviewed as a
-- preview first, and that it expires and can be revoked.
--
-- The hash is computed from the stored text rather than pasted in, so the two cannot
-- drift apart in this migration or in review.

INSERT INTO identity.policy_documents (
    policy_code,
    version,
    language_code,
    title,
    content_format,
    content_text,
    content_hash,
    is_required,
    published_at
)
SELECT
    'delegation.strategy-edit.disclosure',
    'v1',
    'ko',
    '외부 도구에 전략 편집을 위임합니다',
    'MARKDOWN',
    body,
    encode(sha256(convert_to(body, 'UTF8')), 'hex'),
    -- Not a required consent. is_required drives RequiredPolicySet, which every account must
    -- satisfy to complete authentication; a customer who never delegates must never be asked
    -- for this. It is disclosed at the moment a delegation is granted.
    false,
    TIMESTAMPTZ '2026-08-09 00:00:00+00'
FROM (
    SELECT $doc$# 외부 도구에 전략 편집을 위임합니다

이 위임을 만들면 선택한 외부 도구가 회원님을 대신해 다음을 할 수 있습니다.

- 지정한 전략의 **Basic 블록을 추가·삭제·연결하고 값을 바꾸는 것**
- (검증 범위를 함께 준 경우) 그 전략을 검증하는 것

이 위임으로 **할 수 없는 것**은 다음과 같습니다.

- 주문·체결, 자금 이동, 봇 실행이나 중단
- 전략 출시
- 지정하지 않은 다른 전략의 열람이나 편집
- 임의 코드 실행, 외부 데이터 가져오기

도구가 전략을 바꾸려면 **먼저 변경 내용을 미리보기로 제시**해야 하고, 그 미리보기와 정확히 같은 내용만 반영됩니다. 다른 내용으로 바꿔치기할 수 없습니다.

이 위임에는 **만료 시각**이 있으며, 그 전에도 언제든 회수할 수 있습니다. 회수하면 즉시 효력을 잃습니다.

위임 생성·사용·회수 기록은 회원님의 계정 활동에 남습니다.
$doc$ AS body
) AS published
WHERE NOT EXISTS (
    SELECT 1
    FROM identity.policy_documents
    WHERE policy_code = 'delegation.strategy-edit.disclosure'
      AND version = 'v1'
      AND language_code = 'ko'
);
