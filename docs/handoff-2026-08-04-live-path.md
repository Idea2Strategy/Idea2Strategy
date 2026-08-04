# Handoff — 2026-08-04, live path and the two-container fix

Written at the point work stopped so the next agent or admin can resume without re-deriving
anything. Everything described here is merged to `develop` in its own repository and reflected in
the root submodule pointers unless stated otherwise.

## What is now true that was not

The live trading path exists end to end. Before this session a started bot evaluated nothing; the
pieces were all merged and none of them were connected.

```
market-gateway  ──Redis Streams──▶  trading-worker consumer  ──▶  evaluation loop
                                                                      │
  backend release ──▶ bot.launch_contract_plans ──▶ (plan loaded)      ▼
  backend outbox  ──▶ RUN/STOP commands  ──▶ control consumer    order candidates (v3)
                                                                      │
                                                                      ▼
                                          canonical intents, orders, reservations
```

| card / issue | what was actually wrong | PRs |
| --- | --- | --- |
| RT2, trading#106 | no production `BotRuntimeLifecycle`, so a started bot evaluated nothing | trading#120 |
| root#190 | the `strategy-bot.v1` compiled plan had no producer; it existed only as a test fixture | backend#193 |
| B91 | no `StrategyBotControlConsumer` bean, so the RT5 poller never wired and commands sat unread | trading#121 |
| C93 | a room's evaluation *end* held only while B's scheduler was punctual | backend#194 + trading#122 |
| RT3, trading#107 | published market events never reached the loop | trading#123 |
| root#202 | a Basic strategy with a buy container and a sell container could not be released at all | trading#124 + backtest#39 + backend#195 |

Root pointers: #200, #201, #203, #206, #210, #213.

## Defects found while wiring, and fixed

These were latent in already-merged code, not introduced by the wiring:

- **A bot's first trade in any instrument could never be sized.** The composer's mark came only
  from past fills, so an instrument no fill had ever touched was rejected `NO_REFERENCE_PRICE`
  forever — every bot's opening trade. The candidate now carries the reference price the
  evaluation decided on, which is what D's candidate has always carried.
- **A bot starting mid-session died** on `TRIGGER_SEQUENCE_GAP`: the feature runtime requires a
  dense sequence from zero while market sequences start wherever the bot joined. Market ordering
  and feature ordering are now separate concerns.
- **The bot-control checkpoint store and its poller were conditional on each other**, so neither
  could ever wire.

## Decisions recorded so they are not re-litigated

- `requiredObservations` is `required_history_points - 1`: the window counts every point it needs
  *including* the live bar that triggers the evaluation, so warm-up supplies all but that one.
- `instrumentCatalogVersion` is the market date the universe was resolved on. The supported
  universe is a query over listing and symbol effectivity observed on one date, not a published
  artifact.
- A **plan-level order side does not exist** any more, in any of the three runtimes. A Basic
  strategy is one container per side; a single side for the whole plan could only ever describe one
  of them, and that fiction is what made root#202 possible.
- `basic-compiled-plan.v2` is emitted for every new release, single-container included. Version 1
  is still read by both consumers with its original checksums, so previously released bots keep
  loading.
- A container's steps hash **immediately after that container's own flow line**, identically in
  backend, trading-engine and backtest-engine. Anywhere else and a plan fails its checksum on one
  side only, which is indistinguishable from tampering.
- The `CORPORATE_ACTION` approval provider is a **backend adapter D polls**, so operator identity,
  RBAC and the audit trail stay where every other operator action lives.

## Remaining checklist cards — 171 ticked, 7 open

| card | what it needs | who or what unblocks it |
| --- | --- | --- |
| A23 | login/signup/settings/operator screens against real APIs | AWS: a real IdP and ALB, plus browser E2E |
| A90 | one auth subject, RBAC, outbox and audit across B–F | B–F complete, then AWS |
| A91 | deploy, one-shot migration, rollback, `develop→release→main` | AWS deploy targets |
| D14 | Alpaca corporate-action client and the twice-daily research job | in flight; see #209 and #205 |
| D15 | operator approval → official corporate action + adjusted dataset regeneration | A's admin-mcp; contract proposed in root#204 |
| E35 | room create/browse/join, schedule, anonymous leaderboard, my-bot comparison, post-end choice | nothing — the UI has **no** rooms API client and no room views; this is the largest buildable card |
| F92 | reflect an approved corporate action into positions, lots and ledger | **not** blocked on F — see below |

### F92 is the one worth reading before touching it

F's application path is complete and wired: `CorporateActionApplication`, `SplitAdjustment`,
`PostgresCorporateActionStore.apply` (which verifies against canonical and derives every movement
id from `(actionId, positionLotId, botEventId)` so a replay converges instead of splitting twice),
`CorporateActionService` and its bean.

The blocker is not a missing trigger. `ApprovedCorporateAction` requires `approvalId`,
`approvedByOperatorId`, `approvedAt`, `evidenceDigest` and `policyVersion`, and
`market_data.corporate_actions` has **no approval columns at all**. A poller reading canonical
would have to invent an operator and an evidence digest for an adjustment applied to someone's real
position. That is the approval record D15 must produce, and where it lives decides the poller's
shape. Full reasoning: root#143 comment.

## Open issues that are real work, not blocked

- **#188** — sanctioned accounts can still log in and call customer APIs. Security gap, A's area,
  implementable now.
- **#181** — E11 writes F's official ledger and a TRADING-owned `bot` table directly. Ownership
  policy already says who may write; routing it through F is the fix.
- **#207** — C09's symbol-keyed half cannot run on the worker, which has no instrument→symbol
  mapping. Recommended direction: have the gateway publish its availability result rather than
  teach the worker the mapping, since the gateway already computes it.
- **#139** — canonical schema gaps, including the `stream_watermarks (feed_id, shard_key)`
  promotion, which needs a central decision.

## Gaps deliberately left open, with reasons

- **A market event redelivered after a bot restart is evaluated twice.** Re-registration resets the
  bot's view of the market sequence. Deduplicating by the event's own identity across restarts is
  the remaining at-least-once gap on the market path.
- **C09 is half-applied on the worker**: it owns its own consumer lag and stops feeding beyond the
  maximum, because a bot deciding on a bar minutes old is deciding on a market that has moved on.
  Provider connectivity and session state remain the gateway's (#207).
- **backtest-engine has two pre-existing test failures**, both reproducing on a clean checkout and
  untouched by this work: the vendored central-migration copy is 28 migrations stale, and
  `test_the_backend_still_writes_backtest_runs_directly`. The first deserves its own card.

## Local verification notes for whoever continues

- `gradlew test` **must** be run with `--rerun-tasks`; up-to-date checks otherwise report
  BUILD SUCCESSFUL in seconds without executing anything.
- `JAVA_HOME` must be set to the JDK 21 install for `gradlew.bat` to work.
- Every root pointer change was verified locally with `scripts/test-flyway-ci-bundle.ps1` before
  pushing: 35 migrations, 174 application tables, second migrate pending nothing.
- The canonical DBML validator needs Node, which was not installed on this machine; root CI ran
  `pnpm dbml:validate` on every pointer PR instead.
- backtest-engine needs `uv pip install --python .venv/Scripts/python.exe -e ".[dev]"` before its
  suite will run; the checked-in venv lacks the dev extras.
