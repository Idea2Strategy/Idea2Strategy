# Internal Operator Authentication Design

**Status:** Approved for planning by product authority `user:kcrmin` on 2026-08-13.

**Decision:** Replace human operator Cognito/OIDC authentication with dedicated internal operator credentials, TOTP, and server-side sessions. Keep GitHub Actions-to-AWS OIDC until the separately scoped Jenkins migration.

## Authority record

Product authority `user:kcrmin` directed that operator OIDC is excessive for this service, approved the dedicated internal-login recommendation, and confirmed proceeding with that decision. The implementing pull request must quote this authority record and must not claim a fresh provider approval.

## Scope

This change covers only human operator authentication for the operations UI, backend operator routes, and `admin-mcp` browser-mediated access. It preserves the existing operator account boundary, RBAC catalog, role assignments, permission checks, audit evidence, account-disable behavior, and separation from customer accounts.

It does not change customer password or social login. It does not remove the GitHub Actions OIDC trust used to obtain short-lived AWS deployment credentials. It does not implement Jenkins; that migration will choose its AWS workload identity separately, preferably an EC2 instance profile when Jenkins runs in AWS.

## Considered approaches

### 1. Dedicated operator credentials and sessions — selected

Operators remain in `operations.operator_accounts`. Separate credential and session records provide password, TOTP, lockout, and revocation behavior. This keeps customer and operator trust boundaries separate while removing Cognito, hosted-login UI, JWT/JWKS validation, and OIDC deployment configuration.

### 2. Customer account with an ADMIN role — rejected

This has less code but makes a customer login session eligible for administrative authority. A customer-account takeover or customer-auth regression would then cross directly into the operations plane, and customer lifecycle behavior would affect administrators.

### 3. Password-only operator login — rejected

This is the smallest implementation but provides inadequate protection for sanctions, RBAC changes, audit access, and operational controls. TOTP is retained without depending on email or SES.

## Architecture

### Data model

`operations.operator_accounts` remains the stable operator and RBAC principal. The canonical V1 definition removes its OIDC subject-HMAC fields and retains only principal lifecycle fields such as ID, status, creation time, and disablement time. Credential and MFA fields live in the dedicated credential table; no customer identity table is reused.

Add `operations.operator_login_credentials`, one row per operator, containing:

- a case-normalized unique login name;
- an Argon2id password hash, explicit hash parameters, and credential version;
- a versioned AES-GCM-encrypted TOTP seed and enrollment timestamp;
- failed-attempt count, lock expiry, password-change time, and compromise time.

Add `operations.operator_sessions`, containing only a versioned HMAC digest of a random session token, the operator and credential version, creation/last-use/absolute-expiry times, the TOTP verification time, a CSRF-token digest, and revocation fields. Raw session and CSRF tokens are never stored.

The TOTP encryption key and token-digest keys are versioned deployment secrets. They never enter Git, Terraform state, browser bundles, application logs, audit JSON, or database plaintext.

### Provisioning and recovery

There is no public registration, password reset, role elevation, or TOTP-disable endpoint. The first operator is created by the existing one-shot bootstrap boundary using an interactive SSM or local administrative command. The command reads secrets with terminal echo disabled, verifies one TOTP code before commit, and stores only derived or encrypted material.

Later operators receive RBAC assignments through the existing permission-guarded flow. Credential provisioning and locked-out-account recovery use a separate audited SSM/local administrative command with an explicit reviewed operator ID; they are never inferred from a customer account or exposed over HTTP. Email and SES are not required. Provisioning and recovery revoke all existing sessions and increment the credential version.

### Login and session flow

The operations login UI shows login name, password, and six-digit TOTP inputs. It calls `POST /api/v1/operator-auth/sessions`. The backend applies per-login and per-source throttling, verifies the password in constant-time-compatible handling, verifies the current TOTP window with replay prevention, confirms that the operator is active, and creates a server-side session.

The response sets a random session token in a `__Host-operator_session` cookie with `Secure`, `HttpOnly`, `SameSite=Strict`, no `Domain`, and `Path=/`. The response supplies a separate CSRF token to memory for double-submit/header validation; it is not placed in persistent browser storage.

Every operator request resolves the session digest, checks absolute and idle expiry, credential version, operator status, CSRF for state-changing methods, and current RBAC assignments. Authorization is recalculated for every request. Disabling an operator, changing credentials, or revoking a session takes effect on the next request.

`POST /api/v1/operator-auth/logout` revokes the current session and clears the cookie. `GET /api/v1/operator-auth/session` returns only the UI-safe current-operator projection. The existing `/api/v1/operations/me` remains the RBAC projection after authentication.

`POST /api/v1/operator-auth/reauthenticate` requires the current session plus password and TOTP, rotates the CSRF token, and refreshes only that session's MFA verification time. It does not create another session or extend the absolute expiry.

### Session policy

- Password hashing: Argon2id with versioned parameters benchmarked for the deployment class.
- TOTP: 30-second period, six digits, one adjacent time step allowed for clock skew, and a persisted last-used step to reject replay.
- Login failure response: one generic `401` response for unknown login, wrong password, wrong TOTP, disabled operator, or incomplete enrollment.
- Lockout: bounded exponential delay and throttling keys derived from both normalized login input and source fingerprint, including unknown login names. A stable `429` therefore does not reveal whether a login exists.
- Session lifetime: 15-minute idle timeout and 8-hour absolute timeout.
- MFA freshness: the session records the successful TOTP time; high-risk commands require it to be no older than 15 minutes and otherwise return a stable reauthentication-required response.
- Concurrent sessions: at most three active sessions per operator; a fourth login revokes the oldest.

### Edge and deployment

The ALB continues to terminate HTTPS and route requests but no longer performs operator JWT/OIDC validation. Backend session validation is the sole application identity decision, while security groups still restrict direct target access.

Remove the dedicated Cognito user pool, client, domain, claim transformer, OIDC UI variables, JWKS/issuer/audience runtime variables, and OIDC callback/logout routes. Release workflows must stop requiring operator OIDC values but retain `id-token: write` and AWS role assumption for CI/CD.

The later Jenkins migration is independent. If Jenkins runs on EC2, it should deploy through a least-privilege instance profile and short-lived STS role assumption. Static long-lived AWS access keys are not introduced by this change.

## Failure behavior and audit

Authentication fails closed when credential/session secrets are missing, the database is unavailable, encrypted TOTP material cannot be decrypted, time validation is invalid, a session is expired/revoked, or operator/RBAC state is ambiguous.

Pre-authentication failures emit privacy-safe security events with correlation ID, coarse reason category, source fingerprint, and rate-limit outcome, but never login existence, password material, TOTP values, session tokens, CSRF tokens, or encrypted seed material. Successful login, logout, session revocation, credential reset, TOTP replacement, lockout, and high-risk reauthentication are recorded in the operations audit boundary.

## UI behavior

The existing operations login page remains visible for UI development. It becomes an internal login form rather than an OIDC redirect. It has explicit loading, invalid-credentials, rate-limited, service-unavailable, reauthentication-required, and signed-out states. Operator pages remain visible in the route structure, but protected data and actions require an authenticated session and backend permission checks.

Local development uses the same backend cookie/session/TOTP path as deployment. The local origin uses localhost cookie handling while the deployed profile additionally enforces the `__Host-` name and HTTPS-only transport. A development-only bootstrap command may create the documented local operator, but there is no frontend authentication bypass in deployable builds.

## Verification

Implementation is test-driven and must cover:

- password success/failure, unknown login non-enumeration, disabled operator, hash parameter upgrade, and lockout concurrency;
- TOTP success, adjacent-window skew, replay, stale/future codes, encrypted-key rotation, and recovery revocation;
- session issuance, digest-only persistence, cookie attributes, idle/absolute expiry, credential-version invalidation, concurrent-session cap, logout, and CSRF rejection;
- current-MFA enforcement for high-risk operations and immediate RBAC/operator revocation;
- customer sessions, spoofed headers, legacy OIDC JWTs, and direct-target requests never granting operator authority;
- UI login/error/reauthentication/logout states without persistent token storage;
- Terraform and release-workflow checks proving Cognito/operator OIDC removal while GitHub Actions AWS OIDC remains enabled;
- local Docker and deployed HTTPS end-to-end login, RBAC read, high-risk command, logout, restart, and recovery flows.

## Migration and rollout

Because AWS is being rebuilt from the new V1 baseline, the canonical DBML and `V1__initial_schema.sql` are updated together instead of retaining an OIDC compatibility migration. The rollout has no dual-auth period: OIDC tokens stop authenticating when the new backend is deployed.

Before deployment, provision at least one internal operator and verify TOTP through the administrative command. Deploy the backend and UI together, then remove Cognito resources only after the internal-login smoke test succeeds. Rollback restores the previous application and Cognito configuration; database additions remain forward-compatible and are not destructively removed.

## Required canonical changes

After review of this design, update the approved operator-trust contract, RBAC references, canonical DBML, V1 Flyway baseline, backend authentication module, operations UI, Terraform, release workflows, runbooks, and launch-readiness checks as one coordinated feature. The contract change must name `user:kcrmin` and quote the authority decision in its pull request body under the repository's pre-v1.0.0 authority rule.
