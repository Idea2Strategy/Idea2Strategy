# Internal Operator Authentication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace human operator Cognito/OIDC bearer authentication with dedicated login-name/password credentials, TOTP, and opaque server-side sessions while preserving the existing operator RBAC, audit evidence, and GitHub Actions-to-AWS OIDC deployment boundary.

**Architecture:** Keep `operations.operator_accounts` as the stable operator identity and leave RBAC authorization services unchanged. Replace the JWT/subject resolver inside `backend-operator-trust` with credential crypto, a transactional session store, a request-scoped cookie/CSRF authenticator, and audited provisioning commands. The UI becomes a same-origin credential client that retains only the CSRF token in memory. Development and AWS use the same database-backed session path; only the cookie name/Secure attribute and secret sources differ.

**Tech Stack:** Java 21, Spring Boot 4.1, Spring JDBC, PostgreSQL 17, Redis-compatible throttling, Argon2id via Bouncy Castle, JCE AES-256-GCM/HMAC, React 19, TypeScript 7, Vite 8, Vitest, Playwright, Terraform 1.15, GitHub Actions AWS OIDC.

## Global Constraints

- The approved product decision is [the 2026-08-13 design](../specs/2026-08-13-internal-operator-auth-design.md), explicitly authorized by `user:kcrmin`. Quote that authority in the implementation PR.
- Customer authentication under `identity.*` is out of scope. Do not remove customer OIDC, password, email, or customer JWT code.
- Preserve `operations.operator_accounts` IDs, RBAC catalogs, role assignments, permission checks, disable semantics, and existing operational audit evidence.
- Preserve `.github` `id-token: write`, `aws-actions/configure-aws-credentials`, and `infra/terraform/ci-identity/**`. These implement GitHub Actions-to-AWS OIDC, not human operator login.
- Do not add Jenkins files, credentials, jobs, or migration notes beyond stating that Jenkins is excluded.
- This branch is based on root commit `ae26cff` (`Rebaseline local development on Flyway V1`). Update only `db/schema.dbml` and `backend/db-migration/src/main/resources/db/migration/V1__initial_schema.sql`; do not create `V2__*` and do not restore superseded migrations.
- Before implementation, create matching `feature/internal-operator-auth` branches in the `backend` and `ui` submodules from the gitlinks recorded by the refreshed root branch. Commit and verify each submodule independently before updating root gitlinks.
- Never persist or log raw passwords, TOTP seeds, session tokens, CSRF tokens, recovery material, login names, or source addresses. Audit and throttle keys use versioned HMACs and stable reason codes only.
- All authentication ambiguity fails closed. A missing database, Redis throttle store, crypto key, decryption failure, clock anomaly, stale credential version, disabled operator, or RBAC lookup failure denies access.

## Design Review Resolutions

1. The CSRF mechanism is a synchronizer-token design, not double-submit: the backend derives a raw token from the presented raw session token plus a stored CSRF generation using a separate versioned HMAC key, the UI keeps it only in memory, and the database stores only its HMAC digest. `GET /api/v1/operator-auth/session` re-derives and returns the same generation so reloads and concurrent tabs work without persistent browser storage; successful reauthentication increments the generation and rotates the token.
2. Production uses `__Host-operator_session; Secure; HttpOnly; SameSite=Strict; Path=/` with no `Domain`. Plain HTTP localhost uses `operator_session` with the same attributes except `Secure`; no production profile may select the local name.
3. Cognito destruction is a second reviewed Terraform apply. First deploy internal authentication while the Cognito resources remain unused, provision an operator, and pass internal-login smoke tests. Only then apply the reviewed Cognito-removal plan. This preserves the no-dual-auth rule because retained Cognito resources are not accepted by the application.
4. The source throttle trusts `X-Forwarded-For` only when the direct peer is the configured ALB/reverse proxy. Direct local requests use the socket peer. The derived source key is HMACed before Redis storage or audit use.
5. TOTP replay prevention, credential failure counters, credential resets, session-cap eviction, and session reauthentication use row locks/atomic updates. A code accepted in one transaction cannot be accepted again in a concurrent transaction.
6. `admin-mcp` keeps its existing RBAC and audit application ports. Browser-mediated calls authenticate the same opaque cookie session and enforce CSRF on tool invocations; it does not gain a separate token or machine credential path.

---

### Task 1: Lock the revised contract and negative boundaries

**Files:**
- Modify: `contracts/business/operator-rbac.v1.md`
- Modify: `scripts/validate-operator-rbac-proposal.mjs`
- Modify: `scripts/validate-operator-rbac-proposal.test.mjs`
- Create: `scripts/validate-internal-operator-auth.test.mjs`
- Modify: `.github/workflows/ci.yml`

- [ ] Write failing validator cases requiring internal password+TOTP+server-session language, generic authentication errors, session/CSRF rules, credential recovery restrictions, the `user:kcrmin` decision, and explicit preservation of GitHub Actions AWS OIDC.
- [ ] Add negative cases that reject human-operator issuer/JWKS/audience requirements, browser bearer storage, an HTTP bootstrap/reset route, Jenkins scope, or removal of `id-token: write`.
- [ ] Run `node --test scripts/validate-operator-rbac-proposal.test.mjs scripts/validate-internal-operator-auth.test.mjs` and confirm the new cases fail for the expected missing obligations.
- [ ] Update the canonical RBAC contract so `OperatorRequestContext` is established by a current server session and current TOTP evidence instead of a trusted external subject, without changing role/permission semantics.
- [ ] Wire the new validator into `.github/workflows/ci.yml` and rerun the two node test files until green.
- [ ] Run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify-collaboration-policy.ps1`.
- [ ] Commit the root contract slice with `git commit -m "docs(auth): bind operator RBAC to internal sessions"`.

### Task 2: Define the canonical V1 credential and session schema

**Files:**
- Modify: `db/schema.dbml`
- Modify: `backend/db-migration/src/main/resources/db/migration/V1__initial_schema.sql`
- Modify: `backend/db-migration/src/test/java/com/idea2strategy/backend/migration/CentralFlywayIntegrationTest.java`
- Create: `backend/db-migration/src/test/java/com/idea2strategy/backend/migration/InternalOperatorAuthSchemaIntegrationTest.java`
- Modify: `backend/modules/backend-persistence/src/test/java/com/idea2strategy/backend/persistence/operatorbootstrap/JdbcOperatorBootstrapAdapterIntegrationTest.java`

- [ ] Add a failing PostgreSQL integration test asserting that `operations.operator_accounts` no longer contains external-subject HMAC/MFA columns and that its stable ID/status/timestamps remain.
- [ ] In the same test, require `operations.operator_login_credentials` with normalized unique `login_name`, Argon2 algorithm/parameter/version fields, password hash, credential version, encrypted TOTP ciphertext/nonce/key version, enrollment and last accepted TOTP step, failed-attempt/lock timestamps, password-changed timestamp, and compromise timestamp.
- [ ] Require `operations.operator_sessions` with unique versioned session-token HMAC, versioned CSRF HMAC plus positive generation, operator ID, credential version, created/last-used/idle/absolute expiry, MFA-verified timestamp, source HMAC, and revocation metadata. Add checks for expiry ordering, positive versions, digest shape, and revoked-at/reason coherence.
- [ ] Add indexes for normalized login lookup, active session lookup/expiry cleanup, operator session-cap ordering, and locked credentials. Add foreign keys to `operator_accounts`; never cascade-delete audit or RBAC evidence.
- [ ] Modify `db/schema.dbml` and the consolidated V1 SQL together. Update bootstrap receipt coherence away from external-identity key versions and toward the initial credential version.
- [ ] Run `cd backend && ./gradlew :db-migration:test --tests '*InternalOperatorAuthSchemaIntegrationTest' --tests '*CentralFlywayIntegrationTest'`.
- [ ] Run root DBML/Flyway checks: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-dbml.ps1` and `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-central-flyway.ps1` if present; otherwise run the exact schema checks listed by `scripts/test-docker-development.ps1`.
- [ ] Commit backend first with `git -C backend commit -m "feat(auth): add operator credential session schema"`, then commit the synchronized root DBML and backend gitlink with `git commit -m "feat(auth): model internal operator sessions in V1"`.

### Task 3: Build versioned password, TOTP, and token cryptography

**Files:**
- Modify: `backend/modules/backend-operator-trust/build.gradle.kts`
- Delete: JWT/OIDC-only classes under `backend/modules/backend-operator-trust/src/main/java/com/idea2strategy/backend/operatortrust/` (`OperatorJwt*`, `VerifiedOperatorJwt`, `ProtectedOperatorSubject`, `VersionedOperatorSubjectHmac`, `OperatorBearerAuthenticationService`, `JdbcOperatorIdentityResolver`)
- Create: `backend/modules/backend-operator-trust/src/main/java/com/idea2strategy/backend/operatortrust/OperatorPasswordHasher.java`
- Create: `backend/modules/backend-operator-trust/src/main/java/com/idea2strategy/backend/operatortrust/OperatorTotp.java`
- Create: `backend/modules/backend-operator-trust/src/main/java/com/idea2strategy/backend/operatortrust/OperatorSecretCipher.java`
- Create: `backend/modules/backend-operator-trust/src/main/java/com/idea2strategy/backend/operatortrust/OperatorTokenProtector.java`
- Create tests with matching names under `backend/modules/backend-operator-trust/src/test/java/com/idea2strategy/backend/operatortrust/`

- [ ] Add failing known-answer and tamper tests for Argon2id hashes, 6-digit/30-second RFC 6238 TOTP with only the adjacent window, AES-256-GCM encryption with random 96-bit nonces and operator/credential-version AAD, and length-delimited HMAC digests.
- [ ] Add replay-boundary tests that return the accepted TOTP time step so persistence can atomically reject `step <= last_accepted_step`.
- [ ] Add configuration tests requiring explicit current key versions and keys for TOTP encryption, session HMAC, CSRF HMAC, login/source HMAC, with optional previous read keys only during rotation.
- [ ] Add Bouncy Castle only for Argon2id. Store an encoded Argon2 parameter/version record and implement verify-then-rehash signaling; benchmark the selected development/AWS parameters in a disabled-by-default test and document the measured target of approximately 250 ms on the deployment instance class.
- [ ] Implement constant-time digest comparisons and zero temporary password/seed byte arrays where Java permits. Ensure `toString`, exceptions, and test failure messages never expose secrets.
- [ ] Run `cd backend && ./gradlew :modules:backend-operator-trust:test`.
- [ ] Commit with `git -C backend commit -m "feat(auth): add operator credential cryptography"`.

### Task 4: Implement transactional credential, session, and audit persistence

**Files:**
- Create: `backend/modules/backend-application/src/main/java/com/idea2strategy/backend/application/operatorauth/OperatorCredentialPort.java`
- Create: `backend/modules/backend-application/src/main/java/com/idea2strategy/backend/application/operatorauth/OperatorSessionPort.java`
- Create: `backend/modules/backend-application/src/main/java/com/idea2strategy/backend/application/operatorauth/OperatorAuthAuditPort.java`
- Create: `backend/modules/backend-persistence/src/main/java/com/idea2strategy/backend/persistence/operatorauth/OperatorAuthJdbcAdapter.java`
- Create: `backend/modules/backend-persistence/src/test/java/com/idea2strategy/backend/persistence/operatorauth/OperatorAuthJdbcAdapterIntegrationTest.java`

- [ ] Write failing Testcontainers tests for normalized-login lookup, `SELECT ... FOR UPDATE` credential verification, atomic failed-attempt/lock updates, atomic TOTP-step consumption, credential-version increment with full session revocation, idle/absolute expiry, CSRF rotation, last-use touch, logout/revoke-all, and fourth-session oldest eviction.
- [ ] Add audit tests for success/rejection/lockout/logout/revocation/password reset/TOTP replacement/reauthentication using privacy-safe action/reason codes and HMAC identifiers only.
- [ ] Implement one JDBC adapter whose public operations define the transaction boundary. Use database time for security timestamps and deterministic ordering (`created_at`, then session ID) for the three-session cap.
- [ ] Rate-limit last-use writes to once per minute while still enforcing the 15-minute idle deadline from the authoritative stored value plus the current request time.
- [ ] Ensure a disabled operator, compromised credential, version mismatch, expired/revoked session, missing audit write, or SQL ambiguity rolls back and rejects.
- [ ] Run `cd backend && ./gradlew :modules:backend-persistence:test --tests '*OperatorAuthJdbcAdapterIntegrationTest'`.
- [ ] Commit with `git -C backend commit -m "feat(auth): persist operator credentials and sessions"`.

### Task 5: Implement authentication, throttling, and reauthentication services

**Files:**
- Create application records/services under `backend/modules/backend-application/src/main/java/com/idea2strategy/backend/application/operatorauth/`
- Create: `backend/modules/backend-operator-trust/src/main/java/com/idea2strategy/backend/operatortrust/OperatorLoginThrottle.java`
- Create: `backend/modules/backend-operator-trust/src/main/java/com/idea2strategy/backend/operatortrust/RedisOperatorLoginThrottle.java`
- Create corresponding unit tests under both modules

- [ ] Write failing service tests for generic `401 OPERATOR_AUTHENTICATION_REJECTED` across unknown login, wrong password/TOTP, disabled operator, incomplete enrollment, replayed TOTP, and compromised credential.
- [ ] Add tests for bounded exponential delay, per-login and per-source Redis buckets including unknown logins, stable non-enumerating `429 OPERATOR_AUTHENTICATION_RATE_LIMITED`, and fail-closed Redis failure.
- [ ] Add tests for a 15-minute idle lifetime, 8-hour absolute lifetime, maximum three sessions, logout, session inspection/CSRF rotation, and reauthentication that refreshes only `mfa_verified_at` and CSRF without extending absolute expiry.
- [ ] Implement login normalization as Unicode NFKC plus locale-independent lowercase and a strict bounded character policy; hash normalized values before throttle/audit keys.
- [ ] Implement password verification before TOTP decryption, but perform a calibrated dummy Argon2id verification for unknown/ineligible credentials to reduce enumeration timing differences.
- [ ] Make reauthentication require the current valid session plus password and a newly accepted TOTP step.
- [ ] Run `cd backend && ./gradlew :modules:backend-application:test :modules:backend-operator-trust:test`.
- [ ] Commit with `git -C backend commit -m "feat(auth): enforce operator login and session policy"`.

### Task 6: Expose the same-origin session API and CSRF boundary

**Files:**
- Create: `backend/apps/backend-api/src/main/java/com/idea2strategy/backend/api/operatorauth/OperatorAuthController.java`
- Create: `backend/apps/backend-api/src/main/java/com/idea2strategy/backend/api/operatorauth/OperatorAuthConfiguration.java`
- Create: `backend/apps/backend-api/src/main/java/com/idea2strategy/backend/api/operatorauth/OperatorAuthExceptionHandler.java`
- Create: `backend/apps/backend-api/src/main/java/com/idea2strategy/backend/api/operatorauth/OperatorCsrfFilter.java`
- Create tests under `backend/apps/backend-api/src/test/java/com/idea2strategy/backend/api/operatorauth/`
- Modify: `backend/apps/backend-api/src/main/resources/application.yaml`

- [ ] Write MockMvc tests for `POST /api/v1/operator-auth/sessions`, `GET /api/v1/operator-auth/session`, `POST /api/v1/operator-auth/logout`, and `POST /api/v1/operator-auth/reauthenticate` with exact generic statuses and correlation IDs.
- [ ] Test the production `Set-Cookie` contract exactly and test the explicit local HTTP cookie profile separately. Reject an invalid combination such as production mode with `Secure=false` at startup.
- [ ] Test CSRF enforcement for every authenticated mutation using `X-Operator-CSRF`, origin/fetch-metadata validation, and the stored HMAC digest. Verify session inspection re-derives the current token without rotating it, while successful reauthentication increments the generation. Exempt only login and safe methods; logout and reauthentication remain protected.
- [ ] Return the raw CSRF token only in the successful login/session-refresh/reauth response. Set `Cache-Control: no-store`; never echo password, TOTP, cookie, or token material in errors.
- [ ] Replace OIDC/JWKS properties in `application.yaml` with explicit durations, cookie mode, Redis endpoint, and versioned secret bindings.
- [ ] Run `cd backend && ./gradlew :apps:backend-api:test --tests '*OperatorAuth*'`.
- [ ] Commit with `git -C backend commit -m "feat(auth): expose operator session endpoints"`.

### Task 7: Replace bearer identity resolution without changing RBAC behavior

**Files:**
- Modify: `backend/modules/backend-application/src/main/java/com/idea2strategy/backend/application/operatorrbac/OperatorRequestContext.java`
- Replace: `backend/modules/backend-operator-trust/src/main/java/com/idea2strategy/backend/operatortrust/ServletBearerOperatorRbacContext.java` with `ServletSessionOperatorRbacContext.java`
- Modify: `backend/modules/backend-operator-trust/src/main/java/com/idea2strategy/backend/operatortrust/OperatorTrustModuleConfiguration.java`
- Modify existing operator RBAC, sanction, case, competition, and journey tests that construct `OperatorRequestContext`
- Delete obsolete JWT/OIDC trust tests including `OperatorCognitoMfaConfigurationTest.java`

- [ ] First change tests to require a valid session-backed `OperatorRequestContext` carrying operator ID, TOTP verification time, and session ID; remove `trustedExternalSubject` assertions.
- [ ] Keep `mfaCompleted`/freshness semantics compatible with existing RBAC guard services, changing the high-risk freshness default to the approved 15 minutes.
- [ ] Make `CurrentOperatorRbacContext.current()` resolve the cookie session on every request and re-read current operator status/credential version; never cache role or permission results in the session.
- [ ] Run targeted RBAC, sanction, case, competition, and exact-stack journey tests, then `cd backend && ./gradlew test`.
- [ ] Verify `rg -n "Bearer|JwtDecoder|external_identity_key|trustedExternalSubject" backend/modules/backend-operator-trust backend/apps/backend-api` returns no human-operator trust path.
- [ ] Commit with `git -C backend commit -m "refactor(auth): resolve operator RBAC from server sessions"`.

### Task 8: Move bootstrap, provisioning, and recovery to audited CLI-only commands

**Files:**
- Modify: `backend/apps/idea2strategy-cli/src/main/java/com/idea2strategy/cli/OperatorBootstrapCommand.java`
- Create: `backend/apps/idea2strategy-cli/src/main/java/com/idea2strategy/cli/OperatorCredentialProvisionCommand.java`
- Create: `backend/apps/idea2strategy-cli/src/main/java/com/idea2strategy/cli/OperatorCredentialResetCommand.java`
- Modify: `backend/modules/backend-application/src/main/java/com/idea2strategy/backend/application/operatorbootstrap/OperatorBootstrapManifest.java`
- Modify: `backend/modules/backend-persistence/src/main/java/com/idea2strategy/backend/persistence/operatorbootstrap/JdbcOperatorBootstrapAdapter.java`
- Add/modify CLI and bootstrap tests under the matching test packages

- [ ] Write process-level tests proving passwords and TOTP confirmation are read from hidden stdin/console, not flags, environment variables, manifests, stdout, or process listings.
- [ ] Make initial bootstrap atomically create the stable operator, Argon2 credential, encrypted TOTP enrollment, initial role, immutable receipt, and audit row only after the operator enters a valid TOTP code.
- [ ] Add separate provision/reset commands requiring an explicit operator UUID and dedicated database role. Reset increments credential version, revokes all sessions, replaces the password/TOTP seed, and audits without exposing the seed after enrollment.
- [ ] Keep public HTTP, UI, and MCP registration/reset/TOTP-disable routes absent; add a source scan test for prohibited route annotations.
- [ ] For AWS, document execution through interactive SSM Session Manager; for local development, use the same installed CLI against the Compose database.
- [ ] Run `cd backend && ./gradlew :apps:idea2strategy-cli:test :modules:backend-persistence:test --tests '*OperatorBootstrap*'`.
- [ ] Commit with `git -C backend commit -m "feat(auth): provision operator credentials through audited CLI"`.

### Task 9: Apply server sessions to browser-mediated admin-mcp

**Files:**
- Modify: `backend/apps/admin-mcp/build.gradle.kts`
- Modify: `backend/apps/admin-mcp/src/main/resources/application.yaml`
- Modify: `backend/apps/admin-mcp/src/main/java/com/idea2strategy/backend/admin/AdminMcpController.java`
- Modify: `backend/apps/admin-mcp/src/main/java/com/idea2strategy/backend/admin/AdminMcpBoundaryConfiguration.java`
- Modify/add tests under `backend/apps/admin-mcp/src/test/java/com/idea2strategy/backend/admin/`

- [ ] Write controller tests proving cookie session resolution, current RBAC evaluation, fresh 15-minute TOTP for approval tools, and CSRF enforcement on every invocation.
- [ ] Remove the `trustedExternalSubject` filter and accept only the new session-backed context. Keep tool registry permission IDs, authorization port, execution port, idempotency, and audit behavior unchanged.
- [ ] Ensure deployed routing presents browser-mediated admin-mcp under the exact same HTTPS host as the session cookie, even if ALB sends its path to a separate target group. Share only versioned session/CSRF HMAC secrets and the database—not a bearer-token compatibility layer.
- [ ] Run `cd backend && ./gradlew :apps:admin-mcp:test`.
- [ ] Commit with `git -C backend commit -m "refactor(auth): secure admin mcp with operator sessions"`.

### Task 10: Replace the UI OIDC client with an in-memory CSRF session client

**Files:**
- Delete: `ui/src/auth/operatorOidc.ts`
- Delete: `ui/src/auth/operatorOidc.test.ts`
- Create: `ui/src/auth/operatorSession.ts`
- Create: `ui/src/auth/operatorSession.test.ts`
- Modify: `ui/src/components/OperatorAuthenticationView.tsx`
- Modify: `ui/src/main.tsx`
- Modify: `ui/src/App.tsx`
- Modify operator API clients under `ui/src/api/`
- Modify: `ui/src/vite-env.d.ts`
- Replace: `ui/e2e/operator-oidc.e2e.ts` and `ui/playwright.operator-oidc.config.ts` with session equivalents
- Delete: `ui/e2e/mockOperatorIdp.ts`

- [ ] Write failing component tests for visible login name/password/TOTP fields, submission loading, generic invalid credentials, rate limit, service unavailable, reauthentication, session expiry, and signed-out redirect with preserved `returnTo`.
- [ ] Write client tests proving `credentials: 'include'`, no Authorization header, CSRF on mutations, `Cache-Control`-safe session restoration, in-memory-only CSRF state, logout cleanup, and a single retry-free 401 transition to signed out.
- [ ] Implement `operatorSession` around the four backend endpoints. On startup call `GET /session`; keep the returned CSRF token only in a module closure/React state and never in localStorage, sessionStorage, IndexedDB, URL, or logs.
- [ ] Update every operator RBAC/case/sanction/competition API client to use the shared credentialed fetch boundary. Customer access-token handling remains unchanged for customer-only APIs.
- [ ] Remove `/operations/callback`, all OIDC configuration, PKCE/nonce/refresh-token code, and the local bearer harness. Keep `/operations/login` visible and usable in development.
- [ ] Replace the Playwright mock IdP journey with real browser-to-backend login, TOTP, protected read, protected mutation/CSRF, reauthentication, logout, expiry, and reload restoration journeys.
- [ ] Run `cd ui && pnpm typecheck && pnpm exec vitest run && pnpm build && pnpm exec playwright test --config playwright.operator-session.config.ts`.
- [ ] Commit with `git -C ui commit -m "feat(auth): use operator password totp sessions"`.

### Task 11: Make local Compose exercise the deployed authentication path

**Files:**
- Modify local Compose/env templates located by `scripts/dev.ps1`
- Modify: `scripts/dev.ps1`
- Modify: `scripts/test-docker-development.ps1`
- Modify relevant local harness tests under `scripts/`
- Modify: `backend/apps/backend-api/src/main/resources/application.yaml`
- Modify: `backend/apps/admin-mcp/src/main/resources/application.yaml`

- [ ] Add a failing local-stack test that rejects any OIDC/JWKS/operator bearer variable and requires Postgres, Redis, versioned local crypto keys, backend API, UI, and admin-mcp on the session path.
- [ ] Generate non-committed local development keys through the existing harness initialization; never write them to tracked env files. Preserve them across ordinary `down/up` and rotate only on explicit reset.
- [ ] Configure localhost cookie mode explicitly. Do not weaken SameSite, HttpOnly, session expiry, TOTP, CSRF, RBAC, or audit behavior.
- [ ] Add a development-only CLI bootstrap helper that remains interactive and creates no bypass account, hard-coded password, hard-coded TOTP seed, or UI shortcut.
- [ ] Run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-docker-development.ps1`, then start the stack with `./scripts/dev.ps1 up -Scope all -WithBackend -NoBrowser` and execute the real operator browser smoke test.
- [ ] Commit backend configuration changes, then root scripts/gitlinks with `git commit -m "feat(dev): run operator sessions in local stack"`.

### Task 12: Replace Cognito runtime secrets and Terraform wiring

**Files:**
- Modify: `infra/terraform/environments/development/runtime.tf`
- Modify: `infra/terraform/environments/development/compute.tf`
- Modify: `infra/terraform/environments/development/locals.tf`
- Modify: `infra/terraform/environments/development/variables.tf`
- Modify: `infra/terraform/environments/development/outputs.tf`
- Modify: `infra/terraform/environments/development/templates/ec2-user-data.sh.tftpl`
- Modify: `infra/terraform/environments/development/edge.tf`
- Replace: `scripts/test-development-cognito-operator-identity.ps1` with `scripts/test-development-internal-operator-auth.ps1`
- Modify: `scripts/test-full-terraform-architecture.ps1`
- Modify: `scripts/test-runtime-deployment-wiring.ps1`

- [ ] Write failing Terraform source tests requiring versioned Secrets Manager values for TOTP AES, session HMAC, CSRF HMAC, and login/source HMAC, plus Redis/database wiring and production cookie mode.
- [ ] Replace issuer/JWKS/audience/MFA-claim variables and `operator_subject_hmac` with internal-auth settings and independent generated secrets. Keep secrets out of outputs, user data logs, Terraform plan summaries, and shell tracing.
- [ ] Remove ALB/operator JWT validation assumptions; the backend/admin-mcp remain the sole identity validators. Preserve HTTPS, WAF, target security groups, health checks, and current RBAC permission variables.
- [ ] Update host secret refresh/redaction logic for every new key and add rotation-version inputs without introducing raw secret outputs.
- [ ] Run `terraform -chdir=infra/terraform/environments/development fmt -check`, `terraform ... validate`, the replacement auth test, full architecture test, and runtime wiring test.
- [ ] Commit with `git commit -m "feat(infra): wire internal operator session secrets"`.

### Task 13: Remove human Cognito from release workflows while preserving AWS OIDC

**Files:**
- Modify: `.github/workflows/development-release.yml`
- Modify: `.github/workflows/development-frontend-release.yml`
- Modify: `scripts/test-development-release-workflow.ps1`
- Modify: `scripts/test-development-frontend-release-workflow.ps1`
- Delete after the staged smoke gate: `infra/terraform/environments/development/operator-identity.tf`
- Delete after the staged smoke gate: `infra/terraform/environments/development/lambda/operator-pre-token/index.mjs`
- Delete obsolete Cognito proposal/validation artifacts under `proposals/cognito-operator-oidc/`

- [ ] First change workflow tests to reject `VITE_OPERATOR_OIDC_*`, Cognito Lambda packaging/artifact transfer, Cognito outputs, and issuer/audience cross-checks.
- [ ] In the same tests, require all existing `permissions: id-token: write`, pinned `aws-actions/configure-aws-credentials`, plan/apply roles, immutable saved-plan checks, and `infra/terraform/ci-identity` validation to remain byte-for-byte or semantically intact.
- [ ] Build the frontend without operator identity secrets; it needs only same-origin API/RBAC public configuration.
- [ ] Keep the Phase A implementation commit/PR capable of retaining Cognito resources while every application acceptance path is disabled. After Phase A smoke evidence, create a separate Phase B cleanup commit/PR that deletes `operator-identity.tf`, the transformer, variables, outputs, and proposal artifacts; its Terraform plan must contain only the expected Cognito/Lambda/IAM/log destruction plus reviewed incidental changes.
- [ ] Execute Phase B as two operator-reviewed actions: first disable Cognito deletion protection with a separately saved plan; only after that succeeds, review a new saved plan that destroys the pool/client/domain/Lambda/IAM/log resources.
- [ ] Account for Cognito deletion protection explicitly in Phase B: reviewed plan first disables protection, applies, then a second reviewed plan destroys the resources. Never automate around an unreviewed destructive plan.
- [ ] Remove obsolete Lambda package upload/download/hash steps only after Phase A no longer references the transformer.
- [ ] Run both workflow test scripts and `rg -n "VITE_OPERATOR_OIDC|operator-pre-token|aws_cognito" .github infra/terraform/environments/development scripts` to confirm only staged removal documentation/tests intentionally mention them.
- [ ] Run `rg -n "id-token: write|configure-aws-credentials|role-to-assume" .github/workflows infra/terraform/ci-identity` and compare the AWS OIDC boundary with the pre-change snapshot.
- [ ] Commit with `git commit -m "refactor(deploy): remove human operator Cognito"`.

### Task 14: Update operations, recovery, and launch evidence

**Files:**
- Modify: `docs/backend-and-aws-architecture.md`
- Modify: `docs/backend-implementation-master-checklist.md`
- Create: `docs/infrastructure/internal-operator-auth-runbook.md`
- Modify relevant deployment/readiness runbooks under `docs/infrastructure/`
- Modify/add launch validators under `scripts/`

- [ ] Document first bootstrap, later provisioning, password/TOTP reset, session revocation, operator disable, secret rotation, lockout handling, clock drift, audit lookup, and break-glass escalation using SSM/CLI only.
- [ ] Document the Phase A/Phase B deploy gate, no-dual-auth invariant, exact smoke evidence, and rollback: restore the prior app+Cognito deployment while leaving additive credential/session tables present.
- [ ] Document that Jenkins migration and customer authentication are excluded, and that GitHub Actions AWS OIDC remains the deployment identity.
- [ ] Add launch checks for no operator OIDC/browser bearer code, no raw secrets in logs/state/build output, exact cookie flags, Redis/database fail-closed behavior, RBAC/audit preservation, and admin-mcp session enforcement.
- [ ] Run all new document validators and root launch-readiness checks.
- [ ] Commit with `git commit -m "docs(auth): add internal operator auth operations runbook"`.

### Task 15: Full verification, submodule integration, and staged deployment proof

**Files:**
- Modify root `backend` and `ui` gitlinks after their branches are pushed/reviewed
- No product-code changes unless verification exposes a defect

- [ ] In `backend`, run `./gradlew clean test`, container contract tests, and Testcontainers PostgreSQL integration suites. Confirm no ignored authentication tests and no secret-bearing test output.
- [ ] In `ui`, run `pnpm typecheck`, `pnpm exec vitest run`, `pnpm build`, and the operator-session Playwright suite.
- [ ] At root, run harness/policy, DBML/Flyway, Docker development, Terraform architecture/runtime, release workflow, and launch-readiness checks.
- [ ] Start a clean local stack from the consolidated V1, provision an operator through the interactive CLI, and verify login, session reload, current RBAC, high-risk reauthentication, admin-mcp invocation, logout, expiry, lockout, disabled operator, and credential reset/session revocation.
- [ ] Run secret scans over Git diff, generated frontend assets, container logs, Terraform text plans, and audit rows for raw password/TOTP/session/CSRF/login/source material.
- [ ] Push and review backend and UI commits first; then update root gitlinks and run the full root verification again.
- [ ] Commit the root integration with `git commit -m "feat(auth): integrate internal operator authentication"` and include `Approved product direction: user:kcrmin` in the PR body.
- [ ] Phase A deployment: provision the initial AWS operator through interactive SSM, deploy backend/UI/admin-mcp, and capture internal-login/RBAC/audit smoke evidence while confirming Cognito tokens are rejected.
- [ ] Phase B deployment: review and apply Cognito deletion-protection removal, then separately review and apply Cognito resource destruction. Verify no Cognito billing/runtime resources remain.
- [ ] Confirm GitHub Actions still receives AWS credentials only through OIDC and that no Jenkins credential or job was introduced.

## Expected Commit and Merge Order

1. Root contract/validator commit.
2. Backend schema, crypto, persistence, service, HTTP/RBAC, CLI, and admin-mcp commits.
3. UI internal-session commit.
4. Root DBML/local/infra/workflow/runbook Phase A commits with verified backend/UI gitlinks; retained Cognito resources have no application acceptance path.
5. Phase A deploy and smoke evidence.
6. Separate Phase B cleanup commit/PR, then Cognito removal through two separately reviewed Terraform plans.

The current Flyway rebaseline must remain the ancestor of all schema work. If `feature/local-v1-rebaseline` changes after implementation begins, stop, refresh this branch first, regenerate the single V1 from the canonical database state, and rerun all schema consumers before continuing; never resolve that conflict by adding V2.
