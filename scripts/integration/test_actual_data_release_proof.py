from __future__ import annotations

import re
from pathlib import Path

from actual_data_release_proof import (
    FIXED_PERIOD,
    ActualDataApi,
    BacktestConflict,
    build_run_schedule,
    submit_schedule,
)

BOT_IDS = {
    "active-long-growth": "00000000-0000-4000-8000-000000000001",
    "single-clock": "00000000-0000-4000-8000-000000000002",
    "mixed-clock": "00000000-0000-4000-8000-000000000003",
    "all-block": "00000000-0000-4000-8000-000000000004",
    "warning-bearing": "00000000-0000-4000-8000-000000000005",
    "no-signal": "00000000-0000-4000-8000-000000000006",
    "typed-unavailable": "00000000-0000-4000-8000-000000000007",
}


def test_local_queue_timeout_cannot_expire_the_required_sequential_proof_batch() -> (
    None
):
    compose = Path(__file__).resolve().parents[2] / "compose.back.yml"
    matched = re.search(
        r'BACKTEST_QUEUED_TIMEOUT_SECONDS:\s*"(?P<seconds>[0-9]+)"',
        compose.read_text(encoding="utf-8"),
    )

    assert matched is not None
    assert int(matched.group("seconds")) >= 7200


def test_schedule_is_twenty_fresh_sequential_requests_over_every_required_shape() -> (
    None
):
    schedule = build_run_schedule(BOT_IDS, batch_seed="task4-20260901")

    assert len(schedule) == 20
    assert [item.scenario for item in schedule].count("active-long-growth") == 3
    assert [item.scenario for item in schedule].count("single-clock") == 3
    assert [item.scenario for item in schedule].count("mixed-clock") == 3
    assert [item.scenario for item in schedule].count("all-block") == 3
    assert [item.scenario for item in schedule].count("warning-bearing") == 2
    assert [item.scenario for item in schedule].count("no-signal") == 3
    assert [item.scenario for item in schedule].count("typed-unavailable") == 3
    assert len({item.idempotency_key for item in schedule}) == 20
    assert all(item.period == FIXED_PERIOD for item in schedule)


def test_api_submits_the_exact_fixed_dates_and_does_not_put_identity_in_payload() -> (
    None
):
    calls = []

    def transport(method, url, body, headers):
        calls.append((method, url, body, headers))
        return 202, {
            "messageId": "message-1",
            "eventType": "CUSTOM_BACKTEST_REQUESTED",
            "created": True,
        }

    api = ActualDataApi("http://localhost:15173", "opaque-access", transport)

    result = api.submit(
        BOT_IDS["single-clock"], "task4-20260901-single-clock-01", FIXED_PERIOD
    )

    assert result == {
        "messageId": "message-1",
        "eventType": "CUSTOM_BACKTEST_REQUESTED",
        "created": True,
    }
    assert calls == [
        (
            "POST",
            "http://localhost:15173/api/v1/bots/00000000-0000-4000-8000-000000000002/backtests",
            {"periodStart": "2016-01-01", "periodEnd": "2026-07-29"},
            {
                "Accept": "application/json",
                "Authorization": "Bearer opaque-access",
                "Content-Type": "application/json",
                "Idempotency-Key": "task4-20260901-single-clock-01",
            },
        )
    ]


def test_submit_schedule_proves_same_key_replay_and_conflicting_payload_rejection() -> (
    None
):
    schedule = build_run_schedule(BOT_IDS, batch_seed="task4-20260901")[:2]

    class FakeApi:
        def __init__(self):
            self.calls = []

        def submit(self, bot_id, key, period):
            self.calls.append((bot_id, key, period))
            if key == schedule[0].idempotency_key and period != FIXED_PERIOD:
                raise BacktestConflict()
            index = next(
                index
                for index, request in enumerate(schedule, start=1)
                if request.idempotency_key == key
            )
            return {
                "messageId": f"message-{index}",
                "eventType": "CUSTOM_BACKTEST_REQUESTED",
                "created": len(self.calls) <= len(schedule),
            }

    api = FakeApi()

    proof = submit_schedule(api, schedule)

    assert proof.message_ids == ("message-1", "message-2")
    assert proof.replayed_message_id == "message-1"
    assert proof.conflict_rejected is True
    assert len(api.calls) == 4
    assert api.calls[-1][2] == {"periodStart": "2016-01-01", "periodEnd": "2026-07-28"}
