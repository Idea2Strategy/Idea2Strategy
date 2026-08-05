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
