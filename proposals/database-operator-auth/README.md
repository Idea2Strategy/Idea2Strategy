# Database-backed operator authentication proposal

Status: **isolated, unapproved proposal**. This document is intentionally outside
`specs/**` and `contracts/**`. It does not authorize a canonical contract change,
runtime enablement, database migration, or AWS deployment.

## Approval boundary

- Prepared from `Idea2Strategy/Idea2Strategy` commit
  `4232f3be6c0fc529c3dc2037c702799339308699`.
- Protected fingerprint observed before preparation:
  `sha256:7bb58d50af4c61980d2353a60344e8cf470a7fb00a02c08b729b507816838651`.
- `stackcord governance check --json` returned `unknown` because fresh GitHub
  provider approval evidence was unavailable. No protected source is changed by
  this proposal.
- One configured product authority must approve the exact proposal commit before
  `contracts/business/operator-trust.v1.md`, DBML, Flyway, Backend, UI, or
  Terraform is changed to implement it.

## Decision requested

Replace the dedicated external OIDC/Cognito operator identity path with a
dedicated database-backed operator credential and server-side session path.
This does **not** turn a customer account into an operator and does not reuse a
customer login session for operator authorization.

If approved, this proposal supersedes the unapproved Cognito assurance extension
in `proposals/cognito-operator-oidc/README.md`. Cognito remains disabled and no
Cognito resource may be created for operator authentication while the replacement
is being integrated.

## Recommended trust model

### Separate operator credentials

- `operations.operator_accounts` remains the operator/RBAC identity root.
- Add a one-to-one operator credential record with a normalized, unique login ID,
  a versioned password hash, credential version, failed-attempt counters, lock
  boundary, password-change timestamps, and disabled/compromised state.
- Reuse the Backend's reviewed password codec boundary and current
  PBKDF2-HMAC-SHA256 profile rather than introducing another cryptography library.
  Parameters and hash version remain stored with the credential so a future
  rehash is explicit.
- Store only the password hash. Passwords, TOTP values, recovery material, and
  session tokens are never written to logs, audit JSON, Git, or Terraform state.

### Mandatory TOTP and recent step-up

- Every active operator must enroll TOTP. Password-only login never grants an
  operator session.
- The TOTP seed is encrypted with an application data key whose root secret is
  supplied from AWS Secrets Manager; the plaintext seed exists only while
  enrolling or verifying it.
- Login requires password and a valid TOTP value. Sensitive commands additionally
  require a successful TOTP step-up within the existing ten-minute freshness
  window.
- TOTP replay inside the accepted time step, stale proof, excessive attempts,
  locked/disabled accounts, and unavailable key material fail closed.
- Recovery is an audited SSM-only operation. There is no public self-service
  operator password or MFA recovery endpoint in the first release.

### Opaque server-side sessions

- Successful authentication creates a cryptographically random opaque token;
  PostgreSQL stores only a keyed digest, audience, issue/expiry times, credential
  version, MFA verification time, last-seen time, and revocation state.
- Browser sessions use a `Secure`, `HttpOnly`, `SameSite=Strict` cookie with
  origin/CSRF enforcement. The raw token is returned only once and never appears
  in a URL.
- Operator sessions have an idle timeout and an absolute timeout. Password/TOTP
  reset, operator disablement, credential-version change, role revocation, or
  catalog retirement is checked on every request and takes effect immediately.
- Session rotation is atomic; an old token cannot be replayed after rotation.
  Concurrent-session limits and explicit logout/revoke-all operations are
  database-enforced.

### Browser and admin-mcp separation

- Customer opaque sessions never authorize `/api/v1/operations/**`.
- Browser operator sessions have audience `OPERATOR_BROWSER`.
- `admin-mcp` is not public. After a fresh browser TOTP step-up, an authorized
  operator may mint a separate, single-purpose `ADMIN_MCP` opaque session with a
  maximum ten-minute lifetime. Its digest and revocation state are stored in the
  same server-side session boundary; a browser cookie is not accepted by MCP.
- The first release runs `admin-mcp` only through the reviewed on-demand/SSM path.
  There is no long-lived personal access token or shared administrator password.

### Authorization, auditing, and enumeration resistance

- Authentication establishes only one active operator UUID. RBAC remains the
  per-request decision source defined by
  `contract.operations.operator-rbac.v1`.
- Login and TOTP failures use stable non-enumerating responses, bounded database
  counters, exponential delay/rate limits, and privacy-safe security events.
- Successful login, failure/lockout, step-up, session mint/rotation/revocation,
  credential reset, and bootstrap/recovery actions record correlation and actor
  evidence without credentials or raw tokens.
- Forwarded identity, role, MFA, source-IP, ALB, and servlet headers never grant
  authority.

## Bootstrap and secret placement

The first operator is created by the existing reviewed SSM one-shot bootstrap,
extended additively after approval. The reviewed manifest contains the operator
UUID/login identity and RBAC assignment, but no password or TOTP seed.

Initial password material and the TOTP encryption root key are supplied at runtime
from AWS Secrets Manager. The bootstrap requires an immediate password change and
TOTP enrollment before it can issue an operator session. Exact replay returns the
prior receipt; conflicting or non-empty bootstrap state fails closed.

## Required implementation order

1. Approve this exact proposal through the configured GitHub review provider.
2. Update the protected operator-trust contract and register its impact.
3. Add DBML and additive Flyway tables/constraints for credentials, TOTP, sessions,
   attempts, recovery receipts, and audit evidence.
4. Add failing Backend tests, then implement password/TOTP verification, opaque
   sessions, step-up, lockout, revocation, and SSM bootstrap/recovery.
5. Replace the operator JWT adapter without relaxing customer/operator separation
   or RBAC checks.
6. Add the operator login/step-up/logout UI with loading, error, lockout, expiry,
   permission, and recovery-unavailable states.
7. Keep Cognito disabled, remove Cognito-only deployment inputs after consumers are
   migrated, and verify the saved Terraform plan creates no Cognito resources.
8. Run PostgreSQL concurrency tests, Backend/UI security tests, exact-stack E2E,
   and real HTTPS browser plus on-demand `admin-mcp` verification before enablement.

## Required verification

- correct and incorrect password/TOTP, enumeration resistance, rate limiting, and
  atomic lockout under concurrent attempts;
- TOTP replay, clock-window boundaries, unavailable encryption key, enrollment,
  reset, and SSM-only recovery;
- random-token strength, digest-only persistence, rotation, idle/absolute expiry,
  concurrent-session ceiling, logout, revoke-all, and credential-version changes;
- disabled operator, missing/retired RBAC catalog, revoked/expired assignment, and
  stale step-up taking effect on the next request;
- CSRF/origin/cookie behavior, token/header/log redaction, customer-token rejection,
  direct-target rejection, and browser/MCP audience separation;
- first bootstrap, exact replay, conflicting replay, partial rollback, and immutable
  audit receipt;
- exact integrated Backend, DBML/Flyway, UI, Terraform, HTTPS, and CloudWatch E2E.

## Rollback

Until a database-backed operator session is issued, keep operator auth disabled and
the additive schema unused. After credential/session evidence exists, rollback is
forward-fix only: disable operator routes, revoke sessions, preserve credentials and
audit receipts, and deploy a compatible correction. Never fall back to customer
sessions, trusted headers, a shared password, or an unverified Cognito claim.

## Exact approval statement

Approval of this proposal means:

> Replace the dedicated external OIDC/Cognito operator identity path with the
> dedicated database-backed password + mandatory TOTP + opaque server-side session
> model described in this exact commit, while preserving separate customer and
> operator identities, per-request RBAC, recent MFA for sensitive work, SSM-only
> bootstrap/recovery, fail-closed behavior, and immutable audit evidence.
