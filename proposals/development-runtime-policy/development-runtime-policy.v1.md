# Development runtime policy proposal

Status: **unapproved proposal**. This file is intentionally outside `specs/` and
`contracts/`. It does not authorize a protected canonical change or a release.

## Approval target

- Repository/HEAD at preparation: `Idea2Strategy/Idea2Strategy`
  `17db9fe6b9f0e519619907fcb9abdb7bf00391c3`
- Protected fingerprint observed before preparation:
  `sha256:f178f50d868a30b8fb4e87043c1213d3b47bc01d1a70f918478e979be2cd018f`
- Required provider evidence: one fresh GitHub approval from an authority accepted
  by both the repository gate and the release operator's authority allow-list.
- Current gate result: `unknown`; no protected source may be edited from this
  proposal until `stackcord governance check --json` passes for the exact head and
  fingerprint.

## Recommended Development decisions

### Backtest execution policy

- Publish one immutable Development policy per strategy release quarter.
- First policy: `development-official-backtest-2026-q3-v1` for release quarter
  `2026-Q3`, evaluating the ten complete ET calendar years from
  `2016-07-01T04:00:00Z` through `2026-07-01T04:00:00Z`.
- Use the implemented deterministic model pins:
  `market-bars-v2`, `backtest-calculation-v1`, `market:1.0.0`,
  `accounting:1.0.0`, and `precision:1.0.0`.
- Use fee rate `0.002` and fixed slippage `5` bps. These match the cross-engine
  conformance fixture but remain product values requiring explicit approval.
- Use 90-day GTC and maximum order horizons, matching the database constraint.
- Assign new non-placeholder UUIDs to the fee and buying-power-buffer policy rows;
  persist the same UUIDs in PostgreSQL and the immutable policy document.

### Backtest runtime safety policy

- Attempts: maximum 3; 300-second lease; 1,800-second wall timeout;
  900-second CPU limit; 1 GiB memory limit. The increased per-attempt limits
  are required by the approved fixed 2016-2026 evaluation window and remain
  below the development backtest host's 4 GiB capacity.
- Microstructure: version `development-microstructure-v1`, maximum volume
  participation 1,000 bps, and a 1-bp buying-power buffer.
- Fractional trading: allow only instruments marked fractional by the reviewed
  provider/catalog import; publish the exact immutable instrument-ID set.
- Initial Development risk ceilings: strategy notional USD 1,000,000; gross
  exposure USD 1,000,000; single-instrument exposure USD 250,000. Lower bot and
  partition limits continue to win. Raising these values requires a new policy
  version; the runtime never silently falls back.
- Keep the confirmed Basic/Custom/Competition concurrency at 2/1/1, total 4,
  with excess work remaining in the three durable queues.

### Market-data/provider rights and instrument materialization

- Provider/feed: Alpaca SIP only for the initial Development release.
- Treat credentials as authentication, not license evidence. Generate the
  rights-evidence document only after a live SIP entitlement/subscription probe.
- Evidence expires no later than 24 hours after verification. Expired or failed
  evidence keeps Market Gateway unready and blocks trading.
- Import only active, tradable US equities and ETFs returned by Alpaca that also
  have a canonical instrument row. Preserve canonical UUIDs; never generate a
  different UUID merely because a ticker changed.
- The first release may expose only the intersection already present in the
  verified historical dataset. Unsupported symbols fail closed in authoring,
  backtest, and trading rather than receiving synthetic data.
- Historical objects and warm-up manifests remain immutable and checksum/version
  pinned. Provider redistribution is disabled; users receive derived service
  results, not raw SIP data.

### Strategy catalog

- Enable only the reviewed, migration-seeded Basic element catalog in the first
  Development release.
- Keep Pro-only, unseeded, or formula-ambiguous elements unavailable. A UI element
  is not executable merely because it renders.
- Require cross-engine conformance for every enabled element and fail bot release
  when a selected instrument, required feature, or execution-policy version is
  unavailable.

### Development SLO and recovery targets

- Development is single-region and cost-optimized, with no customer-facing
  availability commitment. Operational target: 99.0% monthly availability while
  the environment is intentionally enabled.
- RDS: seven-day automated backups, deletion protection, private networking,
  target RPO 24 hours and RTO 4 hours. Restore verification is required before a
  production claim.
- Runtime recovery: Core target 30 minutes; queued Backtest/Pipeline work is
  at-least-once and may be retried; scheduled Trading fails closed if warm-up,
  SIP, database, Redis, or policy evidence is unavailable.
- Alarm acknowledgement target: 30 minutes during an announced test window;
  otherwise next business day. Retain application logs 30 days and immutable
  deployment/approval receipts at least 90 days.
- No multi-AZ/NAT/ALB is added for Development. Production availability and
  support commitments require a separately costed architecture decision.

### Operator identity

- Use an Okta Development/Integrator organization with a dedicated custom
  authorization server and public Authorization Code + PKCE S256 SPA client.
- Issue RS256 access tokens with one exact audience, `auth_time`, and an approved
  MFA `acr` or `amr` value. Disable implicit flow and client secrets in the SPA.
- Register only the final HTTPS service callback/logout URIs. Real MFA success and
  stale, wrong-audience, customer, and non-MFA rejection are deployment gates.
- This recommendation does not create an Okta account or accept vendor terms on
  another person's behalf; an organization owner must perform that external step.

## Approval consequences

Approval authorizes preparation of versioned Development runtime artifacts and a
protected canonical follow-up. It does not authorize production, raw-data
redistribution, actual brokerage, customer funds, or bypassing legal/provider
review. Rejection leaves all affected runtimes fail-closed; Core read-only health
may be deployed, but the overall service cannot be called Deploy Ready.
