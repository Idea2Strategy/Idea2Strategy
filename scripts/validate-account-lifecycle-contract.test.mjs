import { readFile } from "node:fs/promises";
import test from "node:test";
import assert from "node:assert/strict";

const dbml = await readFile(new URL("../db/schema.dbml", import.meta.url), "utf8");
const contract = await readFile(
  new URL("../docs/contracts/account-lifecycle-v1.md", import.meta.url),
  "utf8",
);

test("pins the approved account lifecycle state and deadline projections", () => {
  for (const fragment of [
    "DORMANT",
    "lifecycle_version bigint",
    "last_lifecycle_event_id uuid",
    "last_successful_auth_at timestamptz",
    "dormant_at timestamptz",
    "withdrawal_requested_at timestamptz",
    "cancellation_deadline_at timestamptz",
    "closing_previous_status identity.account_lifecycle_status",
    "closed_at timestamptz",
    "anonymized_at timestamptz",
  ]) {
    assert.match(dbml, new RegExp(fragment.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
  }
});

test("pins an append-only single-head lifecycle event chain", () => {
  for (const fragment of [
    "previous_event_id uuid",
    "command_type varchar(60)",
    "actor_type varchar(40)",
    "actor_id varchar(160)",
    "correlation_id uuid",
    "idempotency_key varchar(160)",
    "request_hash varchar(128)",
    "retention_policy_version varchar(80)",
    "cancellation_deadline_at timestamptz",
    "dormancy_basis_at timestamptz",
    "(account_id, command_type, idempotency_key) [unique]",
    "(account_id, previous_event_id) [unique]",
    "Ref: identity.account_lifecycle_events.(account_id, previous_event_id) > identity.account_lifecycle_events.(account_id, id)",
    "Ref: identity.accounts.(id, last_lifecycle_event_id) > identity.account_lifecycle_events.(account_id, id)",
  ]) {
    assert.ok(dbml.includes(fragment), `missing lifecycle chain fragment: ${fragment}`);
  }
});

test("persists immutable successful and no-op lifecycle command responses", () => {
  for (const fragment of [
    "Table identity.account_lifecycle_command_receipts",
    "(account_id, command_type, idempotency_key) [pk]",
    "request_hash varchar(128)",
    "response_status integer",
    "response_code varchar(80)",
    "response_document jsonb",
    "lifecycle_event_id uuid",
    "completed_at timestamptz",
    "response_status BETWEEN 200 AND 299",
    "INSERT 후 UPDATE·DELETE 금지",
    "Ref: identity.account_lifecycle_command_receipts.(account_id, lifecycle_event_id) > identity.account_lifecycle_events.(account_id, id)",
  ]) {
    assert.ok(dbml.includes(fragment), `missing command receipt fragment: ${fragment}`);
  }

  assert.match(contract, /성공 또는 상태 변경 없는 성공\(no-op\)/);
  assert.match(contract, /동일한 상태 코드, 응답 코드, 응답 본문/);
  assert.match(contract, /실패 응답은 영수증에 안전하게 저장된 경우에만/);
});

test("models versioned retention obligations and legal holds", () => {
  for (const fragment of [
    "Table identity.account_retention_policy_versions",
    "Table identity.account_retention_policy_rules",
    "Table identity.account_retention_obligations",
    "Table identity.account_legal_holds",
    "blocks_identifier_reuse boolean",
    "retention_days integer",
    "retain_until timestamptz",
    "failure_code varchar(80)",
    "failure_code = 'RETENTION_POLICY_MISSING'",
    "Ref: identity.account_retention_obligations.(account_id, lifecycle_event_id) > identity.account_lifecycle_events.(account_id, id)",
  ]) {
    assert.ok(dbml.includes(fragment), `missing retention fragment: ${fragment}`);
  }
});

test("records the confirmed product values without claiming legal retention periods", () => {
  assert.match(contract, /30일\(30 × 24시간\)/);
  assert.match(contract, /최근 성공 인증 시각부터 연속 12개월/);
  assert.match(contract, /최근 10분 이내/);
  assert.match(contract, /`CLOSED` 후 30일 격리/);
  assert.match(contract, /완전한 승인 정책/);
});

test("models releasable 30-day identifier quarantine without storing plaintext", () => {
  for (const fragment of [
    "Table identity.account_identifier_quarantines",
    "identifier_fingerprint varchar(128)",
    "reuse_eligible_at timestamptz",
    "reuse_eligible_at = quarantined_at + interval '30 days'",
    "Ref: identity.account_identifier_quarantines.(account_id, lifecycle_event_id) > identity.account_lifecycle_events.(account_id, id)",
  ]) {
    assert.ok(dbml.includes(fragment), `missing identifier quarantine fragment: ${fragment}`);
  }
  assert.match(contract, /별도 tombstone/);
});

test("models direct OIDC step-up and sessionless reactivation", () => {
  for (const fragment of [
    "Table identity.oidc_step_up_nonces",
    "nonce_digest varchar(128) [not null, unique]",
    "digest_key_version smallint [not null]",
    "verification_attempt_count int [not null, default: 0]",
    "verification_attempt_count BETWEEN 0 AND 5",
    "consumed_by_account_id uuid",
    "Ref: identity.oidc_step_up_nonces.provider_id > identity.auth_providers.id",
    "Ref: identity.oidc_step_up_nonces.consumed_by_account_id > identity.accounts.id",
  ]) {
    assert.ok(dbml.includes(fragment), `missing OIDC step-up fragment: ${fragment}`);
  }

  assert.match(contract, /제공자 JWKS로 직접 검증/);
  assert.match(contract, /ID token과 원문 nonce는 영속화하거나 로그에 남기지 않는다/);
  assert.match(contract, /세션은 발급하지 않는다/);
  assert.match(contract, /성공 응답 재생도 세션이나 새 nonce를 만들지 않는다/);
  assert.match(contract, /POST \/v1\/account\/oidc-step-up-challenges/);
  assert.match(contract, /POST \/v1\/account\/reactivations\/oidc/);
});

test("models five-domain fail-closed account closure evidence", () => {
  for (const fragment of [
    "Enum identity.account_closure_domain",
    "Enum identity.account_closure_readiness_status",
    "Table identity.account_closure_runs",
    "Table identity.account_closure_readiness",
    "(correlation_id, generation, domain) [pk]",
    "Ref: identity.account_closure_readiness.(correlation_id, account_id) > identity.account_closure_runs.(correlation_id, account_id)",
    "Table operations.account_integrations",
  ]) {
    assert.ok(dbml.includes(fragment), `missing closure coordination fragment: ${fragment}`);
  }

  for (const domain of ["BOT", "TRADING", "COMPETITION", "NOTIFICATION", "INTEGRATION"]) {
    assert.match(contract, new RegExp(`\\b${domain}\\b`));
  }
  assert.match(contract, /자동 주문 취소, 자동 매도 또는 강제 청산은 금지/);
  assert.match(contract, /알 수 없음, 오류, timeout/);
});

test("separates private bot data from competition evidence and pins approved proposal values", () => {
  for (const fragment of [
    "BOT_STRATEGY_PRIVATE_DATA",
    "COMPETITION_RESULT_EVIDENCE",
    "'BOT_STRATEGY_EVALUATION', 'RETAIN', null, 'DEPRECATED_FAIL_CLOSED'",
    "'BOT_STRATEGY_PRIVATE_DATA', 'DELETE', 30",
    "'COMPETITION_RESULT_EVIDENCE', 'ANONYMIZE', 365",
    "'OPERATIONS_DELIVERY_LOG', 'DELETE', 365",
    "'POLICY_CONSENT', 'RETAIN', 1825",
    "'TRADING_FINANCIAL_RECORD', 'RETAIN', 1825",
    "owner_anonymized_at timestamptz",
    "creator_anonymized_at timestamptz",
    "competition_room_organizer_actor",
    "competition_participant_owner_or_anonymized",
    "bot_owner_or_anonymized_evidence",
    "backtest_owner_or_anonymized_evidence",
  ]) {
    assert.ok(dbml.includes(fragment), `missing retention proposal fragment: ${fragment}`);
  }

  assert.match(contract, /private Bot\/Strategy 30일 삭제가 이 증적의 FK를 끊어서는 안 된다/);
  assert.match(contract, /현재 키와 아직 비교 대상인 모든 이전 키 버전/);
  assert.match(contract, /정확한 commit에 대한 fresh 승인 증거/);
});
