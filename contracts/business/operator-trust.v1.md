---
schema_version: 1
id: contract.operations.operator-trust.v1
kind: business
status: approved
revision: 3
refs:
  - contract.operations.operator-rbac.v1
  - role.operator
  - journey.operator.administer
  - scenario.account.sanction
  - capability.audit.evidence
---

# contract.operations.operator-trust.v1

Status: approved canonical contract. Product authority `user:kcrmin` replaced human operator Cognito/OIDC with dedicated login-name/password/TOTP authentication while preserving the existing RBAC and audit model. GitHub Actions to AWS OIDC remains deployment identity and is outside this human authentication boundary.

## 1. Credential separation

Operators authenticate with a dedicated normalized login name, an Argon2id password verifier, and a 6-digit 30-second TOTP. Customer credentials, customer sessions, delegated strategy credentials, browser bearer tokens, Cognito/OIDC identities, ALB identity headers, and internal service credentials never imply operator authority.

The database stores neither plaintext passwords nor plaintext TOTP secrets. Password records carry the algorithm parameters and credential version. TOTP secrets are encrypted with a versioned key and unique nonce. Provisioning, password reset, TOTP replacement, disabling, and session revocation are audited CLI-only operations; there is no public bootstrap, signup, recovery, or self-elevation endpoint.

## 2. Login and MFA verification

The login endpoint accepts the dedicated login name, password, and current TOTP code over HTTPS. It returns the same public failure for unknown, disabled, incomplete, wrong-password, and wrong-TOTP accounts. Rate limits and security evidence apply by privacy-safe source key and account when resolved, without exposing which factor failed.

Password verification uses the stored Argon2id parameters and rejects unsupported or weakened records. TOTP verification uses the configured clock-skew window and atomically advances `last_accepted_totp_step`; the same or an older step cannot be replayed, including by concurrent requests. Authentication succeeds only for one active operator with one active credential record whose password and credential versions match.

## 3. Opaque server-side session

A successful login creates an opaque server-side session cookie with `Secure`, `HttpOnly`, and `SameSite=Strict`. Only versioned HMAC digests of the session token, CSRF token, and privacy-safe source key are stored. The browser keeps CSRF material in memory only and sends it on state-changing requests. Session lookup requires exact digest and operator ownership, credential-version match, idle expiry, absolute expiry, and non-revoked state.

Session rotation invalidates the previous token before the replacement is usable. Password reset, TOTP replacement, operator disablement, or credential-version change revokes all existing sessions. Logout and administrator revocation are idempotent. Missing database or key dependencies fail closed; no allow decision is cached across requests.

## 4. Authorization and audit

After session authentication, RBAC is recalculated from the active catalog and current assignments for every request as required by `contract.operations.operator-rbac.v1`. UI visibility, a role name supplied by a client, source IP, security-group membership, servlet principal, or any `X-Operator-*`/`X-User-*` header is never authorization.

`GET /api/v1/operations/me` returns only the authenticated operator's UI-safe identity, active catalog version, effective roles/permissions, assignment expiry boundaries, and current session expiry. Catalog, assignment, sanction, case, audit, and MCP operations retain their distinct permission and current-MFA requirements. Missing authentication is `401`; authenticated operators without permission receive stable `403` codes; responses include correlation without revealing hidden permissions or account existence.

Login success/failure, logout, expiry, revocation, credential changes, TOTP replay denial, authorization denial, and privileged actions emit privacy-safe immutable audit/security evidence. Raw passwords, TOTP codes/secrets, cookies, CSRF tokens, HMAC values, and customer data never enter logs, responses, or audit JSON.

## 5. Provisioning and lifecycle

The initial operator and later credential maintenance use reviewed CLI commands against the operations domain. Each command requires an idempotency key, records actor/correlation/reason and a request hash, and returns the stored result for an exact replay while rejecting a conflicting replay. Partial credential or session state is never committed.

Credential and session records belong to `operations.operator_accounts`. Runtime APIs cannot hard-delete operator, credential, session, assignment, bootstrap, or audit evidence. Legal hold and the approved operations-retention policy govern later disposal. Key rotation is forward-only and must keep enough version metadata to verify or revoke existing records safely.

## 6. Required verification

- valid login, normalized-name collision, unknown/disabled/incomplete operator, wrong password, wrong TOTP, boundary clock skew, replayed and concurrently replayed TOTP;
- Argon2id parameter validation, TOTP encryption/key-version failure, and dependency outages fail closed without enumeration;
- cookie flags, CSRF denial, idle and absolute expiry boundaries, session rotation, logout, administrator revocation, and credential-version invalidation;
- customer cookies, bearer/OIDC tokens, spoofed headers, and direct-target requests never authenticate an operator;
- RBAC grant/revoke/catalog changes take effect on the next request and keep existing audit semantics;
- CLI provisioning/reset/TOTP replacement exact replay, conflicting replay, partial-failure rollback, and full session revocation;
- browser operator flow and `admin-mcp` use the same authenticated operator and RBAC semantics without sharing customer sessions;
- GitHub Actions to AWS OIDC remains present for deployment while no human operator Cognito/OIDC path is accepted.
