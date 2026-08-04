# Trading live-segment OPENED handoff proposal

Status: **isolated proposal; not canonical and not releasable**

The approved Backend-to-Trading handoff means Backend cannot know the Trading-owned
`bot_events.event_sequence` or authoritative initial state hash when it first creates
`competition.live_evaluation_segments`. Canonical adoption requires a fresh provider
observation and a successful governance check for the new protected fingerprint.

Recommended DBML and forward-migration delta:

- make `competition.live_evaluation_segments.start_event_sequence` and
  `initial_state_hash` nullable only during `PENDING_LEDGER`;
- require the pair to be both null or both present, and require a positive sequence;
- add a deferred invariant trigger that rejects a Participation transition to
  `EVALUATING` while either value is null;
- forbid clearing or changing either value after it is set;
- have Trading's `OPENED` payload carry `botEventSequence` with `botEventId`, so
  Backend can finalize the segment from Trading-owned evidence.

Acceptance requires PostgreSQL tests proving that a pending request commits with the
null pair, an early `EVALUATING` transition fails, the matching `OPENED` event fills the
pair and allows the transition, and a mismatched or second sequence is rejected.
