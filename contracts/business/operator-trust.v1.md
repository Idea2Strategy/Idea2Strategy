---
schema_version: 1
id: contract.operations.operator-trust.v1
kind: business
status: approved
revision: 1
refs:
  - contract.operations.operator-rbac.v1
  - role.operator
  - journey.operator.administer
  - scenario.account.sanction
  - capability.audit.evidence
---

# contract.operations.operator-trust.v1

Status: approved canonical contract. Product authority `user:kcrmin` merged proposal PR [#166](https://github.com/Idea2Strategy/Idea2Strategy/pull/166).

## 1. Credential separation

Operator browser/API and `admin-mcp` requests use a dedicated short-lived OIDC JWT access token with the operator audience. Customer opaque session tokens, email/OIDC customer login sessions, delegated strategy credentials, ALB cookies without a verifiable bearer token, and internal service credentials never imply operator authority.

The IdP registration, issuer, audience, accepted signing algorithm/key set, allowed `acr`/`amr` values, maximum token age, and MFA freshness are versioned deployment configuration. The ALB production profile uses RS256 because the selected ALB JWT-validation action supports RS256; the backend requires the same algorithm for this profile. Secrets remain in the selected secret store and are never persisted in Git, request logs, audit JSON, or the browser bundle.

## 2. Edge and backend verification

The production HTTPS ALB applies JWT validation to every operator and `admin-mcp` route before forwarding. It validates signature, `iss`, `exp`, `nbf` and `iat` when present, the exact operator audience/client claim, and required assurance claims supported by the chosen IdP. Failure returns an authentication error and never reaches an operator handler.

The target independently verifies the bearer JWT signature against the pinned issuer/JWKS policy and validates issuer, audience, subject, expiry, not-before, issued-at, allowed algorithm, key ID, assurance claims, and authentication time. Key refresh is bounded; unknown keys, unavailable required metadata beyond the safe cache window, ambiguous claims, clock violations, or configuration mismatch fail closed.

ALB validation is defense in depth. The backend authorization decision never trusts source IP, security-group membership, servlet principal name, container role, `X-Amzn-Oidc-Identity`, `X-Operator-*`, `X-User-*`, or another client-controlled identity/MFA header. The service target accepts application traffic only from the ALB security group, but network origin alone grants no identity.

## 3. Operator mapping and MFA

After token verification, the backend creates the lookup input from a length-delimited canonical pair `(issuer, subject)`, protects it with the configured versioned HMAC key, and requires exactly one matching `operations.operator_accounts` row and HMAC key version with status `ACTIVE`. Rotation may query explicitly configured current and previous key versions, but a successful mapping records the matched version and never falls back to an unversioned digest. Missing, duplicate, disabled, or unmigrated mappings fail closed without revealing whether the subject is registered.

Current MFA is true only when the verified token proves an approved `acr` value or contains an approved `amr` member and its signed `auth_time` is within the configured maximum age. `mfa_enrolled_at`, `last_mfa_verified_at`, a role name, or an edge-only claim is supporting/audit state, not sufficient proof. Successful current proof may update `last_mfa_verified_at` monotonically after verification; stale proof cannot refresh it.

RBAC is recalculated from the active catalog and current assignments for every request as required by `contract.operations.operator-rbac.v1`. UI visibility is not authorization.

## 4. Bootstrap

There is no public HTTP bootstrap or self-elevation endpoint. Initial active catalog installation, first operator subject mapping, and first role assignment are performed by a one-shot deployment command executed through SSM with a reviewed manifest and expected empty/bootstrap state.

The command records manifest hash, catalog version, issuer/subject HMAC key version, resulting operator/assignment IDs, deployment actor, correlation ID, immutable bootstrap receipt, and audit evidence in one transaction. It refuses to run when an active catalog or operator assignment already exists, when the manifest hash was consumed, or when any requested role/permission is outside the manifest. Rerunning the same successful bootstrap key and manifest returns its prior result; another manifest with the same key fails closed.

Later operator grants and revocations use the ordinary permission-guarded A13 APIs. Bootstrap cannot be invoked from the UI or `admin-mcp`.

## 5. Permission read API

All responses use stable IDs/codes from the active versioned catalog and omit identity-provider tokens, raw subjects, HMAC values, secrets, and permissions the caller is not allowed to enumerate.

- `GET /api/v1/operations/me`: any authenticated active operator; returns operator ID, active catalog version, current MFA status/freshness, effective role IDs/codes, effective permission IDs/codes, and assignment expiry boundaries for the caller only.
- `GET /api/v1/operations/rbac/catalog`: requires the catalog-read permission from versioned seed/config; returns the active version and its UI-safe role/permission/delegability projection.
- `GET /api/v1/operations/rbac/operators/{operatorId}/assignments`: requires the assignment-read permission; returns current and historical assignment states without raw external identity.
- Existing grant, revoke, sanction, case, audit, and MCP commands continue to require their separately mapped permissions and fresh MFA where configured.

Unknown callers and targets preserve the existing non-enumeration rules. Missing authentication is `401`; authenticated operators without permission or required current MFA receive stable `403` codes; stale catalog/version conflicts use `409` only when revealing that state is authorized. Every denial includes correlation but no hidden permission set.

## 6. Session, revocation, and failure behavior

Token lifetime is short and configured outside this contract. Disabling an operator, revoking an assignment, retiring a catalog, or changing a permission takes effect on the next request regardless of remaining token lifetime. The backend does not cache an allow decision across requests.

IdP/JWKS or edge outages fail closed for new authentication. A bounded cache may verify already issued tokens only while the cached key and policy are still valid; stale-while-unbounded behavior is prohibited. Authentication and RBAC denials emit privacy-safe security/audit evidence, while requests lacking a trustworthy operator UUID remain in the pre-auth security log boundary.

## 7. Data lifecycle

The backend operations domain owns the operator mapping, bootstrap receipt, assignment, and audit evidence. The mapping stores only a versioned HMAC of `(issuer, subject)`, never the raw subject or token. Bootstrap receipts and RBAC/audit evidence are internal restricted operational records.

Until an approved operations-retention policy explicitly permits disposal, bootstrap receipts, successful/denied authorization audit evidence, and assignment history are retained. Legal hold blocks destructive processing. Runtime APIs cannot hard-delete these rows. A future approved cleanup may rotate or scrub obsolete HMAC material only after replacement mappings are verified and must never erase the evidence needed to explain a grant, revocation, sanction, or operator case decision.

The schema change is additive. Existing unversioned operator digests are backfilled only from verified deployment mapping evidence; rows without that evidence remain unusable and fail closed. After versioned mapping or bootstrap evidence exists, rollback is forward-fix only.

## 8. Required verification

- valid token, wrong issuer, wrong audience, wrong algorithm, unknown key, expired/not-yet-valid/future-issued token;
- spoofed operator/ALB/servlet headers and direct-target attempts never authorize;
- same subject under another issuer maps differently;
- inactive, missing, and duplicate operator mappings fail without enumeration;
- absent, stale, or unapproved MFA claims deny high-risk work even when DB enrollment exists;
- role/assignment/catalog revocation takes effect on the next request;
- bootstrap first run, exact replay, conflicting replay, non-empty state, and partial-failure rollback;
- permission self/catalog/assignment reads enforce their distinct guards and redact provider data;
- browser operator flow and `admin-mcp` use the same trust semantics without sharing customer sessions;
- ALB, backend, PostgreSQL, UI browser, and audit-correlation E2E pass on the exact integrated commits.

