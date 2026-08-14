# Internal operator authentication runbook

Approved product direction: `user:kcrmin` (2026-08-13). Human administrators use a dedicated login name, Argon2id password, TOTP, and an opaque database session. Customer authentication is separate. GitHub Actions continues to assume AWS roles through OIDC; Jenkins is excluded.

## Bootstrap

Run the installed CLI from a local administrative shell or an interactive SSM Session Manager shell with the bootstrap database role. Supply the reviewed manifest and SHA-256. The manifest contains the normalized login name but no password, TOTP seed, or crypto key.

```text
idea2strategy operator bootstrap --manifest reviewed-operator-bootstrap.json --expected-sha256 <sha256>
```

Hidden standard input is, in order: password, base64 TOTP seed, and the current six-digit code. Required deployment environment values are `OPERATOR_AUTH_TOTP_KEY_VERSION` and `OPERATOR_AUTH_TOTP_KEY`. Do not place these values in shell history, command arguments, tickets, manifests, or logs.

Verify `/operations/login`, `/api/v1/operator-auth/session`, `/api/v1/operations/me`, one permission-guarded mutation, reauthentication, logout, and the corresponding `operations.audit_events` rows before exposing the operations UI.

## Provisioning and credential reset

Use the installed CLI only from a local administrative shell or interactive SSM session. Both commands require `I2S_BOOTSTRAP_JDBC_URL`, `I2S_BOOTSTRAP_DB_USER`, `I2S_BOOTSTRAP_DB_PASSWORD`, the exact dedicated role in `I2S_OPERATOR_CREDENTIAL_DB_ROLE`, an audited deployment actor UUID in `I2S_OPERATOR_CREDENTIAL_ACTOR_ID`, and the TOTP encryption key/version. The target operator UUID is mandatory and is never inferred from a customer account.

```text
idea2strategy operator credential-provision --operator-id <uuid> --login-name <normalized-login>
idea2strategy operator credential-reset --operator-id <uuid>
```

For either command, hidden standard input is password, base64 TOTP seed, then the current six-digit confirmation code. Provisioning requires an existing active operator without credentials. Reset locks the credential row, increments its version, replaces password and TOTP material, clears lock/replay state, revokes every active session, and appends an audit event in the same transaction. Neither command returns credential material.

## Incidents and recovery

- Disable an operator by setting the reviewed `operator_accounts.status` lifecycle through the administrative boundary. Existing sessions fail on the next request.
- A credential reset must increment `credential_version`, replace the Argon2 hash and encrypted TOTP seed, clear replay/lock counters, revoke every active session, and write an audit event in one transaction.
- Treat database, Redis/throttle, key lookup, decryption, or clock failures as authentication failures. Never bypass TOTP in the UI.
- Rotate one versioned key domain at a time. Keep the previous read key only for the rotation window; new writes use the current version. TOTP-key rotation requires re-encryption.
- For TOTP clock drift, repair NTP first. The verifier accepts only one adjacent 30-second window and rejects replayed steps.

## Deployment

Deploy backend, UI, and admin-mcp together. Production uses `__Host-operator_session; Secure; HttpOnly; SameSite=Strict; Path=/`; localhost uses the non-Secure `operator_session` name only. Cognito resources are removed in a reviewed Terraform plan after the internal-login smoke test. Never apply an unreviewed destructive plan.

Rollback restores the prior application release. The additive credential/session schema may remain. GitHub Actions AWS OIDC (`id-token: write` plus `aws-actions/configure-aws-credentials`) must remain enabled.
