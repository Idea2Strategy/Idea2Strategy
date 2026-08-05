# Alpaca IEX Development fallback proposal (unapproved)

Status: isolated proposal; not approved, integrated, deployable, or canonical.

## Why this decision is needed

The Development paper credentials were observed to return HTTP 200 for an IEX snapshot and
HTTP 403 for a SIP snapshot. That observation proves only that the tested credentials could read
IEX at that instant. It does not authorize fabricating SIP rights evidence, and it is not by itself
an indefinite entitlement receipt.

The current runtime cannot be pointed at IEX safely by changing only the WebSocket URL:

- its provider-rights gate requires `provider=alpaca, feed=sip`;
- its parser writes `feed=SIP` into every Redis market-event envelope;
- Terraform pins an `alpaca-sip-rights.json` path and the SIP WebSocket endpoint.

Changing only the endpoint would therefore either fail closed or falsely label IEX prices as SIP.

## Proposed Development-only behavior

Approve `trading_market_data_feed = "iex"` as an explicit Development fallback while SIP is not
available. The runtime must bind all of these values to that single selection:

| Boundary | IEX value |
| --- | --- |
| Provider | `ALPACA` (unchanged) |
| Feed in Redis market-event envelope | `IEX` |
| WebSocket endpoint | `wss://stream.data.alpaca.markets/v2/iex` |
| Rights artifact local name | `alpaca-iex-rights.json` |
| Rights artifact contents | `provider=alpaca`, `feed=iex`, current verified/expiry timestamps |

Only `sip` and `iex` are accepted. An official Alpaca endpoint whose path disagrees with the
selected feed is rejected at startup. Missing, expired, or differently labelled rights evidence
continues to fail before credential use and subscription.

SIP remains the default. Returning to SIP is a reversible Terraform input change plus a newly
verified and version-pinned SIP rights artifact; no event is relabelled.

## Compatibility and known limitation

The Redis event schema already carries provider and feed as strings. Trading Worker is
provider-neutral and does not branch on SIP, so `ALPACA/IEX` is an additive vocabulary value and
can drive the live evaluation loop without a schema change.

Data Pipeline's D90 realtime ingestion is intentionally feed-specific: it currently accepts
`ALPACA/SIP` and materializes `ALPACA_SIP_RAW_1M`. It will reject `IEX` rather than silently mixing
the two feeds. Therefore this proposal does **not** claim that IEX realtime events update the SIP
historical catalog, warmup bundle, or backtest datasets. Historical/backtest material remains
bound to its existing immutable feed metadata. Live IEX versus historical SIP price differences
are an accepted Development limitation only if product authority explicitly approves them.

The desired-zero Pipeline corporate-action path is independent of the D90 realtime feed, but D90
must not be enabled against this IEX stream until a separately approved IEX catalog/feed contract,
dataset naming scheme, migration/seed, and compatibility test exist.

## Rights artifact procedure

Do not reuse or rename a SIP artifact. Immediately before the deployment plan:

1. Probe the exact configured Development credentials against Alpaca IEX without logging secrets.
2. On success, create a new JSON artifact whose `provider` is `alpaca`, `feed` is `iex`, and whose
   bounded validity interval reflects the probe policy.
3. Upload it to the versioned runtime-artifact bucket and pin its exact S3 version and SHA-256 as
   `provider-rights`, with local path `alpaca-iex-rights.json`.
4. Plan from `trading_market_data_feed=iex`; Terraform rejects a SIP-labelled local path.
5. After boot, verify the WebSocket subscription, Redis envelope `provider=ALPACA/feed=IEX`,
   availability projection, Trading Worker consumption, and CloudWatch logs.

An HTTP 200 snapshot captured earlier is supporting evidence, not a reusable or false SIP receipt.

## Approval required before integration or deployment

A configured product authority must approve the exact proposal and implementation heads and
explicitly accept all three points:

1. Development live evaluation may use Alpaca IEX while SIP remains unavailable.
2. Live IEX and historical/backtest SIP may differ; they must remain distinctly labelled and must
   never be combined into one SIP dataset.
3. Pipeline D90 realtime materialization stays disabled for IEX until a separate canonical IEX
   feed/catalog change is approved.

After that review, a fresh exact-commit governance observation is still required before any
protected canonical source is changed. This proposal itself changes no `specs/**`, `contracts/**`,
governance, DBML, or migration.

## Prepared implementation and verification order

1. Merge the Trading Engine compatibility change after authority approval and green CI.
2. Advance the reviewed root submodule pointer.
3. Merge the Terraform feed/artifact/endpoint binding after authority approval and green CI.
4. Build and pin the Trading image digest.
5. Generate truthful IEX rights evidence, then run and inspect a saved Terraform plan.
6. Apply only the saved plan and execute the runtime checks listed above.

Until those gates pass, no branch described by this proposal is a release candidate.
