"""Create editable, trade-producing Basic strategy samples for the local test account."""

from __future__ import annotations

import json
import os
from dataclasses import dataclass
from typing import Any, Mapping, Protocol, Sequence
from urllib.error import HTTPError
from urllib.parse import quote
from urllib.request import Request, urlopen

SAMPLE_REVISION = 2


@dataclass(frozen=True)
class SampleStrategy:
    key: str
    name: str
    description: str
    semantic_document: dict[str, Any]
    presentation_document: dict[str, Any]
    minimum_fill_count: int = 2
    minimum_closing_trade_count: int = 1
    minimum_trade_month_count: int = 2


@dataclass(frozen=True)
class _Condition:
    element_code: str
    parameters: Mapping[str, str]
    label: str
    tone: str
    op: str
    value: str
    base: str | None = None


@dataclass(frozen=True)
class _Definition:
    key: str
    name: str
    description: str
    symbols: tuple[str, ...]
    buy: tuple[_Condition, ...]
    sell: tuple[_Condition, ...]


_PRICE_UP = _Condition(
    "BASIC_PRICE_COMPARE",
    {"resolution": "30m", "operator": "GT", "reference": "PREVIOUS_CLOSE"},
    "가격 비교", "condition", ">", "전일 종가",
)
_PRICE_DOWN = _Condition(
    "BASIC_PRICE_COMPARE",
    {"resolution": "30m", "operator": "LT", "reference": "PREVIOUS_CLOSE"},
    "가격 비교", "condition", "<", "전일 종가",
)
_VOLUME_CONFIRM = _Condition(
    "BASIC_VOLUME_COMPARE",
    {
        "resolution": "30m", "operator": "GTE", "reference": "AVERAGE_VOLUME",
        "period": "20", "multiplier": "1",
    },
    "거래량", "data", "≥", "20봉 평균 거래량의 1배",
)


def _streak(direction: str, bars: int) -> _Condition:
    return _Condition(
        "BASIC_STREAK",
        {"resolution": "30m", "direction": direction, "bars": str(bars)},
        "연속 상승·하락", "condition", "상승" if direction == "UP" else "하락",
        f"{bars}봉",
    )


def _holding(bars: int) -> _Condition:
    return _Condition(
        "BASIC_HOLDING_PERIOD",
        {"unit": "BAR", "amount": str(bars), "resolution": "30m"},
        "보유 기간", "time", "이상", f"{bars}봉",
    )


_DEFINITIONS = (
    _Definition(
        "AAPL_MOMENTUM_REVERSAL",
        "샘플 · AAPL 거래량 확인 모멘텀",
        "전일 종가 상승과 평균 거래량을 함께 확인해 진입하고, 보유 기간과 가격 반전을 함께 확인해 청산합니다.",
        ("AAPL",),
        (_PRICE_UP, _VOLUME_CONFIRM),
        (_holding(65), _PRICE_DOWN),
    ),
    _Definition(
        "MSFT_STREAK_REVERSAL",
        "샘플 · MSFT 연속 상승 후 반전",
        "연속 상승과 거래량을 확인해 진입하고, 최소 보유 기간 이후 하락 반전에서 청산합니다.",
        ("MSFT",),
        (_streak("UP", 2), _VOLUME_CONFIRM),
        (_holding(65), _PRICE_DOWN),
    ),
    _Definition(
        "LIQUID_MULTI_ASSET_CYCLE",
        "샘플 · SPY·QQQ 복합 순환",
        "두 유동성 ETF를 같은 복합 규칙으로 독립 평가해 반복 진입과 청산을 확인합니다.",
        ("SPY", "QQQ"),
        (_PRICE_UP, _streak("UP", 2)),
        (_holding(65), _streak("DOWN", 2)),
    ),
)


def _condition_block(card_id: str, index: int, condition: _Condition) -> dict[str, Any]:
    block = {
        "id": f"{card_id}-condition-{index}",
        "label": condition.label,
        "tone": condition.tone,
        "op": condition.op,
        "value": condition.value,
    }
    if condition.base is not None:
        block["base"] = condition.base
    return block


def _semantic_group(
    card_id: str,
    container: str,
    instrument_id: str,
    conditions: Sequence[_Condition],
) -> dict[str, Any]:
    blocks = [
        {
            "id": f"{card_id}-condition-{index}",
            "elementCode": condition.element_code,
            "parameters": dict(condition.parameters),
        }
        for index, condition in enumerate(conditions, start=1)
    ]
    blocks.append({
        "id": f"{card_id}-order",
        "elementCode": "BASIC_EQUAL_ALLOCATION_ORDER",
        "parameters": {
            "orderPercent": "10" if container == "BUY" else "100",
            "maxPositionPercent": "25",
            "executionMode": "대기 후 재진입" if container == "BUY" else "대기 후 재실행",
            "waitMode": "조건 재충족",
            "waitInterval": "1",
            "maxExecutions": "1000",
        },
    })
    return {
        "id": f"{card_id}:{instrument_id}",
        "allocationGroupId": card_id,
        "container": container,
        "evaluationMode": "INDEPENDENT",
        "allocationMode": "EQUAL",
        "instrumentIds": [instrument_id],
        "blocks": blocks,
        "connections": [
            {
                "fromBlockId": block["id"], "outputPort": "passed",
                "toBlockId": blocks[index + 1]["id"], "inputPort": "passed",
            }
            for index, block in enumerate(blocks[:-1])
        ],
    }


def _sample(definition: _Definition, catalog_id: str, instruments: Mapping[str, str]) -> SampleStrategy:
    for symbol in definition.symbols:
        if symbol not in instruments:
            raise ValueError(f"Basic catalog is missing required sample instrument: {symbol}")

    section_id = f"sample-{definition.key.lower()}"
    buy_id = f"{section_id}-buy"
    sell_id = f"{section_id}-sell"
    instrument_ids = [instruments[symbol] for symbol in definition.symbols]
    groups = [
        _semantic_group(card_id, container, instrument_id, conditions)
        for card_id, container, conditions in (
            (buy_id, "BUY", definition.buy),
            (sell_id, "SELL", definition.sell),
        )
        for instrument_id in instrument_ids
    ]
    snapshot = {
        "sections": [{
            "id": section_id,
            "symbol": " · ".join(definition.symbols),
            "instrumentIds": instrument_ids,
            "allocation": 100,
            "timeframe": "30분봉",
            "x": 80,
            "y": 80,
            "width": 760,
            "height": 520,
            "cards": {"buy": [buy_id], "sell": [sell_id], "risk": []},
            "cardOrder": [buy_id, sell_id],
            "cardPositions": {buy_id: {"x": 24, "y": 96}, sell_id: {"x": 396, "y": 96}},
        }],
        "cardBlocks": {
            buy_id: [_condition_block(buy_id, i, item) for i, item in enumerate(definition.buy, start=1)],
            sell_id: [_condition_block(sell_id, i, item) for i, item in enumerate(definition.sell, start=1)],
        },
        "cardMeta": {
            buy_id: {"title": "복합 매수", "detail": definition.description, "explanation": definition.description},
            sell_id: {"title": "복합 매도", "detail": definition.description, "explanation": definition.description},
        },
        "buySettings": {buy_id: {
            "maxOrderPercent": 10,
            "entryMode": "대기 후 재진입",
            "cycle": "매 거래일",
            "cycleInterval": 1,
            "reentryWait": "조건 재충족",
            "reentryInterval": 1,
            "maxEntries": 1000,
        }},
        "sellSettings": {sell_id: {
            "sellPercent": 100,
            "executeMode": "대기 후 재실행",
            "reexecWait": "조건 재충족",
            "reexecInterval": 1,
            "maxExecutions": 1000,
        }},
        "symbolLimits": {section_id: {symbol: 25 for symbol in definition.symbols}},
    }
    return SampleStrategy(
        key=definition.key,
        name=definition.name,
        description=definition.description,
        semantic_document={"mode": "BASIC", "catalogId": catalog_id, "groups": groups},
        presentation_document={
            "basicEditor": {"version": 1, "snapshot": snapshot, "viewport": {"pan": {"x": 0, "y": 0}, "zoom": 1}},
            "localSampleKey": definition.key,
            "localSampleRevision": SAMPLE_REVISION,
        },
    )


def build_samples(catalog_id: str, instruments: Mapping[str, str]) -> tuple[SampleStrategy, ...]:
    """Build stable API and UI documents from the published catalog identities."""
    return tuple(_sample(definition, catalog_id, instruments) for definition in _DEFINITIONS)


class SampleSeederApi(Protocol):
    def get_catalog(self) -> Mapping[str, Any]: ...
    def list_strategies(self) -> Sequence[Mapping[str, Any]]: ...
    def get_document(self, strategy_id: str) -> Mapping[str, Any]: ...
    def create_strategy(self, sample: SampleStrategy) -> str: ...
    def acquire_lease(self, strategy_id: str) -> Mapping[str, Any]: ...
    def save_document(self, strategy_id: str, lease_token: str, sample: SampleStrategy) -> Mapping[str, Any]: ...
    def release_lease(self, strategy_id: str, lease_token: str) -> None: ...
    def validate_strategy(self, strategy_id: str, catalog_id: str) -> Mapping[str, Any]: ...
    def release_strategy(self, strategy_id: str, validation_id: str) -> Mapping[str, Any]: ...


def seed_samples(api: SampleSeederApi) -> list[dict[str, str]]:
    """Idempotently create and release the stable samples through the public API."""
    catalog = api.get_catalog()
    version = catalog.get("version")
    if not isinstance(version, Mapping) or not isinstance(version.get("id"), str):
        raise ValueError("Basic catalog version id is unavailable")
    catalog_id = version["id"]
    catalog_instruments = catalog.get("instruments")
    if not isinstance(catalog_instruments, Sequence):
        raise ValueError("Basic catalog instruments are unavailable")
    instruments = {
        row["symbol"]: row["id"]
        for row in catalog_instruments
        if isinstance(row, Mapping) and isinstance(row.get("symbol"), str) and isinstance(row.get("id"), str)
    }
    samples = build_samples(catalog_id, instruments)
    library = [
        row for row in api.list_strategies()
        if isinstance(row.get("name"), str) and isinstance(row.get("id"), str)
    ]
    receipts: list[dict[str, str]] = []
    for sample in samples:
        same_name = [row for row in library if row["name"] == sample.name]
        released_exists = any(row.get("kind") == "released" for row in same_name)
        draft_candidates = [row for row in same_name if row.get("kind") != "released"]
        configured: Mapping[str, Any] | None = None
        configured_is_current = False
        resumable: Mapping[str, Any] | None = None
        for candidate in draft_candidates:
            document = api.get_document(candidate["id"])
            presentation = document.get("presentationDocument")
            if isinstance(presentation, Mapping) and presentation.get("localSampleKey") == sample.key:
                configured = candidate
                configured_is_current = presentation.get("localSampleRevision") == SAMPLE_REVISION
                break
            semantic = document.get("semanticDocument")
            groups = semantic.get("groups") if isinstance(semantic, Mapping) else None
            if candidate.get("description") == sample.description and groups == []:
                resumable = candidate

        if configured and configured_is_current and released_exists:
            receipts.append({"key": sample.key, "strategyId": configured["id"], "status": "reused"})
            continue
        existing = configured or resumable
        if draft_candidates and existing is None:
            raise ValueError(f"Strategy name is already used by a non-sample document: {sample.name}")
        strategy_id = existing["id"] if existing else api.create_strategy(sample)
        lease = api.acquire_lease(strategy_id)
        lease_token = lease.get("leaseToken")
        if not isinstance(lease_token, str):
            raise ValueError("Strategy edit lease token is unavailable")
        try:
            api.save_document(strategy_id, lease_token, sample)
        finally:
            api.release_lease(strategy_id, lease_token)
        validation = api.validate_strategy(strategy_id, catalog_id)
        if validation.get("status") != "VALID" or not isinstance(validation.get("validationRunId"), str):
            raise ValueError(f"Sample strategy did not validate: {sample.key}")
        released = api.release_strategy(strategy_id, validation["validationRunId"])
        receipts.append({
            "key": sample.key,
            "strategyId": strategy_id,
            "releaseId": str(released.get("releaseId", "")),
            "botId": str(released.get("botId", "")),
            "status": "created",
        })
    return receipts


def _json_transport(
    method: str,
    url: str,
    body: Mapping[str, Any] | None,
    token: str | None,
) -> Mapping[str, Any]:
    encoded = None if body is None else json.dumps(body, separators=(",", ":")).encode("utf-8")
    headers = {"Accept": "application/json"}
    if encoded is not None:
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = Request(url, data=encoded, headers=headers, method=method)
    try:
        with urlopen(request, timeout=30) as response:
            payload = response.read()
    except HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Local sample API request failed ({error.code} {method} {url}): {detail}") from error
    if not payload:
        return {}
    value = json.loads(payload)
    if not isinstance(value, Mapping):
        raise ValueError(f"Local sample API returned a non-object response: {method} {url}")
    return value


class LocalSampleApi:
    def __init__(self, base_url: str, token: str, transport=_json_transport) -> None:
        self._base_url = base_url.rstrip("/")
        self._token = token
        self._transport = transport

    def _request(self, method: str, path: str, body: Mapping[str, Any] | None = None) -> Mapping[str, Any]:
        return self._transport(method, f"{self._base_url}{path}", body, self._token)

    def get_catalog(self) -> Mapping[str, Any]:
        return self._request("GET", "/api/v1/strategy-catalogs/basic")

    def list_strategies(self) -> Sequence[Mapping[str, Any]]:
        page = self._request("GET", "/api/v1/strategies?limit=100")
        items = page.get("items")
        if not isinstance(items, Sequence):
            raise ValueError("Strategy library response has no items")
        return [item for item in items if isinstance(item, Mapping)]

    def get_document(self, strategy_id: str) -> Mapping[str, Any]:
        return self._request("GET", f"/api/v1/strategies/{quote(strategy_id)}/document")

    def create_strategy(self, sample: SampleStrategy) -> str:
        result = self._request("POST", "/api/v1/strategies", {
            "name": sample.name, "description": sample.description, "mode": "BASIC",
        })
        strategy_id = result.get("id")
        if not isinstance(strategy_id, str):
            raise ValueError("Strategy creation response has no id")
        return strategy_id

    def acquire_lease(self, strategy_id: str) -> Mapping[str, Any]:
        return self._request("POST", f"/api/v1/strategies/{quote(strategy_id)}/edit-lease")

    def save_document(self, strategy_id: str, lease_token: str, sample: SampleStrategy) -> Mapping[str, Any]:
        current = self.get_document(strategy_id)
        edit_sequence = current.get("editSequence")
        if not isinstance(edit_sequence, int):
            raise ValueError("Strategy document response has no edit sequence")
        return self._request("PUT", f"/api/v1/strategies/{quote(strategy_id)}/document", {
            "expectedEditSequence": edit_sequence,
            "leaseToken": lease_token,
            "semanticDocument": sample.semantic_document,
            "presentationDocument": sample.presentation_document,
        })

    def release_lease(self, strategy_id: str, lease_token: str) -> None:
        self._request("DELETE", f"/api/v1/strategies/{quote(strategy_id)}/edit-lease", {"leaseToken": lease_token})

    def validate_strategy(self, strategy_id: str, catalog_id: str) -> Mapping[str, Any]:
        return self._request("POST", f"/api/v1/strategies/{quote(strategy_id)}/validations", {"catalogId": catalog_id})

    def release_strategy(self, strategy_id: str, validation_id: str) -> Mapping[str, Any]:
        return self._request("POST", f"/api/v1/strategies/{quote(strategy_id)}/releases", {
            "validationRunId": validation_id,
            "initialCashAmount": "100000.00000000",
            "budgetCapBps": 10000,
            "candidateConflictPolicy": {"policy": "FIRST_WINS"},
        })


def _login(base_url: str, email: str, password: str) -> str:
    response = _json_transport("POST", f"{base_url.rstrip('/')}/api/v1/auth/login", {
        "email": email, "password": password,
    }, None)
    token = response.get("accessToken")
    if not isinstance(token, str):
        raise ValueError("Local login response has no access token")
    return token


def main() -> None:
    base_url = os.environ.get("LOCAL_SAMPLE_BASE_URL", "http://localhost:15173")
    email = os.environ["LOCAL_SAMPLE_EMAIL"]
    password = os.environ["LOCAL_SAMPLE_PASSWORD"]
    receipts = seed_samples(LocalSampleApi(base_url, _login(base_url, email, password)))
    print(json.dumps({"status": "prepared", "samples": receipts}, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__":
    main()
