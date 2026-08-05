# Cognito operator OIDC assurance proposal

Status: isolated proposal; not approved, integrated, or deployable until the
product-authority gate below passes.

## Why a protected decision is required

The approved operator-trust contract recognizes current MFA only from an exact
approved `acr` value or an approved member of `amr`, combined with a recent
signed `auth_time`. Amazon Cognito access tokens contain `auth_time`, but do not
contain `acr` or `amr` by default. AWS also explicitly prohibits a pre-token
generation Lambda from adding, changing, or suppressing the reserved `acr` and
`amr` claims.

Official evidence:

- <https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-user-pools-using-the-access-token.html>
- <https://docs.aws.amazon.com/cognito/latest/developerguide/user-pool-lambda-pre-token-generation.html>

Consequently, Cognito cannot satisfy the current literal contract without one
reviewed extension. Silently treating group membership, MFA enrollment, or an
unsigned browser assertion as MFA would violate the existing fail-closed rule.

## Proposed narrowly scoped rule

A deployment may configure one exact HTTPS namespaced claim and exact allowed
values as equivalent current-MFA evidence only when all of these controls are
bound to that deployment:

1. The issuer is a dedicated Cognito User Pool with `MfaConfiguration=ON`.
2. TOTP is the only enabled MFA method; device remembering and alternative
   passwordless first factors are not configured.
3. Self-registration is disabled and operators are created by an administrator.
4. The public browser client has no secret, uses Authorization Code + PKCE S256,
   disables implicit/client-credentials grants, and has exact callback/logout
   URLs.
5. A V2 pre-token Lambda adds `aud=<current app client id>` and
   `https://ideatostrategy.com/claims/mfa=cognito:mfa-required` only to supported
   human authentication, initial password-change, and refresh token events.
6. Backend JWT validation remains RS256, exact issuer/JWKS/single audience,
   short token-age, subject mapping, and RBAC validation. The namespaced value
   counts only while the signed Cognito `auth_time` is within the configured MFA
   freshness window. Refresh never advances `auth_time`.
7. Missing, differently named, differently valued, stale, future, wrong-client,
   or unverifiable evidence fails closed.

No customer identity, Cognito group, email address, enrollment timestamp,
historical database timestamp, or frontend state grants operator authority.

## Security delta and accepted risk

This extension is deliberately narrower than treating Cognito as a generic
source of MFA claims, but it is still a security-model change. The namespaced
claim does not prove which TOTP challenge was completed for an individual token.
It proves that the dedicated pool issued a token in a configuration where every
human sign-in must complete the pool-wide TOTP challenge before token issuance.
The Backend therefore trusts the conjunction of the signed issuer, exact client
audience, the immutable claim transformer, pool-wide `MfaConfiguration=ON`, and
recent signed `auth_time`. None of those inputs is sufficient by itself.

The minimum accepted residual risks are:

- a privileged Cognito or Lambda configuration change could create
  configuration drift while the transformer continues to emit the namespaced
  value; Terraform drift review and alerts on `UpdateUserPool`,
  `UpdateUserPoolClient`, `UpdateFunctionCode`, `UpdateFunctionConfiguration`,
  and Lambda permission changes are therefore release and operating controls;
- TOTP is phishable and is weaker than a phishing-resistant hardware factor;
  this proposal accepts that limitation for the small Development operator
  population but does not authorize SMS, email OTP, passwordless first factors,
  remembered-device bypass, federation, or reuse of a customer pool;
- an administrator can create, disable, reset, or recover an operator account;
  those actions require the existing AWS administrative boundary and CloudTrail
  evidence, and they never create an application RBAC mapping or assignment;
- a compromised browser can steal a short-lived bearer token; the UI must use
  Authorization Code + PKCE S256, must not persist access or refresh tokens in
  local storage, and the Backend still limits acceptance by token age, active
  subject mapping, current assignment, and current catalog on every request;
- refresh exchanges do not repeat a TOTP challenge. They remain acceptable only
  because refresh does not advance signed `auth_time`; once the ten-minute MFA
  freshness window expires, high-risk requests fail until interactive MFA is
  completed again.

Any additional app client, identity provider, MFA method, passwordless flow,
device remembering, trigger source, claim value, issuer, or audience is outside
this proposal and requires a new protected decision. A detected drift or an
inability to prove these invariants fails closed; availability is not recovered
by weakening authentication.

## Required verification before protected adoption

Approval and deployment evidence must cover all of the following on exact
commits and a reviewed saved Terraform plan:

1. Static and plan checks prove a dedicated Essentials pool, MFA `ON`, TOTP as
   the sole configured second factor, admin-only user creation, no remembered
   devices or federation, one public client without a secret, code flow only,
   exact callback/logout URLs, five-minute access/ID tokens, and bounded refresh
   lifetime.
2. Transformer unit tests prove V2 human authentication, invitation password
   change, and refresh behavior; exact current client `aud`; the sole namespaced
   claim/value; preservation of unrelated response data; and fail-closed
   handling of unknown event versions, missing clients, unsupported triggers,
   and attempts to substitute reserved `acr`/`amr` claims.
3. Backend tests accept only the exact issuer, JWKS key, RS256 algorithm, single
   audience, claim name/value, active subject mapping, active RBAC state, and
   recent `auth_time`. Missing, stale, future, malformed, duplicated, wrong-key,
   wrong-client, wrong-issuer, inactive-mapping, and revoked-assignment cases
   deny without identity enumeration.
4. A real managed-login Authorization Code + PKCE S256 flow with an
   administrator-invited operator proves temporary-password completion, TOTP
   enrollment, TOTP challenge, token issuance, `/api/v1/operations/me`, and one
   MFA-protected permission. No token may authorize an operator route before
   TOTP completion and application mapping/RBAC bootstrap.
5. Refresh is exercised both before and after the MFA freshness window. The
   refresh after the MFA freshness window must retain the original
   `auth_time` and be denied for MFA-protected work until a new interactive TOTP
   authentication occurs.
6. Revoking the refresh token, disabling the Cognito user, disabling the mapped
   operator, revoking the assignment, retiring the catalog, and introducing a
   safe test of issuer/JWKS unavailability each deny on the documented next
   request or bounded-cache boundary.
7. CloudTrail/CloudWatch evidence and alarms cover pool/client/Lambda drift,
   pre-token invocation errors, repeated authentication failures, and Backend
   issuer/audience/assurance denials without logging tokens or raw subjects.
8. The rollback drill below is executed before the feature is called releasable.

Synthetic JWTs and Lambda unit tests are necessary negative evidence, but they
do not replace the real managed-login and Backend end-to-end proof.

## Staged rollout and rollback

Before protected approval, `enable_cognito_operator_identity=false` and any
deployment using this provider keeps `enable_operator_auth=false`; operator
routes remain unavailable. After the exact rule is approved and the protected
contract and Backend verifier are integrated, rollout is ordered as follows:

1. review a saved Terraform plan, create the dedicated pool/client/Lambda with
   operator authentication still disabled, and verify all configuration and
   monitoring invariants without creating an operator user;
2. create and map the first operator only through the separately reviewed
   one-shot bootstrap procedure, then complete the real browser and negative
   verification above;
3. enable operator authentication in a second reviewed saved plan and verify
   edge, Backend, RBAC, audit correlation, token revocation, and freshness on the
   exact deployed commits.

For an assurance, token-validation, or provider incident, the first rollback is
to apply a reviewed plan with `enable_operator_auth=false`. This makes every
operator and `admin-mcp` route unavailable and must never fall back to customer
sessions, IAM credentials, or header trust. Then revoke the affected app-client
refresh tokens or disable affected Cognito users, preserve CloudTrail,
CloudWatch, application audit, bootstrap receipts, and mapping evidence, and
repair the provider/Backend policy before re-enabling the route.

Do not delete the pool, Lambda, mapping, assignment, or audit data as an
emergency rollback. The pool has deletion protection, and after versioned
subject mapping or bootstrap evidence exists the approved data-lifecycle rule
requires forward-fix. Destruction is a later separately reviewed cleanup only
after mappings are migrated or made unusable and retention/legal-hold duties are
satisfied. Rollback success means authentication is closed, refresh capability
is revoked where necessary, evidence is preserved, and no weaker operator path
exists.

## Exact approval point

Before merging the Backend custom-claim verifier, enabling
`enable_cognito_operator_identity`, setting `enable_operator_auth=true` for this
provider, or creating the AWS resources, run a fresh
`stackcord governance check --json` for the exact protected change commit and
fingerprint. One configured product authority must approve this exact statement:

> For the dedicated Cognito operator pool described in this proposal, accept the
> signed claim `https://ideatostrategy.com/claims/mfa` with the sole value
> `cognito:mfa-required` as equivalent to an approved `acr`/`amr` MFA value,
> subject to the existing signed `auth_time`, issuer, audience, age, subject
> mapping, and per-request RBAC requirements.

After fresh approval, update the protected operator-trust contract to record the
rule, merge provider then Backend then root pointer, and apply only a reviewed
saved Terraform plan.

## User action after deployment

An AWS administrator creates each operator by email. The operator follows the
one-time invitation, changes the temporary password, enrolls a TOTP authenticator,
and completes one real browser login. The operator never creates an AWS IAM user,
access key, app-client secret, or Okta account.

## Cost

The dedicated pool uses Cognito Essentials. Direct Cognito users are free for
the first 10,000 monthly active users; above that the published price is
USD 0.015 per MAU. A small operator set is therefore expected to add USD 0/month.
The pre-token Lambda is one short 128 MiB invocation per token issuance and is
expected to remain inside Lambda's one-million-request and 400,000 GB-second
monthly free tier. CloudWatch log ingestion/storage is the only likely non-zero
amount and should be negligible at operator traffic, with 30-day retention.

Pricing evidence:

- <https://aws.amazon.com/cognito/pricing/>
- <https://aws.amazon.com/lambda/pricing/>
