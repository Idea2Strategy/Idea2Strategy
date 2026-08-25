# Market preview and backtest terminal recovery implementation plan

1. Add failing backend contract/application tests for server-anchored 1/3-month windows, metadata, empty/partial states, validation, and authentication. Implement the window query while preserving recent-limit consumers.
2. Add failing data projection tests proving compact payloads retain canonical timestamps and OHLCV without generation or rounding; verify retention covers the longest preview window.
3. Add failing UI client/component tests for the window contract, controlled symbol selection, timeframe/window refetches, exact range labels, partial/empty states, and differentiated HTTP/contract/network errors. Implement the UI behavior.
4. Add failing worker tests proving the last retry becomes FAILED before DLQ, over-limit addressable messages repair run state, permanent/DLQ paths record reasons, and duplicate terminal deliveries do not execute.
5. Add failing persistence tests for atomic attempt/run terminal updates and stale recovery: exhausted queued, expired running retry/fail, live heartbeat protection, expired cancellation, and idempotent repeated passes. Implement the recovery repository/service and periodic worker loop.
6. Expose attempt failure reasons in the backtest UI and extend cancellation/status tests.
7. Rebuild the local Docker services, project actual local Parquet history, run unit/integration/contract/E2E suites, and use the browser to verify AAPL plus multiple instruments for 1/3 months and timeframe changes.
8. Independently read source Parquet and compare literal first/last timestamps and OHLCV rows with Redis, API JSON, and rendered chart state. Run stuck-row recovery and prove no exhausted non-terminal runs remain.
9. Run repository secret checks, inspect diffs for unrelated work, commit each affected repository, update root gitlinks/docs, commit root, and push the current remote branches.
