"""Create editable, trade-producing Basic strategy samples for the local test account."""

from __future__ import annotations

import json
import os
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from typing import Any, Protocol
from urllib.error import HTTPError
from urllib.parse import quote
from urllib.request import Request, urlopen

SAMPLE_REVISION = 4


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
    "가격 비교",
    "condition",
    ">",
    "전일 종가",
)
_PRICE_DOWN = _Condition(
    "BASIC_PRICE_COMPARE",
    {"resolution": "30m", "operator": "LT", "reference": "PREVIOUS_CLOSE"},
    "가격 비교",
    "condition",
    "<",
    "전일 종가",
)
_VOLUME_CONFIRM = _Condition(
    "BASIC_VOLUME_COMPARE",
    {
        "resolution": "30m",
        "operator": "GTE",
        "reference": "AVERAGE_VOLUME",
        "period": "20",
        "multiplier": "1",
    },
    "거래량",
    "data",
    "≥",
    "20봉 평균 거래량의 1배",
)


def _streak(direction: str, bars: int) -> _Condition:
    return _Condition(
        "BASIC_STREAK",
        {"resolution": "30m", "direction": direction, "bars": str(bars)},
        "연속 상승·하락",
        "condition",
        "상승" if direction == "UP" else "하락",
        f"{bars}봉",
    )


def _holding(bars: int) -> _Condition:
    return _Condition(
        "BASIC_HOLDING_PERIOD",
        {"unit": "BAR", "amount": str(bars), "resolution": "30m"},
        "보유 기간",
        "time",
        "이상",
        f"{bars}봉",
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
    scheduled = any(condition.element_code == "BASIC_SCHEDULE" for condition in conditions)
    blocks = [
        {
            "id": f"{card_id}-condition-{index}",
            "elementCode": condition.element_code,
            "parameters": dict(condition.parameters),
        }
        for index, condition in enumerate(conditions, start=1)
    ]
    blocks.append(
        {
            "id": f"{card_id}-order",
            "elementCode": "BASIC_EQUAL_ALLOCATION_ORDER",
            "parameters": {
                "orderPercent": "10" if container == "BUY" else "100",
                "maxPositionPercent": "25",
                "executionMode": (
                    "주기마다"
                    if container == "BUY" and scheduled
                    else "대기 후 재진입"
                    if container == "BUY"
                    else "대기 후 재실행"
                ),
                "waitMode": "조건 재충족",
                "waitInterval": "1",
                "maxExecutions": "1000",
            },
        }
    )
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
                "fromBlockId": block["id"],
                "outputPort": "passed",
                "toBlockId": blocks[index + 1]["id"],
                "inputPort": "passed",
            }
            for index, block in enumerate(blocks[:-1])
        ],
    }


def _sample(
    definition: _Definition, catalog_id: str, instruments: Mapping[str, str]
) -> SampleStrategy:
    for symbol in definition.symbols:
        if symbol not in instruments:
            raise ValueError(
                f"Basic catalog is missing required sample instrument: {symbol}"
            )

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
        "sections": [
            {
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
                "cardPositions": {
                    buy_id: {"x": 24, "y": 96},
                    sell_id: {"x": 396, "y": 96},
                },
            }
        ],
        "cardBlocks": {
            buy_id: [
                _condition_block(buy_id, i, item)
                for i, item in enumerate(definition.buy, start=1)
            ],
            sell_id: [
                _condition_block(sell_id, i, item)
                for i, item in enumerate(definition.sell, start=1)
            ],
        },
        "cardMeta": {
            buy_id: {
                "title": "복합 매수",
                "detail": definition.description,
                "explanation": definition.description,
            },
            sell_id: {
                "title": "복합 매도",
                "detail": definition.description,
                "explanation": definition.description,
            },
        },
        "buySettings": {
            buy_id: {
                "maxOrderPercent": 10,
                "entryMode": "대기 후 재진입",
                "cycle": "매 거래일",
                "cycleInterval": 1,
                "reentryWait": "조건 재충족",
                "reentryInterval": 1,
                "maxEntries": 1000,
            }
        },
        "sellSettings": {
            sell_id: {
                "sellPercent": 100,
                "executeMode": "대기 후 재실행",
                "reexecWait": "조건 재충족",
                "reexecInterval": 1,
                "maxExecutions": 1000,
            }
        },
        "symbolLimits": {section_id: {symbol: 25 for symbol in definition.symbols}},
    }
    return SampleStrategy(
        key=definition.key,
        name=definition.name,
        description=definition.description,
        semantic_document={"mode": "BASIC", "catalogId": catalog_id, "groups": groups},
        presentation_document={
            "basicEditor": {
                "version": 1,
                "snapshot": snapshot,
                "viewport": {"pan": {"x": 0, "y": 0}, "zoom": 1},
            },
            "localSampleKey": definition.key,
            "localSampleRevision": SAMPLE_REVISION,
        },
    )


def _condition(
    element_code: str,
    resolution: str,
    parameters: Mapping[str, str],
    label: str,
    op: str,
    value: str,
    *,
    tone: str = "condition",
    base: str | None = None,
) -> _Condition:
    return _Condition(
        element_code,
        {"resolution": resolution, **parameters} if resolution else dict(parameters),
        label,
        tone,
        op,
        value,
        base,
    )


def _price_guard(resolution: str) -> _Condition:
    return _condition(
        "BASIC_PRICE_COMPARE",
        resolution,
        {"operator": "NEQ", "reference": "PREVIOUS_CLOSE"},
        "가격 비교",
        "≠",
        "전일 종가",
        tone="data",
    )


def _full_catalog_sample(
    catalog_id: str, instruments: Mapping[str, str]
) -> SampleStrategy:
    required = ("AAPL", "MSFT", "META", "NVDA")
    for symbol in required:
        if symbol not in instruments:
            raise ValueError(
                f"Basic catalog is missing required sample instrument: {symbol}"
            )

    schedule = _condition(
        "BASIC_SCHEDULE",
        "30m",
        {"cycle": "EVERY_TRADING_DAY", "interval": "1"},
        "실행 주기",
        "매 거래일",
        "1",
        tone="time",
    )
    targets: dict[str, tuple[str, tuple[_Condition, ...], tuple[_Condition, ...]]] = {
        "AAPL": (
            "30m",
            (
                schedule,
                _condition(
                    "BASIC_PRICE_COMPARE",
                    "30m",
                    {"operator": "GT", "reference": "PREVIOUS_CLOSE"},
                    "가격 비교",
                    ">",
                    "전일 종가",
                    tone="data",
                ),
                _condition(
                    "BASIC_PRICE_CHANGE_PERCENT",
                    "30m",
                    {
                        "base": "PREVIOUS_CLOSE",
                        "direction": "UP",
                        "thresholdPercent": "1",
                    },
                    "가격 변화율",
                    "상승",
                    "1%",
                    tone="data",
                    base="전일 종가",
                ),
            ),
            (
                _condition(
                    "BASIC_POSITION_RETURN",
                    "",
                    {"direction": "LOSS", "thresholdPercent": "5"},
                    "현재 수익률",
                    "손실",
                    "5%",
                    tone="risk",
                ),
                _condition(
                    "BASIC_HOLDING_PERIOD",
                    "30m",
                    {"unit": "BAR", "amount": "1"},
                    "보유 기간",
                    "≥",
                    "1봉",
                    tone="risk",
                ),
            ),
        ),
        "MSFT": (
            "1h",
            (
                _condition(
                    "BASIC_VOLUME_COMPARE",
                    "1h",
                    {
                        "operator": "GTE",
                        "reference": "AVERAGE_VOLUME",
                        "period": "20",
                        "multiplier": "1",
                    },
                    "거래량",
                    "≥",
                    "최근 20봉 평균 거래량 1배",
                    tone="data",
                ),
                _condition(
                    "BASIC_STREAK",
                    "1h",
                    {"direction": "UP", "bars": "2"},
                    "연속 상승·하락",
                    "↑",
                    "2봉",
                ),
            ),
            (
                _condition(
                    "BASIC_PEAK_RETURN",
                    "",
                    {"operator": "GTE", "thresholdPercent": "8"},
                    "최고 수익률",
                    "≥",
                    "8%",
                    tone="risk",
                ),
            ),
        ),
        "META": (
            "4h",
            (
                _condition(
                    "BASIC_SMA_CROSS",
                    "4h",
                    {"direction": "UP", "shortPeriod": "5", "longPeriod": "20"},
                    "평균선 교차",
                    "↑",
                    "5봉 · 20봉",
                    tone="indicator",
                ),
                _condition(
                    "BASIC_RSI_CROSS",
                    "4h",
                    {"direction": "UP", "period": "14", "threshold": "30"},
                    "RSI 반등",
                    "↑",
                    "30",
                ),
            ),
            (
                _condition(
                    "BASIC_DRAWDOWN_FROM_PEAK",
                    "",
                    {"operator": "GTE", "thresholdPercent": "7"},
                    "고점 대비 하락",
                    "≥",
                    "7%",
                    tone="risk",
                ),
            ),
        ),
        "NVDA": (
            "1d",
            (
                _condition(
                    "BASIC_MACD_CROSS",
                    "1d",
                    {
                        "direction": "UP",
                        "fastPeriod": "12",
                        "slowPeriod": "26",
                        "signalPeriod": "9",
                    },
                    "MACD 전환",
                    "↑",
                    "12 · 26 · 9",
                ),
                _condition(
                    "BASIC_BOLLINGER_REVERSAL",
                    "1d",
                    {"direction": "UP", "period": "20", "deviations": "2"},
                    "가격 띠 반전",
                    "↑",
                    "20봉 · 2σ",
                ),
            ),
            (
                _condition(
                    "BASIC_HOLDING_PERIOD",
                    "1d",
                    {"unit": "TRADING_DAY", "amount": "1"},
                    "보유 기간",
                    "≥",
                    "1거래일",
                    tone="risk",
                ),
            ),
        ),
    }
    groups: list[dict[str, Any]] = []
    sections: list[dict[str, Any]] = []
    card_blocks: dict[str, list[dict[str, Any]]] = {}
    card_meta: dict[str, dict[str, str]] = {}
    buy_settings: dict[str, dict[str, Any]] = {}
    sell_settings: dict[str, dict[str, Any]] = {}
    symbol_limits: dict[str, dict[str, int]] = {}

    for section_index, (symbol, (resolution, buy_targets, sell_targets)) in enumerate(
        targets.items(), start=1
    ):
        section_id = f"full-catalog-{symbol.lower()}"
        instrument_id = instruments[symbol]
        buy_cards: list[str] = []
        sell_cards: list[str] = []
        card_positions: dict[str, dict[str, int]] = {}
        for container, conditions in (("BUY", buy_targets), ("SELL", sell_targets)):
            for card_index, target in enumerate(conditions, start=1):
                card_id = f"{section_id}-{container.lower()}-{card_index}"
                guard = (
                    _condition(
                        "BASIC_VOLUME_COMPARE",
                        resolution,
                        {
                            "operator": "GTE",
                            "reference": "PREVIOUS_VOLUME",
                            "period": "1",
                            "multiplier": "1",
                        },
                        "거래량",
                        "≥",
                        "이전 봉 거래량 1배",
                        tone="data",
                    )
                    if target.element_code == "BASIC_PRICE_COMPARE"
                    else _price_guard(resolution)
                )
                flow_conditions = (target, guard)
                groups.append(
                    _semantic_group(card_id, container, instrument_id, flow_conditions)
                )
                visible_conditions = tuple(
                    item
                    for item in flow_conditions
                    if item.element_code != "BASIC_SCHEDULE"
                )
                card_blocks[card_id] = [
                    _condition_block(card_id, index, item)
                    for index, item in enumerate(visible_conditions, start=1)
                ]
                card_meta[card_id] = {
                    "title": f"{target.label} 검증",
                    "detail": f"{symbol} {resolution} · {target.label}",
                    "explanation": "전체 Basic 블록의 실제 데이터 실행 경로를 검증하는 로컬 샘플입니다.",
                }
                card_positions[card_id] = {
                    "x": 24 if container == "BUY" else 396,
                    "y": 96 + (card_index - 1) * 150,
                }
                if container == "BUY":
                    buy_cards.append(card_id)
                    periodic = target.element_code == "BASIC_SCHEDULE"
                    buy_settings[card_id] = {
                        "maxOrderPercent": 10,
                        "entryMode": "주기마다" if periodic else "대기 후 재진입",
                        "cycle": "매 거래일",
                        "cycleInterval": 1,
                        "reentryWait": "조건 재충족",
                        "reentryInterval": 1,
                        "maxEntries": 1000,
                    }
                else:
                    sell_cards.append(card_id)
                    sell_settings[card_id] = {
                        "sellPercent": 100,
                        "executeMode": "대기 후 재실행",
                        "reexecWait": "조건 재충족",
                        "reexecInterval": 1,
                        "maxExecutions": 1000,
                    }
        sections.append(
            {
                "id": section_id,
                "symbol": symbol,
                "instrumentIds": [instrument_id],
                "allocation": 25,
                "timeframe": {
                    "30m": "30분봉",
                    "1h": "1시간봉",
                    "4h": "4시간봉",
                    "1d": "일봉",
                }[resolution],
                "x": 80 + (section_index - 1) * 40,
                "y": 80 + (section_index - 1) * 40,
                "width": 760,
                "height": 720,
                "cards": {"buy": buy_cards, "sell": sell_cards, "risk": []},
                "cardOrder": [*buy_cards, *sell_cards],
                "cardPositions": card_positions,
            }
        )
        symbol_limits[section_id] = {symbol: 25}

    return SampleStrategy(
        key="FULL_CATALOG_MIXED_RESOLUTION",
        name="검증 · 전체 14블록 · 30분·1시간·4시간·일봉",
        description="모든 Basic 블록을 네 가지 봉 주기와 매수·매도 흐름에서 실제 데이터로 실행하는 검증 전략입니다.",
        semantic_document={"mode": "BASIC", "catalogId": catalog_id, "groups": groups},
        presentation_document={
            "basicEditor": {
                "version": 1,
                "snapshot": {
                    "sections": sections,
                    "cardBlocks": card_blocks,
                    "cardMeta": card_meta,
                    "buySettings": buy_settings,
                    "sellSettings": sell_settings,
                    "symbolLimits": symbol_limits,
                },
                "viewport": {"pan": {"x": 0, "y": 0}, "zoom": 0.8},
            },
            "localSampleKey": "FULL_CATALOG_MIXED_RESOLUTION",
            "localSampleRevision": SAMPLE_REVISION,
        },
    )


def build_long_horizon_growth_strategy(
    catalog_id: str, instruments: Mapping[str, str]
) -> SampleStrategy:
    """Build the user-facing low-turnover growth portfolio proven on local history."""
    required = ("NVDA", "MSFT", "AAPL", "META", "AMZN")
    for symbol in required:
        if symbol not in instruments:
            raise ValueError(
                f"Basic catalog is missing required sample instrument: {symbol}"
            )

    price_up = lambda resolution: _condition(
        "BASIC_PRICE_COMPARE",
        resolution,
        {"operator": "GT", "reference": "PREVIOUS_CLOSE"},
        "가격 비교",
        ">",
        "전일 종가",
        tone="data",
    )
    drawdown = lambda percent: _condition(
        "BASIC_DRAWDOWN_FROM_PEAK",
        "",
        {"operator": "GTE", "thresholdPercent": str(percent)},
        "고점 대비 하락",
        "≥",
        f"{percent}%",
        tone="risk",
    )

    peak_return = _condition(
        "BASIC_PEAK_RETURN",
        "",
        {"operator": "GTE", "thresholdPercent": "20"},
        "최고 수익률",
        "≥",
        "20%",
        tone="risk",
    )
    weights = (("NVDA", 30), ("MSFT", 25), ("AAPL", 20), ("META-AMZN", 25))
    partitions = tuple(
        {
            "id": f"long-horizon-{symbol.lower()}",
            "symbols": tuple(symbol.split("-")),
            "resolution": "1d",
            "allocation": allocation,
            "buy": (("상승 확인 후 최초 진입", (price_up("1d"),)),),
            "sell": (("대형 낙폭 방어", (peak_return, drawdown(40))),),
        }
        for symbol, allocation in weights
    )

    groups: list[dict[str, Any]] = []
    sections: list[dict[str, Any]] = []
    card_blocks: dict[str, list[dict[str, Any]]] = {}
    card_meta: dict[str, dict[str, str]] = {}
    buy_settings: dict[str, dict[str, Any]] = {}
    sell_settings: dict[str, dict[str, Any]] = {}
    symbol_limits: dict[str, dict[str, float | int]] = {}
    timeframe_labels = {"30m": "30분봉", "4h": "4시간봉", "1d": "일봉"}

    for section_index, partition in enumerate(partitions):
        section_id = str(partition["id"])
        symbols = tuple(partition["symbols"])
        resolution = str(partition["resolution"])
        raw_per_symbol_limit = partition["allocation"] / len(symbols)
        per_symbol_limit = (
            int(raw_per_symbol_limit)
            if raw_per_symbol_limit.is_integer()
            else raw_per_symbol_limit
        )
        buy_cards: list[str] = []
        sell_cards: list[str] = []
        card_positions: dict[str, dict[str, int]] = {}
        for container in ("BUY", "SELL"):
            flows = partition[container.lower()]
            for card_index, (title, conditions) in enumerate(flows, start=1):
                card_id = f"{section_id}-{container.lower()}-{card_index}"
                for symbol in symbols:
                    group = _semantic_group(
                        card_id, container, instruments[symbol], conditions
                    )
                    terminal = group["blocks"][-1]["parameters"]
                    terminal["maxPositionPercent"] = str(per_symbol_limit)
                    terminal["orderPercent"] = str(
                        per_symbol_limit if container == "BUY" else 100
                    )
                    terminal["executionMode"] = "1회만"
                    terminal["maxExecutions"] = "1"
                    groups.append(group)
                visible = tuple(
                    condition
                    for condition in conditions
                    if condition.element_code != "BASIC_SCHEDULE"
                )
                card_blocks[card_id] = [
                    _condition_block(card_id, index, condition)
                    for index, condition in enumerate(visible, start=1)
                ]
                card_meta[card_id] = {
                    "title": str(title),
                    "detail": f"{' · '.join(symbols)} {timeframe_labels[resolution]}",
                    "explanation": "서로 다른 확인 조건이 모두 충족될 때만 실행합니다.",
                }
                card_positions[card_id] = {
                    "x": 24 if container == "BUY" else 396,
                    "y": 96 + (card_index - 1) * 190,
                }
                if container == "BUY":
                    buy_cards.append(card_id)
                    buy_settings[card_id] = {
                        "maxOrderPercent": per_symbol_limit,
                        "entryMode": "1회만",
                        "cycle": "매 거래일",
                        "cycleInterval": 1,
                        "reentryWait": "조건 재충족",
                        "reentryInterval": 1,
                        "maxEntries": 1,
                    }
                else:
                    sell_cards.append(card_id)
                    sell_settings[card_id] = {
                        "sellPercent": 100,
                        "executeMode": "1회만",
                        "reexecWait": "조건 재충족",
                        "reexecInterval": 1,
                        "maxExecutions": 1,
                    }
        sections.append(
            {
                "id": section_id,
                "symbol": " · ".join(symbols),
                "instrumentIds": [instruments[symbol] for symbol in symbols],
                "allocation": partition["allocation"],
                "timeframe": timeframe_labels[resolution],
                "x": 80 + section_index * 820,
                "y": 80,
                "width": 760,
                "height": 620,
                "cards": {"buy": buy_cards, "sell": sell_cards, "risk": []},
                "cardOrder": [*buy_cards, *sell_cards],
                "cardPositions": card_positions,
            }
        )
        symbol_limits[section_id] = {
            symbol: per_symbol_limit for symbol in symbols
        }

    return SampleStrategy(
        key="LONG_HORIZON_DRAWDOWN_DEFENSE",
        name="장기 성장 · 대형 낙폭 방어",
        description="다섯 성장주를 일봉에서 목표 비중으로 한 번 진입하고, 수익 달성 뒤 40% 대형 낙폭에서만 방어합니다.",
        semantic_document={"mode": "BASIC", "catalogId": catalog_id, "groups": groups},
        presentation_document={
            "basicEditor": {
                "version": 1,
                "snapshot": {
                    "sections": sections,
                    "cardBlocks": card_blocks,
                    "cardMeta": card_meta,
                    "buySettings": buy_settings,
                    "sellSettings": sell_settings,
                    "symbolLimits": symbol_limits,
                },
                "viewport": {"pan": {"x": 0, "y": 0}, "zoom": 0.7},
            },
            "localSampleKey": "LONG_HORIZON_DRAWDOWN_DEFENSE",
            "localSampleRevision": SAMPLE_REVISION,
        },
    )


def build_samples(
    catalog_id: str, instruments: Mapping[str, str]
) -> tuple[SampleStrategy, ...]:
    """Build stable API and UI documents from the published catalog identities."""
    return (
        *(_sample(definition, catalog_id, instruments) for definition in _DEFINITIONS),
        _full_catalog_sample(catalog_id, instruments),
    )


class SampleSeederApi(Protocol):
    def get_catalog(self) -> Mapping[str, Any]: ...
    def list_strategies(self) -> Sequence[Mapping[str, Any]]: ...
    def get_document(self, strategy_id: str) -> Mapping[str, Any]: ...
    def create_strategy(self, sample: SampleStrategy) -> str: ...
    def save_document(
        self, strategy_id: str, sample: SampleStrategy
    ) -> Mapping[str, Any]: ...
    def validate_strategy(
        self, strategy_id: str, catalog_id: str
    ) -> Mapping[str, Any]: ...
    def release_strategy(
        self, strategy_id: str, validation_id: str
    ) -> Mapping[str, Any]: ...


def seed_samples(api: SampleSeederApi) -> list[dict[str, str]]:
    """Idempotently create and release the stable samples through the public API."""
    catalog = api.get_catalog()
    version = catalog.get("version")
    if not isinstance(version, Mapping) or not isinstance(version.get("id"), str):
        raise TypeError("Basic catalog version id is unavailable")
    catalog_id = version["id"]
    catalog_instruments = catalog.get("instruments")
    if not isinstance(catalog_instruments, Sequence):
        raise TypeError("Basic catalog instruments are unavailable")
    instruments = {
        row["symbol"]: row["id"]
        for row in catalog_instruments
        if isinstance(row, Mapping)
        and isinstance(row.get("symbol"), str)
        and isinstance(row.get("id"), str)
    }
    samples = build_samples(catalog_id, instruments)
    library = [
        row
        for row in api.list_strategies()
        if isinstance(row.get("name"), str) and isinstance(row.get("id"), str)
    ]
    receipts: list[dict[str, str]] = []

    def configure(strategy_id: str, sample: SampleStrategy) -> Mapping[str, Any]:
        api.save_document(strategy_id, sample)
        validation = api.validate_strategy(strategy_id, catalog_id)
        if validation.get("status") != "VALID" or not isinstance(
            validation.get("validationRunId"), str
        ):
            raise ValueError(f"Sample strategy did not validate: {sample.key}")
        return validation

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
            if (
                isinstance(presentation, Mapping)
                and presentation.get("localSampleKey") == sample.key
            ):
                configured = candidate
                configured_is_current = (
                    presentation.get("localSampleRevision") == SAMPLE_REVISION
                )
                break
            semantic = document.get("semanticDocument")
            groups = semantic.get("groups") if isinstance(semantic, Mapping) else None
            if candidate.get("description") == sample.description and groups == []:
                resumable = candidate

        if configured and configured_is_current and released_exists:
            receipts.append(
                {"key": sample.key, "strategyId": configured["id"], "status": "reused"}
            )
            continue
        existing = configured or resumable
        if draft_candidates and existing is None:
            raise ValueError(
                f"Strategy name is already used by a non-sample document: {sample.name}"
            )

        strategy_id = existing["id"] if existing else api.create_strategy(sample)
        validation = configure(strategy_id, sample)
        if released_exists:
            receipts.append(
                {"key": sample.key, "strategyId": strategy_id, "status": "created"}
            )
            continue

        released = api.release_strategy(strategy_id, validation["validationRunId"])
        editable_strategy_id = api.create_strategy(sample)
        configure(editable_strategy_id, sample)
        receipts.append(
            {
                "key": sample.key,
                "strategyId": editable_strategy_id,
                "releaseId": str(released.get("releaseId", "")),
                "botId": str(released.get("botId", "")),
                "status": "created",
            }
        )
    return receipts


def _json_transport(
    method: str,
    url: str,
    body: Mapping[str, Any] | None,
    token: str | None,
) -> Mapping[str, Any]:
    encoded = (
        None
        if body is None
        else json.dumps(body, separators=(",", ":")).encode("utf-8")
    )
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
        raise RuntimeError(
            f"Local sample API request failed ({error.code} {method} {url}): {detail}"
        ) from error
    if not payload:
        return {}
    value = json.loads(payload)
    if not isinstance(value, Mapping):
        raise TypeError(
            f"Local sample API returned a non-object response: {method} {url}"
        )
    return value


class LocalSampleApi:
    def __init__(self, base_url: str, token: str, transport=_json_transport) -> None:
        self._base_url = base_url.rstrip("/")
        self._token = token
        self._transport = transport

    def _request(
        self, method: str, path: str, body: Mapping[str, Any] | None = None
    ) -> Mapping[str, Any]:
        return self._transport(method, f"{self._base_url}{path}", body, self._token)

    def get_catalog(self) -> Mapping[str, Any]:
        return self._request("GET", "/api/v1/strategy-catalogs/basic")

    def list_strategies(self) -> Sequence[Mapping[str, Any]]:
        page = self._request("GET", "/api/v1/strategies?limit=100")
        items = page.get("items")
        if not isinstance(items, Sequence):
            raise TypeError("Strategy library response has no items")
        return [item for item in items if isinstance(item, Mapping)]

    def get_document(self, strategy_id: str) -> Mapping[str, Any]:
        return self._request("GET", f"/api/v1/strategies/{quote(strategy_id)}/document")

    def create_strategy(self, sample: SampleStrategy) -> str:
        result = self._request(
            "POST",
            "/api/v1/strategies",
            {
                "name": sample.name,
                "description": sample.description,
                "mode": "BASIC",
            },
        )
        strategy_id = result.get("id")
        if not isinstance(strategy_id, str):
            raise TypeError("Strategy creation response has no id")
        return strategy_id

    def acquire_lease(self, strategy_id: str) -> Mapping[str, Any]:
        return self._request(
            "POST", f"/api/v1/strategies/{quote(strategy_id)}/edit-lease"
        )

    def save_document(
        self, strategy_id: str, sample: SampleStrategy
    ) -> Mapping[str, Any]:
        current = self.get_document(strategy_id)
        edit_sequence = current.get("editSequence")
        if not isinstance(edit_sequence, int):
            raise TypeError("Strategy document response has no edit sequence")
        return self._request(
            "PUT",
            f"/api/v1/strategies/{quote(strategy_id)}/document",
            {
                "expectedEditSequence": edit_sequence,
                "semanticDocument": sample.semantic_document,
                "presentationDocument": sample.presentation_document,
            },
        )

    def release_lease(self, strategy_id: str, lease_token: str) -> None:
        self._request(
            "DELETE",
            f"/api/v1/strategies/{quote(strategy_id)}/edit-lease",
            {"leaseToken": lease_token},
        )

    def validate_strategy(self, strategy_id: str, catalog_id: str) -> Mapping[str, Any]:
        return self._request(
            "POST",
            f"/api/v1/strategies/{quote(strategy_id)}/validations",
            {"catalogId": catalog_id},
        )

    def release_strategy(
        self, strategy_id: str, validation_id: str
    ) -> Mapping[str, Any]:
        return self._request(
            "POST",
            f"/api/v1/strategies/{quote(strategy_id)}/releases",
            {
                "validationRunId": validation_id,
                "initialCashAmount": "100000.00000000",
                "budgetCapBps": 10000,
                "candidateConflictPolicy": {"policy": "FIRST_WINS"},
            },
        )


def _login(base_url: str, email: str, password: str) -> str:
    response = _json_transport(
        "POST",
        f"{base_url.rstrip('/')}/api/v1/auth/login",
        {
            "email": email,
            "password": password,
        },
        None,
    )
    token = response.get("accessToken")
    if not isinstance(token, str):
        raise TypeError("Local login response has no access token")
    return token


def main() -> None:
    base_url = os.environ.get("LOCAL_SAMPLE_BASE_URL", "http://localhost:15173")
    email = os.environ["LOCAL_SAMPLE_EMAIL"]
    password = os.environ["LOCAL_SAMPLE_PASSWORD"]
    receipts = seed_samples(LocalSampleApi(base_url, _login(base_url, email, password)))
    print(
        json.dumps(
            {"status": "prepared", "samples": receipts},
            ensure_ascii=False,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
