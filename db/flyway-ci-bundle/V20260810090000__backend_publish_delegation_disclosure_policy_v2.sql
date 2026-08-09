-- Widens the delegation disclosure to match a delegation that can now build a strategy
-- from nothing.
--
-- v1 promised block editing inside a strategy the customer had already shaped. ADD_GROUP
-- lets a delegated tool create the trade containers themselves, which decide the side, how
-- blocks combine, how capital is split, and which instruments are traded. That is more than
-- v1 disclosed, and a disclosure that understates the delegation is the failure this document
-- exists to prevent.
--
-- v1 is retired rather than edited: applied migrations are immutable, and a customer who
-- consented to v1 consented to v1. The grant path selects the newest published version for
-- the policy code, so it picks this up with no code change.
--
-- Both instants are one second after v1's publication and deliberately in the past. The
-- selecting query is `retired_at is null and published_at <= now()`, so a future timestamp
-- would retire v1 while v2 was not yet publishable and leave the policy code with no current
-- document at all — every delegation grant would fail with nothing published to point at.
-- CI caught exactly that.

UPDATE identity.policy_documents
SET retired_at = TIMESTAMPTZ '2026-08-09 00:00:01+00'
WHERE policy_code = 'delegation.strategy-edit.disclosure'
  AND version = 'v1'
  AND retired_at IS NULL;

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
    'v2',
    'ko',
    '외부 도구에 전략 편집을 위임합니다',
    'MARKDOWN',
    body,
    encode(sha256(convert_to(body, 'UTF8')), 'hex'),
    -- Still not a required consent: it is disclosed when a delegation is granted, never as a
    -- condition of authenticating. See V20260809140000.
    false,
    TIMESTAMPTZ '2026-08-09 00:00:01+00'
FROM (
    SELECT $doc$# 외부 도구에 전략 편집을 위임합니다

이 위임을 만들면 선택한 외부 도구가 회원님을 대신해 다음을 할 수 있습니다.

- 지정한 전략에 **매수·매도 컨테이너를 만드는 것**. 컨테이너를 만들 때 매수/매도 방향, 조건을 결합하는 방식, 자금을 배분하는 방식, 거래할 종목을 함께 정합니다
- 그 안의 **Basic 블록을 추가·삭제·연결하고 값을 바꾸는 것**
- (검증 범위를 함께 준 경우) 그 전략을 검증하는 것

즉 **빈 전략을 건네면 도구가 전략의 뼈대부터 만들 수 있습니다.**

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
      AND version = 'v2'
      AND language_code = 'ko'
);
