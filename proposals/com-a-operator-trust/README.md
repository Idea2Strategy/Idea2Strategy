# COM-A operator authentication and permission-read proposal

This isolated proposal defines the missing production trust boundary shared by backend A22 and UI A23. It does not modify `specs/**`, `contracts/**`, infrastructure, or application code before product-authority approval.

Tracking issue: [COM-A #165](https://github.com/Idea2Strategy/Idea2Strategy/issues/165).

## Recommended decision

- Operator and `admin-mcp` requests use a dedicated short-lived OIDC JWT access token. A normal customer session token never authorizes operator work.
- The HTTPS ALB validates JWT signature, issuer, time claims, audience, and required assurance claims before forwarding.
- The backend independently validates the same bearer JWT and derives identity only from verified claims. Edge validation is defense in depth, not an authorization oracle.
- Raw `X-Operator-*`, `X-User-*`, `X-Amzn-Oidc-Identity`, servlet principal names, and role headers never grant authority.
- Operator identity is the HMAC of a length-delimited `(issuer, subject)` pair, then mapped to exactly one active `operations.operator_accounts` row.
- MFA is true only when the current signed token contains an approved `acr` or `amr` value and a sufficiently recent `auth_time`. Enrollment or a historical DB timestamp alone is not current proof.
- Initial catalog activation and first-operator grant use an audited one-shot deployment command through SSM; there is no public bootstrap endpoint.
- The UI receives only its own effective permissions and versioned catalog/read projections through authenticated, permission-guarded APIs.
- The additive schema proposal records the operator subject-HMAC key version and an immutable idempotent bootstrap receipt; canonical DBML remains unchanged before approval.

## AWS compatibility

The selected ingress is already an Application Load Balancer. AWS documents an HTTPS `jwt-validation` listener action that validates JWT signature and time/issuer claims and can validate additional claims. The target still validates the bearer token and remains reachable only from the ALB security group.

- https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-verify-jwt.html
- https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-authenticate-users.html

## Rollout order

1. Product-authority review of this exact proposal.
2. Canonical security/API contract integration.
3. Additive identity-key-version/bootstrap-receipt migration, then IdP client, ALB listener rules, Secrets Manager references, and target isolation.
4. Backend JWT verifier and operator context replacement while old header/principal paths remain disabled.
5. One-shot bootstrap, permission read APIs, admin-mcp token handling, and audit.
6. A22 security/E2E and A23 operator UI/browser E2E before enablement.

## Rollback

Before operator traffic is enabled, the listener rule and verifier can remain disabled while the additive columns and receipt table remain unused. After a bootstrap receipt or verified operator audit exists, rollback is forward-fix only: disable operator routes, preserve identity/audit rows, and deploy a compatible verifier correction.
