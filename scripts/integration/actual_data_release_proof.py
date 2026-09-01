"""Submit the finite immutable-actual-data release-proof corpus through public APIs."""

from __future__ import annotations

import json
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass
from types import MappingProxyType
from typing import Any
from urllib.error import HTTPError
from urllib.parse import quote
from urllib.request import Request, urlopen

FIXED_PERIOD = MappingProxyType(
    {"periodStart": "2016-01-01", "periodEnd": "2026-07-29"}
)
_CONFLICT_PERIOD = MappingProxyType(
    {"periodStart": "2016-01-01", "periodEnd": "2026-07-28"}
)
_REPETITIONS = (
    ("active-long-growth", 3),
    ("single-clock", 3),
    ("mixed-clock", 3),
    ("all-block", 3),
    ("warning-bearing", 2),
    ("no-signal", 3),
    ("typed-unavailable", 3),
)


class BacktestConflict(RuntimeError):
    """A same-key request carried a different immutable payload."""


@dataclass(frozen=True, slots=True)
class RunRequest:
    scenario: str
    bot_id: str
    idempotency_key: str
    period: Mapping[str, str]


@dataclass(frozen=True, slots=True)
class SubmissionProof:
    message_ids: tuple[str, ...]
    replayed_message_id: str
    conflict_rejected: bool


def build_run_schedule(
    bot_ids: Mapping[str, str], *, batch_seed: str
) -> tuple[RunRequest, ...]:
    """Return the required twenty requests in their custom-lane submission order."""
    expected = {scenario for scenario, _ in _REPETITIONS}
    if set(bot_ids) != expected or not batch_seed.strip():
        raise ValueError("release-proof bot identities are incomplete")
    return tuple(
        RunRequest(
            scenario=scenario,
            bot_id=bot_ids[scenario],
            idempotency_key=f"{batch_seed}-{scenario}-{repetition:02d}",
            period=FIXED_PERIOD,
        )
        for scenario, count in _REPETITIONS
        for repetition in range(1, count + 1)
    )


def _http_transport(
    method: str,
    url: str,
    body: Mapping[str, str],
    headers: Mapping[str, str],
) -> tuple[int, Mapping[str, Any]]:
    encoded = json.dumps(body, separators=(",", ":")).encode("utf-8")
    request = Request(url, data=encoded, headers=dict(headers), method=method)
    try:
        with urlopen(request, timeout=60) as response:
            status = response.status
            payload = response.read()
    except HTTPError as error:
        status = error.code
        payload = error.read()
    parsed = json.loads(payload) if payload else {}
    if not isinstance(parsed, Mapping):
        raise TypeError("backtest API returned a non-object response")
    return status, parsed


class ActualDataApi:
    def __init__(
        self,
        base_url: str,
        access_token: str,
        transport: Callable[
            [str, str, Mapping[str, str], Mapping[str, str]],
            tuple[int, Mapping[str, Any]],
        ] = _http_transport,
    ) -> None:
        self._base_url = base_url.rstrip("/")
        self._access_token = access_token
        self._transport = transport

    def submit(
        self, bot_id: str, idempotency_key: str, period: Mapping[str, str]
    ) -> Mapping[str, Any]:
        status, result = self._transport(
            "POST",
            f"{self._base_url}/api/v1/bots/{quote(bot_id)}/backtests",
            dict(period),
            {
                "Accept": "application/json",
                "Authorization": f"Bearer {self._access_token}",
                "Content-Type": "application/json",
                "Idempotency-Key": idempotency_key,
            },
        )
        if status == 409:
            raise BacktestConflict()
        if status != 202:
            raise RuntimeError(
                f"backtest API rejected an audit request with HTTP {status}"
            )
        if (
            not isinstance(result.get("messageId"), str)
            or result.get("eventType") != "CUSTOM_BACKTEST_REQUESTED"
            or not isinstance(result.get("created"), bool)
        ):
            raise RuntimeError("backtest API receipt is incomplete")
        return result


def submit_schedule(
    api: ActualDataApi, schedule: Sequence[RunRequest]
) -> SubmissionProof:
    """Submit in order, then prove replay and conflict behavior on the first key."""
    if not schedule:
        raise ValueError("release-proof schedule is empty")
    message_ids: list[str] = []
    for request in schedule:
        receipt = api.submit(request.bot_id, request.idempotency_key, request.period)
        if receipt.get("created") is not True:
            raise AssertionError(
                "fresh release-proof submission did not return created=true: "
                f"{request.idempotency_key}"
            )
        message_ids.append(str(receipt["messageId"]))

    first = schedule[0]
    replay = api.submit(first.bot_id, first.idempotency_key, first.period)
    replayed_message_id = str(replay["messageId"])
    if replayed_message_id != message_ids[0] or replay.get("created") is not False:
        raise AssertionError(
            "same-key replay did not return the durable original receipt"
        )
    try:
        api.submit(first.bot_id, first.idempotency_key, _CONFLICT_PERIOD)
    except BacktestConflict:
        conflict_rejected = True
    else:
        raise AssertionError("same-key conflicting payload was accepted")
    return SubmissionProof(tuple(message_ids), replayed_message_id, conflict_rejected)
