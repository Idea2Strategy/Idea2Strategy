# Release-proof verification evidence

Observed on 2026-09-03 KST from the isolated `codex/release-proof` worktree. Raw
browser, soak, chaos, SLO, and resource receipts remain ignored under
`.local/artifacts/release-proof/`. This report intentionally excludes account
identifiers, credentials, bearer/session material, signed URLs, and private
filesystem paths.

## Candidate identity

- Root checkpoint `100e1a20f8ee9a587050c9aee0d016d4394571e2` is an ancestor of the release-proof branch.
- Backend PR [#291](https://github.com/Idea2Strategy/Idea2Strategy-backend/pull/291) merged to `develop` as `62b43e38b92673cbb10b34b646fdd66bf00f776c`.
- Backtest PR [#99](https://github.com/Idea2Strategy/Idea2Strategy-backtest-engine/pull/99) merged to `develop` as `a568df09ba26a836eeec68f281ea3a5642aeecad`.
- UI PR [#184](https://github.com/Idea2Strategy/Idea2Strategy-ui/pull/184) merged to `develop` as `ce32bf42747395502c034c2831c02a7220119a10`.
- The three merged component trees are byte-identical to the reviewed candidate trees.
- The refreshed Flyway bundle pins those exact Backend and Backtest merge commits. Its bundle SHA-256 is `de2aaf3da97f0197a1d4d3d953ec678bbd6ce9926305caeebef7292d61d33768`.

## Actual data and browser journey

- The transferred archives passed the supplied SHA-256 manifest before restore.
- The restored versioned MinIO corpus contains 198 actual AAPL `xl.meta` objects. The real benchmark corpus contains 88 SPY/QQQ manifests. No generated OHLCV or benchmark fixture was used.
- A direct `/backtests/{runId}` navigation regression test first reproduced the route stall while the competition lazy module and preferences request were held pending. The minimal UI fix moved the result route to its own lazy module; the focused test proves it renders without requesting `OperationsViews`.
- The final merged-tree browser run opened the CLI-authored 14-block catalog across 30-minute, 1-hour, 4-hour, and daily partitions, then created, saved, validated, released, and executed a new strategy through the actual worker.
- The final run `5c3d1cc2-d21e-3270-b830-089931083ce4` reached `COMPLETED`; result checksum `39da9708739373ac53874fb9abe22a39f0f825132999dc58c65e654b1871aa08`; benchmark comparison `READY`. The test asserted actual SPY/QQQ comparison data, direct hard navigation, and phone/tablet/laptop/desktop layouts.
- Final real-browser results: full Basic journey 2/2; real customer/account and public/secret competition journeys 3/3; mock state, disclosure, responsive, and operator-command journeys 26/26; opaque operator cookie-session/CSRF journey 1/1.

## Soak, deterministic, SLO, and recovery evidence

- Actual service runs: 67 total. The 40-run soak produced 34 `COMPLETED` and six typed `UNAVAILABLE` results. The six expected strategy-level rejections were all `REQUIRED_INPUT_UNAVAILABLE`; engine/lifecycle defect count was zero.
- Deterministic gate: five consecutive passes. Every step exited zero, durable row growth was zero in every iteration, and semantic/result-hash sets remained stable.
- Full-history unsaturated SLO probes: 20/20 `COMPLETED`; dequeue-to-terminal p95 `6.883151s` against a `600s` limit; request-to-terminal maximum `18.453423s` against a `900s` ceiling.
- Chaos and replay evidence: queued cancellation completed with zero attempts; stale lease reclaim recorded `LEASE_EXPIRED` then succeeded on attempt two; max-attempt exhaustion failed after five attempts with `MAX_ATTEMPTS_EXHAUSTED`; same-key replay returned the stable receipt and conflicting content was rejected.
- Chaos observations include seven terminal service runs: four `CANCELLED`, two `COMPLETED`, and one `FAILED`, with ten attempts in total.
- Exact 40-run footprint: 40 runs, 40 attempts, 40 input pins, 34 summaries, and 44,682 detail rows.
- Resource sampling: 77 samples; queue depth peak 20; worker file descriptors 21 to 21 with peak 22; RSS 729,388 KiB to 731,472 KiB with peak 1,034,616 KiB.
- Integrity queries returned zero orphan attempts, duplicate manifests, invalid terminal timestamps, stale claims, nonterminal max-attempt runs, and unbalanced ledgers.

## Final gates

- Root: 57/57 Node contract tests; DBML 174 tables; contract registry 7/7; Basic conformance 14 cases; UI/API parity 83 frontend routes against 113 backend mappings; release-protected contracts 3/3; local secret-hook tests 2/2.
- Backend: full Gradle `check` passed on the reviewed tree. The persistence integration portion completed successfully; shutdown warnings occurred only after its ephemeral PostgreSQL containers had been removed.
- Backtest: Ruff lint passed; the intentionally scoped formatter gate passed 26 files; mypy passed 74 source files; Docker-free pytest passed 1,418 with two skips and 241 deselections; Docker pytest passed 241 with 1,420 deselections.
- UI: Vitest passed 58 files and 688 tests; TypeScript check, production build, and production bundle assertion passed.
- Flyway: deterministic refresh passed; fresh PostgreSQL 16 install and validate applied ten migrations, produced 185 application tables, passed runtime-grant and trading projection fixtures, and reported zero pending migrations on the second run.
- Docker development configuration validation passed, including localhost-only ports and opt-in application profiles. Final locally rebuilt Frontend, Backend, and Backtest endpoints returned HTTP 200.
- Remote component checks were green before merge: UI 5/5, Backend 2/2, Backtest 9/9 including dependency/secret scan and PostgreSQL/LocalStack integration.

The dedicated AWS previous-release upgrade rehearsal was not represented as
passed because its mandatory `docs/evidence/INT02-aws.md` `root_sha` receipt is
not present in this checkout. No substitute ref was invented. The transferred
real local PostgreSQL volume accepted the current idempotent Flyway startup, and
the current bundle's fresh-install, validate, and second-run gates are recorded
above.

## Review result

Independent scoped reviews covered Task 6, all Task 7 corrections, and the full
merge-base-to-candidate diffs for Backend (27 files), Backtest (36 files), and UI
(13 files). Final result: Critical 0, Important 0, Minor 0. Receipts were also
checked for credentials, account identifiers, and signed URLs; none were found.
