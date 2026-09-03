# Release-proof Goal handoff — paused during Task 6

**Paused:** 2026-09-02 (Asia/Seoul)
**Plan:** `docs/superpowers/plans/2026-08-31-release-proof-verification.md`
**Spec:** `docs/superpowers/specs/2026-08-31-release-proof-verification-design.md`
**SDD ledger:** `.superpowers/sdd/2026-08-31-release-proof-verification/progress.md` (gitignored; copy separately if the old machine remains available)

## Active Goal

Idea2Strategy의 전략·다중 파티션 시장 데이터·백테스트·장애 복구·UI/API 흐름을 출시 수준으로 반복 검증하고, 발견된 결함을 테스트 주도로 수정하여 실제 로컬 데이터 및 Docker E2E, 전체 테스트, CI, 비밀정보 검사, 커밋·푸시·`develop` 병합까지 완료한다. 완료 기준은 재현 가능한 출시 차단 결함 0건, 정상/실패/취소/재시도/재시작/경계값/복합 전략 검증 게이트 전부 통과, 실제 결과와 원본 데이터 대조 완료이다.

## Remote checkpoint

The work is safely committed and pushed, but intentionally **not merged into `develop`** because Task 6 is incomplete and the real result page still fails to render.

| Repository | Remote branch | Exact commit |
|---|---|---|
| root code checkpoint | `codex/release-proof` | contains `100e1a20f8ee9a587050c9aee0d016d4394571e2`; branch HEAD also includes this handoff document |
| backend | `codex/release-proof-task6-handoff` | `f41d81dcd71c86a7fc0bb9d0d3ad002b4ec7fb15` |
| backtest-engine | `codex/release-proof-task6-handoff` | `28fc4dfa64606e5ab640cc137e53cb4d629244f6` |
| ui | `codex/release-proof-task6-handoff` | `8909196198d749848a925380c88d2cc7c7625a37` |

The root checkpoint pins those exact component commits and contains a refreshed, passing Flyway CI bundle with 10 migrations and 185 application tables.

## Eight-stage status

1. **Complete — baseline the isolated release candidate.** Captured revisions, health, dirty-state and release blockers without changing product code.
2. **Complete — durable release-proof runner.** Added typed, immutable, secret-safe receipt contracts and repeatable gate tooling.
3. **Complete — exhaust the Basic strategy semantic matrix.** Proved UI/catalog/backend/compiler/runtime parity across all Basic blocks, boundaries, loaded partition identities and multi-manifest requirements.
4. **Complete — actual-data strategy corpus.** Ran 20 real-data requests over the fixed `2016-01-01..2026-07-29` period: 17 `COMPLETED`, 3 expected `UNAVAILABLE`; independently reconciled manifest pins, Parquet hashes/OHLCV, triggers, fills, fees, slippage, FIFO PnL, ledgers, equity and result hashes.
5. **Procedurally complete — queue/lease/cancellation/restart chaos.** Proved finite terminal behavior, DLQ/recovery/cancellation/resource paths and object cleanup. The final review left three load-bearing security findings; Task 6 fixed all three and their suites are green, but the combined Task 6 review has not happened yet.
6. **Paused/incomplete — real customer, competition and operator browser flows.** See exact stop point below.
7. **Pending — operational bounds and repeated stability.** At least 30 actual runs, deterministic gate five times, p95/ceiling measurement, leak/drift/orphan queries.
8. **Pending — final verification and delivery.** Full suites, final whole-branch review/fix wave, component PRs/checks/merges, refreshed root pointers, root PR merge, remote `develop` verification, local URL/account report, Goal completion.

## Task 6 work completed before the pause

- Closed the three Task 5 integrity defects with RED-first owner tests:
  - removed broad runtime write authority and routed legitimate attempt/storage changes through narrow database capabilities;
  - provider-only reconciled bytes remain unowned and cannot be compensation-deleted;
  - artifact reissue/cleanup is limited to the producer or its immediate successor.
- Backend migration/ACL tests passed; backtest-engine passed 1,418 non-Docker tests and 241 Docker tests plus Ruff and mypy.
- Fixed local secret placeholder expansion in `dev.ps1`; generated operator/session keys now decode to the exact required 32 bytes instead of corrupting later values.
- UI mock E2E passed 25/25; operator production-session E2E passed 1/1.
- Fresh isolated real-API E2E passed 3/3: public competition, secret competition invitation/re-entry, and signup/login without email verification.
- Mirrored exactly 44 real AAPL 30m market-data objects (11 available annual manifests plus predecessor closure) into the isolated Task 6 stack. All immutable VersionId reads matched stored byte sizes and SHA-256 hashes. No fake/generated market data was used.
- Fixed two distinct annual-manifest boundary defects with owner tests:
  - the selector wrongly rejected the final annual manifest when the requested end was inside it;
  - persistence wrongly required every selected annual manifest to be wholly contained instead of overlap-covering the locked period.
- The final real strategy journey successfully authored, saved, validated and released a strategy; the worker completed the backtest and PostgreSQL showed run `COMPLETED` and attempt `SUCCEEDED`.
- All Task 6-only containers were stopped and removed. Shared containers and source data volumes were not changed.

## Exact stop point and reproduced defect

The real browser journey fails after successful execution when navigating to `/backtests`:

- expected `backtest-live-workspace` to render within 15 seconds;
- the page remains in route loading;
- the retained trace points to a pending lazy `OperationsViews.tsx` module and an aborted preferences request;
- this is now the active owner-boundary investigation. Do not rerun or redesign the worker first—the run already completed correctly.

The next implementation step is a focused hard-navigation owner test for `/backtests`, reproducing the lazy-route/Vite runtime boundary without the full stack. Identify whether the module graph, preference bootstrap, auth/session loader, or route suspense/error boundary owns the hang. Fix the narrow owner with RED/GREEN evidence, then rerun the unchanged deploy-like strategy journey.

## Method that must continue

- Work in an isolated worktree, never the stale outer clone or `develop` directly.
- Read the plan/spec once, then trust the SDD ledger and Git history after compaction/restart.
- Use strict TDD and systematic debugging: observe the failure, reduce to the narrowest owner test, then change production code.
- Use actual local market data only. Never shorten the fixed period or synthesize OHLCV/benchmarks to make a test pass.
- Keep frontend, backend, compiler/runtime, PostgreSQL, queue, object storage and UI state aligned.
- Use deploy-like Docker with task-specific project names/ports; do not destroy shared containers or source volumes.
- For each plan task: fresh implementer, task-scoped reviewer, up to five reviewed fix rounds, ledger rulings at the breaker. Run a broad final review after Task 8.
- Preserve applied Flyway migrations; schema changes are forward-only. Refresh and prove the root Flyway bundle whenever migration-owning gitlinks move.
- Keep credentials in ignored environment files only. Never place IDs/passwords, signing keys, raw receipts, signed URLs or absolute private paths in commits/reports/screenshots.
- Apply the installed MengTo design skills as product constraints, not decoration: real deterministic data, coherent tokens/layout/type, explicit loading/empty/error/permission/recovery states, keyboard/focus/200% zoom/reduced-motion checks, no fake dashboard claims.

## New-computer bootstrap

```powershell
git clone https://github.com/Idea2Strategy/Idea2Strategy.git
cd Idea2Strategy
git fetch origin
git checkout codex/release-proof
git submodule sync --recursive
git submodule update --init --recursive
git status --short --branch
git submodule status
```

Verify that the root history contains the code-checkpoint SHA and that the exact component SHAs match the table above. If a submodule remote refuses the detached commit, fetch its handoff branch explicitly inside that submodule and checkout the exact SHA.

Install/read these skills before acting:

- `superpowers:using-superpowers`
- `superpowers:executing-plans`
- `superpowers:subagent-driven-development`
- `superpowers:systematic-debugging`
- `superpowers:test-driven-development`
- `superpowers:verification-before-completion`
- `browser:control-in-app-browser`
- MengTo: `design-first-ui-prompting`, `operational-enterprise-ai`, `product-proof-saas`, `tailwindcss`, `audit-verify-explain-grade-5`

Run the lightweight checkpoint gates first:

```powershell
node --test scripts/test-secret-scan-git-hook.mjs
& .\scripts\test-local-development-environment.ps1
& .\scripts\test-flyway-ci-bundle.ps1
```

## Local data is not in Git

`git pull` transfers code and schema, **not** the real Parquet/MinIO/PostgreSQL corpus. On the old machine the verified actual-data baseline lives in ignored local artifacts and Docker volumes such as `idea2strategy-postgres-data`, `idea2strategy-minio-data`, and `idea2strategy-localstack-data` (inspect exact current names before exporting). Export or copy the intended local baseline to the new machine without committing it, restore it into task-specific volumes, and independently verify object count, VersionId, byte size and SHA-256 before claiming real-data evidence. If the D-drive source is used, copy it into a project-local ignored directory first so normal development no longer depends on the D drive.

Never copy `.env.docker`, operator keys, passwords, browser storage, access tokens, or signed URLs through Git. Generate fresh local secrets on the new computer.

## Resume prompt

Paste the following into the new Codex task after checking out the branch:

> Continue the active Release-proof Goal from `docs/handoffs/2026-09-02-release-proof-task6-pause.md`. Read that file, `docs/superpowers/specs/2026-08-31-release-proof-verification-design.md`, `docs/superpowers/plans/2026-08-31-release-proof-verification.md`, repository `AGENTS.md`/`CLAUDE.md`, and the SDD ledger if it was copied. Verify that root history contains code checkpoint `100e1a20f8ee9a587050c9aee0d016d4394571e2` and submodules match the handoff table. Re-create an isolated worktree and re-declare the exact active Goal from the handoff. Resume Task 6 only; do not repeat Tasks 1–5. First reproduce the `/backtests` hard-navigation hang with a focused UI owner test, using the retained symptom that a real run was already `COMPLETED`/`SUCCEEDED` while `backtest-live-workspace` never rendered and `OperationsViews.tsx`/preferences stayed pending or aborted. Fix it test-first, restore verified real data into a task-only Docker stack, rerun the unchanged real strategy→release→worker→result journey, then complete the remaining customer/competition/operator state/action/responsive/accessibility inventory. Generate the sanitized browser receipt and perform a fresh scoped Task 6 review/fix loop. Then execute Tasks 7 and 8 without stopping: soak/repetition/SLO/invariant proof, final full suites and secret scans, whole-branch review, component PRs/checks/merges, refreshed Flyway bundle, root PR merge to remote `develop`, local deploy-like re-verification, URL and freshly generated test account report. Do not mark the Goal complete without actual browser and actual local-data evidence.
