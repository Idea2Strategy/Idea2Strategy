"""Generated complex-shape contract matrix complementing the three-lane runtime proof."""

from __future__ import annotations

import copy
import uuid
from collections import Counter
from collections.abc import Callable
from datetime import timedelta
from decimal import Decimal

import basic_strategy_cases as matrix
import pyarrow as pa
import pyarrow.compute as pc
import pyarrow.parquet as pq
import pytest
import stored_market_snapshot as stored_snapshot
from backtest_engine.attempt_coordinator import AttemptCoordinator
from backtest_engine.basic_runtime import (
    BasicDecisionStatus,
    BasicPlanReplay,
    BasicPlanRuntime,
    derive_data_requirements,
)
from backtest_engine.calendar import XNYS_CALENDAR
from backtest_engine.data_availability import (
    AvailabilityStatus,
)
from backtest_engine.elements import (
    ElementCompatibilityError,
    PlanStep,
    element_catalog,
)
from backtest_engine.execution_policy import D17_EXECUTION_POLICY_FIXTURE
from backtest_engine.orchestrator import BacktestJob, BacktestOrchestrator, ReplayStatus
from stored_market_snapshot import INSTRUMENT_ID, load_stored_market_snapshot
from test_orchestrator import (
    WALL_T0,
    FixedMonitor,
    RecordingEngine,
    RecordingPublisher,
    WallClock,
    _policy,
)

EXPECTED_CONDITION_CODES = frozenset(
    {
        "BASIC_PRICE_COMPARE",
        "BASIC_PRICE_CHANGE_PERCENT",
        "BASIC_VOLUME_COMPARE",
        "BASIC_STREAK",
        "BASIC_SMA_CROSS",
        "BASIC_RSI_CROSS",
        "BASIC_MACD_CROSS",
        "BASIC_BOLLINGER_REVERSAL",
        "BASIC_POSITION_RETURN",
        "BASIC_HOLDING_PERIOD",
        "BASIC_PEAK_RETURN",
        "BASIC_DRAWDOWN_FROM_PEAK",
    }
)
EXPECTED_ELEMENT_CODES = EXPECTED_CONDITION_CODES | {
    "BASIC_SCHEDULE",
    "BASIC_EQUAL_ALLOCATION_ORDER",
}
EXPECTED_NUMERIC_PARAMETERS = frozenset(
    {
        ("PRICE_CHANGE_PERCENT", "thresholdPercent"),
        ("RSI_CROSS", "threshold"),
        ("POSITION_RETURN", "thresholdPercent"),
        ("HOLDING_PERIOD", "amount"),
        ("PEAK_RETURN", "thresholdPercent"),
        ("DRAWDOWN_FROM_PEAK", "thresholdPercent"),
        ("SCHEDULE", "interval"),
        ("EMIT_ORDER_CANDIDATE", "orderPercent"),
        ("EMIT_ORDER_CANDIDATE", "maxPositionPercent"),
        ("EMIT_ORDER_CANDIDATE", "waitInterval"),
        ("EMIT_ORDER_CANDIDATE", "maxExecutions"),
    }
)
EXPECTED_ENUM_PARAMETERS = frozenset(
    {
        ("PRICE_COMPARE", "resolution"),
        ("PRICE_COMPARE", "operator"),
        ("PRICE_COMPARE", "reference"),
        ("PRICE_CHANGE_PERCENT", "resolution"),
        ("PRICE_CHANGE_PERCENT", "base"),
        ("PRICE_CHANGE_PERCENT", "direction"),
        ("VOLUME_COMPARE", "resolution"),
        ("VOLUME_COMPARE", "operator"),
        ("VOLUME_COMPARE", "reference"),
        ("VOLUME_COMPARE", "period"),
        ("VOLUME_COMPARE", "multiplier"),
        ("STREAK", "resolution"),
        ("STREAK", "direction"),
        ("STREAK", "bars"),
        ("SMA_CROSS", "resolution"),
        ("SMA_CROSS", "direction"),
        ("SMA_CROSS", "shortPeriod"),
        ("SMA_CROSS", "longPeriod"),
        ("RSI_CROSS", "resolution"),
        ("RSI_CROSS", "direction"),
        ("RSI_CROSS", "period"),
        ("MACD_CROSS", "resolution"),
        ("MACD_CROSS", "direction"),
        ("MACD_CROSS", "fastPeriod"),
        ("MACD_CROSS", "slowPeriod"),
        ("MACD_CROSS", "signalPeriod"),
        ("BOLLINGER_REVERSAL", "resolution"),
        ("BOLLINGER_REVERSAL", "direction"),
        ("BOLLINGER_REVERSAL", "period"),
        ("BOLLINGER_REVERSAL", "deviations"),
        ("POSITION_RETURN", "direction"),
        ("HOLDING_PERIOD", "unit"),
        ("HOLDING_PERIOD", "resolution"),
        ("PEAK_RETURN", "operator"),
        ("DRAWDOWN_FROM_PEAK", "operator"),
        ("SCHEDULE", "cycle"),
        ("SCHEDULE", "resolution"),
        ("EMIT_ORDER_CANDIDATE", "allocation"),
        ("EMIT_ORDER_CANDIDATE", "orderType"),
        ("EMIT_ORDER_CANDIDATE", "timeInForce"),
        ("EMIT_ORDER_CANDIDATE", "side"),
        ("EMIT_ORDER_CANDIDATE", "executionMode"),
        ("EMIT_ORDER_CANDIDATE", "waitMode"),
    }
)
EXPECTED_SEEDS = (17, 101, 313, 2027, 4099, 7919, 65537, 104729, 8675309, 20260831)
EXPECTED_LOADED_INSTRUMENT_IDS = {
    1: ("03e7e685-d6da-4f1f-9279-91477884aab9",),
    2: (
        "00000000-0000-4000-8000-000000000302",
        "03e7e685-d6da-4f1f-9279-91477884aab9",
    ),
    3: (
        "00000000-0000-4000-8000-000000000302",
        "00000000-0000-4000-8000-000000000303",
        "03e7e685-d6da-4f1f-9279-91477884aab9",
    ),
    4: (
        "00000000-0000-4000-8000-000000000302",
        "00000000-0000-4000-8000-000000000303",
        "00000000-0000-4000-8000-000000000304",
        "03e7e685-d6da-4f1f-9279-91477884aab9",
    ),
    5: (
        "00000000-0000-4000-8000-000000000302",
        "00000000-0000-4000-8000-000000000303",
        "00000000-0000-4000-8000-000000000304",
        "00000000-0000-4000-8000-000000000305",
        "03e7e685-d6da-4f1f-9279-91477884aab9",
    ),
}
EXPECTED_SHAPES = {
    "pairwise-basic_price_compare": ("30m", ("BUY",), 1, 1),
    "pairwise-basic_price_change_percent": ("30m", ("SELL",), 2, 2),
    "pairwise-basic_volume_compare": ("1h", ("BUY",), 3, 3),
    "pairwise-basic_streak": ("1h", ("SELL",), 4, 4),
    "pairwise-basic_sma_cross": ("4h", ("BUY",), 1, 5),
    "pairwise-basic_rsi_cross": ("4h", ("SELL",), 2, 1),
    "pairwise-basic_macd_cross": ("1d", ("BUY",), 3, 2),
    "pairwise-basic_bollinger_reversal": ("1d", ("SELL",), 4, 3),
    "pairwise-basic_position_return": ("30m", ("SELL",), 1, 4),
    "pairwise-basic_holding_period": ("1d", ("SELL",), 2, 5),
    "pairwise-basic_peak_return": ("4h", ("SELL",), 3, 1),
    "pairwise-basic_drawdown_from_peak": ("1d", ("SELL",), 4, 2),
    "pairwise-basic_schedule": ("1d", ("BUY",), 1, 3),
    "maximum-four-partition-five-instrument-two-side": ("30m", ("BUY", "SELL"), 4, 5),
    "contradictory-price-boundaries": ("30m", ("SELL",), 1, 1),
    "duplicate-price-condition": ("30m", ("BUY",), 1, 1),
    "no-signal": ("30m", ("BUY",), 1, 1),
    "missing-required-history": ("4h", ("BUY",), 1, 1),
    "simultaneous-buy-sell": ("30m", ("BUY", "SELL"), 1, 1),
}
EXPECTED_PARTITION_KEYS = {
    "pairwise-basic_price_compare": ("0e35f72c-edb0-5cd0-a09a-b9ea8ff88f42",),
    "pairwise-basic_price_change_percent": (
        "2f1355b5-80f6-5222-96fe-dabbb0b5d1ea",
        "ce6af436-f6e2-5087-91d7-35e6518172d9",
    ),
    "pairwise-basic_volume_compare": (
        "db03063a-ab4e-5a06-8373-dd20e95e99ce",
        "ae6d6ab6-27a6-506a-a62b-1b8f803f639a",
        "d91679c2-7be4-56e8-8363-a4b77fe8a7b8",
    ),
    "pairwise-basic_streak": (
        "31fe73be-5fac-5339-b034-1428fbdbde84",
        "2ffe7540-9ee8-5bcc-8ea7-d8be745da125",
        "0dcce8c1-01b7-501f-8f46-fa3b0a386b8d",
        "69d1fb30-e717-5bd9-9ea6-c0cc701bf6cf",
    ),
    "pairwise-basic_sma_cross": ("28b0f0f6-1075-534b-b20c-2680ff249a78",),
    "pairwise-basic_rsi_cross": (
        "981f817a-4408-56ef-99e2-bf9d98f6c789",
        "8084513a-3ec0-552d-98fa-642bb9e659b2",
    ),
    "pairwise-basic_macd_cross": (
        "1c780690-7b1e-5faa-8888-ce3334426fe7",
        "ec9132fb-14d4-5cae-ab17-0d878393cf6f",
        "a476d8a3-5e0e-56f7-ba57-1a8981dc60a0",
    ),
    "pairwise-basic_bollinger_reversal": (
        "bbacaa6d-320b-5d81-b38d-a4a36fb7f3b6",
        "1b9bde07-972f-5b60-93a6-3f7aa400c615",
        "b75125c7-d50c-5c3c-8a51-6a1cc8cfe976",
        "9216dc6b-9374-5fb9-987c-45568bb500d3",
    ),
    "pairwise-basic_position_return": ("fbe32cda-3b0e-5acf-af15-1d5e75c54bfb",),
    "pairwise-basic_holding_period": (
        "fdedda36-c3e0-5af4-98c2-d83b87b0305e",
        "7b1560a0-1b44-5520-8aa1-1bdef3961a41",
    ),
    "pairwise-basic_peak_return": (
        "cc4b907e-e321-567c-b3f6-45c911873f4b",
        "14446179-72f9-562c-baae-85ba0fde5fc1",
        "05dfa999-4c3b-5697-a15b-92119f2133ab",
    ),
    "pairwise-basic_drawdown_from_peak": (
        "b336eede-6154-519f-a2ad-2d59ee487b34",
        "3cbf34ef-3bac-5846-af0e-b7e46a9b11cf",
        "e5a694d8-f00d-5024-b828-9a3b65cb2b4b",
        "142cb410-d81e-578f-acaa-5a77fbe500e7",
    ),
    "pairwise-basic_schedule": ("826ebbda-e66b-581f-89b5-fd93ed9537ee",),
    "maximum-four-partition-five-instrument-two-side": (
        "246e43d7-6a03-5743-af19-ffe11c8d68ee",
        "7938b08a-3bd0-5baf-9f43-1a747a3908e4",
        "e05952c3-4156-588b-9c83-98242f1f308a",
        "8cc4dc09-ed4c-55b3-9ef2-b74abb9679cf",
    ),
    "contradictory-price-boundaries": ("6a54b391-a592-5269-a599-3d3ed7d4d7ab",),
    "duplicate-price-condition": ("c3068cc5-f800-5d36-9a4e-c9c83fc8828a",),
    "no-signal": ("07b50e61-3464-5957-8142-ac1af8c4d37b",),
    "missing-required-history": ("7de4a498-592e-5331-85af-386393957b29",),
    "simultaneous-buy-sell": ("f0f0d708-89f8-52a1-ad88-be44f2d5a971",),
}
EXPECTED_FLOW_KEYS = {
    "pairwise-basic_price_compare": (("partition-1-buy-flow-1",),),
    "pairwise-basic_price_change_percent": (
        ("partition-1-sell-flow-1",),
        ("partition-2-sell-flow-1",),
    ),
    "pairwise-basic_volume_compare": (
        ("partition-1-buy-flow-1",),
        ("partition-2-buy-flow-1",),
        ("partition-3-buy-flow-1",),
    ),
    "pairwise-basic_streak": (
        ("partition-1-sell-flow-1",),
        ("partition-2-sell-flow-1",),
        ("partition-3-sell-flow-1",),
        ("partition-4-sell-flow-1",),
    ),
    "pairwise-basic_sma_cross": (("partition-1-buy-flow-1",),),
    "pairwise-basic_rsi_cross": (
        ("partition-1-sell-flow-1",),
        ("partition-2-sell-flow-1",),
    ),
    "pairwise-basic_macd_cross": (
        ("partition-1-buy-flow-1",),
        ("partition-2-buy-flow-1",),
        ("partition-3-buy-flow-1",),
    ),
    "pairwise-basic_bollinger_reversal": (
        ("partition-1-sell-flow-1",),
        ("partition-2-sell-flow-1",),
        ("partition-3-sell-flow-1",),
        ("partition-4-sell-flow-1",),
    ),
    "pairwise-basic_position_return": (("partition-1-sell-flow-1",),),
    "pairwise-basic_holding_period": (
        ("partition-1-sell-flow-1",),
        ("partition-2-sell-flow-1",),
    ),
    "pairwise-basic_peak_return": (
        ("partition-1-sell-flow-1",),
        ("partition-2-sell-flow-1",),
        ("partition-3-sell-flow-1",),
    ),
    "pairwise-basic_drawdown_from_peak": (
        ("partition-1-sell-flow-1",),
        ("partition-2-sell-flow-1",),
        ("partition-3-sell-flow-1",),
        ("partition-4-sell-flow-1",),
    ),
    "pairwise-basic_schedule": (("partition-1-buy-flow-1",),),
    "maximum-four-partition-five-instrument-two-side": (
        ("partition-1-buy-flow-1", "partition-1-sell-flow-1"),
        ("partition-2-buy-flow-2", "partition-2-sell-flow-2"),
        ("partition-3-buy-flow-3", "partition-3-sell-flow-3"),
        (
            "partition-4-buy-flow-4",
            "partition-4-sell-flow-4",
        ),
    ),
    "contradictory-price-boundaries": (("partition-1-sell-flow-1",),),
    "duplicate-price-condition": (("partition-1-buy-flow-1",),),
    "no-signal": (("partition-1-buy-flow-1",),),
    "missing-required-history": (("partition-1-buy-flow-1",),),
    "simultaneous-buy-sell": (("partition-1-buy-flow-1", "partition-1-sell-flow-1"),),
}

_BUY_TERMINAL_ARGUMENTS = (
    ("allocation", "EQUAL"),
    ("executionMode", "1회만"),
    ("maxExecutions", "1"),
    ("maxPositionPercent", "40"),
    ("orderPercent", "25"),
    ("orderType", "MARKET"),
    ("side", "BUY"),
    ("timeInForce", "DAY"),
    ("waitInterval", "1"),
    ("waitMode", "조건 재충족"),
)
_SELL_TERMINAL_ARGUMENTS = (
    ("allocation", "EQUAL"),
    ("executionMode", "1회만"),
    ("maxExecutions", "1"),
    ("maxPositionPercent", "40"),
    ("orderPercent", "25"),
    ("orderType", "MARKET"),
    ("side", "SELL"),
    ("timeInForce", "DAY"),
    ("waitInterval", "1"),
    ("waitMode", "조건 재충족"),
)

# Literal runtime steps transcribed independently from the published basic/v1
# contract. These do not read the semantic case objects or backend artifacts.
EXPECTED_SINGLE_CHAIN_STEPS = {
    "pairwise-basic_price_compare": (
        (
            1,
            "PRICE_COMPARE",
            (
                ("operator", "GT"),
                ("reference", "PREVIOUS_CLOSE"),
                ("resolution", "30m"),
            ),
        ),
        (2, "EMIT_ORDER_CANDIDATE", _BUY_TERMINAL_ARGUMENTS),
    ),
    "pairwise-basic_price_change_percent": (
        (
            1,
            "PRICE_CHANGE_PERCENT",
            (
                ("base", "PREVIOUS_CLOSE"),
                ("direction", "UP"),
                ("resolution", "30m"),
                ("thresholdPercent", "3.5"),
            ),
        ),
        (2, "EMIT_ORDER_CANDIDATE", _SELL_TERMINAL_ARGUMENTS),
    ),
    "pairwise-basic_volume_compare": (
        (
            1,
            "VOLUME_COMPARE",
            (
                ("multiplier", "2"),
                ("operator", "GTE"),
                ("period", "20"),
                ("reference", "AVERAGE_VOLUME"),
                ("resolution", "1h"),
            ),
        ),
        (2, "EMIT_ORDER_CANDIDATE", _BUY_TERMINAL_ARGUMENTS),
    ),
    "pairwise-basic_streak": (
        (
            1,
            "STREAK",
            (("bars", "3"), ("direction", "UP"), ("resolution", "1h")),
        ),
        (2, "EMIT_ORDER_CANDIDATE", _SELL_TERMINAL_ARGUMENTS),
    ),
    "pairwise-basic_sma_cross": (
        (
            1,
            "SMA_CROSS",
            (
                ("direction", "UP"),
                ("longPeriod", "20"),
                ("resolution", "4h"),
                ("shortPeriod", "5"),
            ),
        ),
        (2, "EMIT_ORDER_CANDIDATE", _BUY_TERMINAL_ARGUMENTS),
    ),
    "pairwise-basic_rsi_cross": (
        (
            1,
            "RSI_CROSS",
            (
                ("direction", "UP"),
                ("period", "14"),
                ("resolution", "4h"),
                ("threshold", "30"),
            ),
        ),
        (2, "EMIT_ORDER_CANDIDATE", _SELL_TERMINAL_ARGUMENTS),
    ),
    "pairwise-basic_macd_cross": (
        (
            1,
            "MACD_CROSS",
            (
                ("direction", "UP"),
                ("fastPeriod", "12"),
                ("resolution", "1d"),
                ("signalPeriod", "9"),
                ("slowPeriod", "26"),
            ),
        ),
        (2, "EMIT_ORDER_CANDIDATE", _BUY_TERMINAL_ARGUMENTS),
    ),
    "pairwise-basic_bollinger_reversal": (
        (
            1,
            "BOLLINGER_REVERSAL",
            (
                ("deviations", "2"),
                ("direction", "UP"),
                ("period", "20"),
                ("resolution", "1d"),
            ),
        ),
        (2, "EMIT_ORDER_CANDIDATE", _SELL_TERMINAL_ARGUMENTS),
    ),
    "pairwise-basic_position_return": (
        (
            1,
            "PRICE_COMPARE",
            (
                ("operator", "GT"),
                ("reference", "PREVIOUS_CLOSE"),
                ("resolution", "30m"),
            ),
        ),
        (
            2,
            "POSITION_RETURN",
            (("direction", "LOSS"), ("thresholdPercent", "5")),
        ),
        (3, "EMIT_ORDER_CANDIDATE", _SELL_TERMINAL_ARGUMENTS),
    ),
    "pairwise-basic_holding_period": (
        (
            1,
            "PRICE_COMPARE",
            (
                ("operator", "GT"),
                ("reference", "PREVIOUS_CLOSE"),
                ("resolution", "1d"),
            ),
        ),
        (
            2,
            "HOLDING_PERIOD",
            (("amount", "10"), ("resolution", "1d"), ("unit", "TRADING_DAY")),
        ),
        (3, "EMIT_ORDER_CANDIDATE", _SELL_TERMINAL_ARGUMENTS),
    ),
    "pairwise-basic_peak_return": (
        (
            1,
            "PRICE_COMPARE",
            (
                ("operator", "GT"),
                ("reference", "PREVIOUS_CLOSE"),
                ("resolution", "4h"),
            ),
        ),
        (
            2,
            "PEAK_RETURN",
            (("operator", "GTE"), ("thresholdPercent", "15")),
        ),
        (3, "EMIT_ORDER_CANDIDATE", _SELL_TERMINAL_ARGUMENTS),
    ),
    "pairwise-basic_drawdown_from_peak": (
        (
            1,
            "PRICE_COMPARE",
            (
                ("operator", "GT"),
                ("reference", "PREVIOUS_CLOSE"),
                ("resolution", "1d"),
            ),
        ),
        (
            2,
            "DRAWDOWN_FROM_PEAK",
            (("operator", "GTE"), ("thresholdPercent", "7")),
        ),
        (3, "EMIT_ORDER_CANDIDATE", _SELL_TERMINAL_ARGUMENTS),
    ),
    "pairwise-basic_schedule": (
        (
            1,
            "PRICE_COMPARE",
            (
                ("operator", "GT"),
                ("reference", "PREVIOUS_CLOSE"),
                ("resolution", "1d"),
            ),
        ),
        (
            2,
            "SCHEDULE",
            (
                ("cycle", "EVERY_N_TRADING_DAYS"),
                ("interval", "5"),
                ("resolution", "1d"),
            ),
        ),
        (3, "EMIT_ORDER_CANDIDATE", _BUY_TERMINAL_ARGUMENTS),
    ),
    "contradictory-price-boundaries": (
        (
            1,
            "PRICE_COMPARE",
            (
                ("operator", "GT"),
                ("reference", "PREVIOUS_CLOSE"),
                ("resolution", "30m"),
            ),
        ),
        (
            2,
            "DRAWDOWN_FROM_PEAK",
            (("operator", "GTE"), ("thresholdPercent", "10")),
        ),
        (
            3,
            "DRAWDOWN_FROM_PEAK",
            (("operator", "LT"), ("thresholdPercent", "5")),
        ),
        (4, "EMIT_ORDER_CANDIDATE", _SELL_TERMINAL_ARGUMENTS),
    ),
    "duplicate-price-condition": (
        (
            1,
            "PRICE_COMPARE",
            (
                ("operator", "GT"),
                ("reference", "PREVIOUS_CLOSE"),
                ("resolution", "30m"),
            ),
        ),
        (
            2,
            "PRICE_COMPARE",
            (
                ("operator", "GT"),
                ("reference", "PREVIOUS_CLOSE"),
                ("resolution", "30m"),
            ),
        ),
        (3, "EMIT_ORDER_CANDIDATE", _BUY_TERMINAL_ARGUMENTS),
    ),
    "no-signal": (
        (
            1,
            "PRICE_COMPARE",
            (
                ("operator", "LT"),
                ("reference", "PREVIOUS_CLOSE"),
                ("resolution", "30m"),
            ),
        ),
        (2, "EMIT_ORDER_CANDIDATE", _BUY_TERMINAL_ARGUMENTS),
    ),
    "missing-required-history": (
        (
            1,
            "MACD_CROSS",
            (
                ("direction", "UP"),
                ("fastPeriod", "12"),
                ("resolution", "4h"),
                ("signalPeriod", "9"),
                ("slowPeriod", "26"),
            ),
        ),
        (2, "EMIT_ORDER_CANDIDATE", _BUY_TERMINAL_ARGUMENTS),
    ),
}

EXPECTED_FLOW_SPECIFIC_STEPS = {
    "maximum-four-partition-five-instrument-two-side": {
        "partition-1-buy-flow-1": (
            (
                1,
                "PRICE_COMPARE",
                (
                    ("operator", "GT"),
                    ("reference", "PREVIOUS_CLOSE"),
                    ("resolution", "30m"),
                ),
            ),
            (
                2,
                "PRICE_CHANGE_PERCENT",
                (
                    ("base", "PREVIOUS_CLOSE"),
                    ("direction", "UP"),
                    ("resolution", "30m"),
                    ("thresholdPercent", "3.5"),
                ),
            ),
            (
                3,
                "VOLUME_COMPARE",
                (
                    ("multiplier", "2"),
                    ("operator", "GTE"),
                    ("period", "20"),
                    ("reference", "AVERAGE_VOLUME"),
                    ("resolution", "30m"),
                ),
            ),
            (4, "EMIT_ORDER_CANDIDATE", _BUY_TERMINAL_ARGUMENTS),
        ),
        "partition-1-sell-flow-1": (
            (
                1,
                "PRICE_COMPARE",
                (
                    ("operator", "GT"),
                    ("reference", "PREVIOUS_CLOSE"),
                    ("resolution", "30m"),
                ),
            ),
            (
                2,
                "PRICE_CHANGE_PERCENT",
                (
                    ("base", "PREVIOUS_CLOSE"),
                    ("direction", "UP"),
                    ("resolution", "30m"),
                    ("thresholdPercent", "3.5"),
                ),
            ),
            (
                3,
                "VOLUME_COMPARE",
                (
                    ("multiplier", "2"),
                    ("operator", "GTE"),
                    ("period", "20"),
                    ("reference", "AVERAGE_VOLUME"),
                    ("resolution", "30m"),
                ),
            ),
            (4, "EMIT_ORDER_CANDIDATE", _SELL_TERMINAL_ARGUMENTS),
        ),
        "partition-2-buy-flow-2": (
            (
                1,
                "STREAK",
                (("bars", "3"), ("direction", "UP"), ("resolution", "30m")),
            ),
            (
                2,
                "SMA_CROSS",
                (
                    ("direction", "UP"),
                    ("longPeriod", "20"),
                    ("resolution", "30m"),
                    ("shortPeriod", "5"),
                ),
            ),
            (3, "EMIT_ORDER_CANDIDATE", _BUY_TERMINAL_ARGUMENTS),
        ),
        "partition-2-sell-flow-2": (
            (
                1,
                "STREAK",
                (("bars", "3"), ("direction", "UP"), ("resolution", "30m")),
            ),
            (
                2,
                "SMA_CROSS",
                (
                    ("direction", "UP"),
                    ("longPeriod", "20"),
                    ("resolution", "30m"),
                    ("shortPeriod", "5"),
                ),
            ),
            (
                3,
                "RSI_CROSS",
                (
                    ("direction", "UP"),
                    ("period", "14"),
                    ("resolution", "30m"),
                    ("threshold", "30"),
                ),
            ),
            (4, "EMIT_ORDER_CANDIDATE", _SELL_TERMINAL_ARGUMENTS),
        ),
        "partition-3-buy-flow-3": (
            (
                1,
                "RSI_CROSS",
                (
                    ("direction", "UP"),
                    ("period", "14"),
                    ("resolution", "30m"),
                    ("threshold", "30"),
                ),
            ),
            (
                2,
                "MACD_CROSS",
                (
                    ("direction", "UP"),
                    ("fastPeriod", "12"),
                    ("resolution", "30m"),
                    ("signalPeriod", "9"),
                    ("slowPeriod", "26"),
                ),
            ),
            (3, "EMIT_ORDER_CANDIDATE", _BUY_TERMINAL_ARGUMENTS),
        ),
        "partition-3-sell-flow-3": (
            (
                1,
                "MACD_CROSS",
                (
                    ("direction", "UP"),
                    ("fastPeriod", "12"),
                    ("resolution", "30m"),
                    ("signalPeriod", "9"),
                    ("slowPeriod", "26"),
                ),
            ),
            (
                2,
                "BOLLINGER_REVERSAL",
                (
                    ("deviations", "2"),
                    ("direction", "UP"),
                    ("period", "20"),
                    ("resolution", "30m"),
                ),
            ),
            (
                3,
                "POSITION_RETURN",
                (("direction", "LOSS"), ("thresholdPercent", "5")),
            ),
            (4, "EMIT_ORDER_CANDIDATE", _SELL_TERMINAL_ARGUMENTS),
        ),
        "partition-4-buy-flow-4": (
            (
                1,
                "BOLLINGER_REVERSAL",
                (
                    ("deviations", "2"),
                    ("direction", "UP"),
                    ("period", "20"),
                    ("resolution", "30m"),
                ),
            ),
            (
                2,
                "SCHEDULE",
                (
                    ("cycle", "EVERY_N_TRADING_DAYS"),
                    ("interval", "5"),
                    ("resolution", "30m"),
                ),
            ),
            (3, "EMIT_ORDER_CANDIDATE", _BUY_TERMINAL_ARGUMENTS),
        ),
        "partition-4-sell-flow-4": (
            (
                1,
                "HOLDING_PERIOD",
                (
                    ("amount", "10"),
                    ("resolution", "30m"),
                    ("unit", "TRADING_DAY"),
                ),
            ),
            (
                2,
                "PEAK_RETURN",
                (("operator", "GTE"), ("thresholdPercent", "15")),
            ),
            (
                3,
                "DRAWDOWN_FROM_PEAK",
                (("operator", "GTE"), ("thresholdPercent", "7")),
            ),
            (4, "EMIT_ORDER_CANDIDATE", _SELL_TERMINAL_ARGUMENTS),
        ),
    },
    "simultaneous-buy-sell": {
        "partition-1-buy-flow-1": (
            (
                1,
                "PRICE_COMPARE",
                (
                    ("operator", "GT"),
                    ("reference", "PREVIOUS_CLOSE"),
                    ("resolution", "30m"),
                ),
            ),
            (2, "EMIT_ORDER_CANDIDATE", _BUY_TERMINAL_ARGUMENTS),
        ),
        "partition-1-sell-flow-1": (
            (
                1,
                "PRICE_COMPARE",
                (
                    ("operator", "GT"),
                    ("reference", "PREVIOUS_CLOSE"),
                    ("resolution", "30m"),
                ),
            ),
            (2, "EMIT_ORDER_CANDIDATE", _SELL_TERMINAL_ARGUMENTS),
        ),
    },
}
EXPECTED_EXECUTIONS = {
    "pairwise-basic_price_compare": (1, "COMPLETED", "AVAILABLE", (("CANDIDATE", 1),)),
    "pairwise-basic_price_change_percent": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("CONDITION_NOT_MET", 2), ("INPUT_MISSING", 2)),
    ),
    "pairwise-basic_volume_compare": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("CONDITION_NOT_MET", 3), ("INPUT_MISSING", 6)),
    ),
    "pairwise-basic_streak": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("CONDITION_NOT_MET", 4), ("INPUT_MISSING", 12)),
    ),
    "pairwise-basic_sma_cross": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("CONDITION_NOT_MET", 1), ("INPUT_MISSING", 4)),
    ),
    "pairwise-basic_rsi_cross": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("CONDITION_NOT_MET", 2),),
    ),
    "pairwise-basic_macd_cross": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("CONDITION_NOT_MET", 3), ("INPUT_MISSING", 3)),
    ),
    "pairwise-basic_bollinger_reversal": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("CONDITION_NOT_MET", 4), ("INPUT_MISSING", 8)),
    ),
    "pairwise-basic_position_return": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("CANDIDATE", 1), ("INPUT_MISSING", 3)),
    ),
    "pairwise-basic_holding_period": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("CONDITION_NOT_MET", 2), ("INPUT_MISSING", 8)),
    ),
    "pairwise-basic_peak_return": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("CONDITION_NOT_MET", 3),),
    ),
    "pairwise-basic_drawdown_from_peak": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("CONDITION_NOT_MET", 4), ("INPUT_MISSING", 4)),
    ),
    "pairwise-basic_schedule": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("CONDITION_NOT_MET", 1), ("INPUT_MISSING", 2)),
    ),
    "maximum-four-partition-five-instrument-two-side": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("CANDIDATE", 1), ("CONDITION_NOT_MET", 4), ("INPUT_MISSING", 35)),
    ),
    "contradictory-price-boundaries": (
        0,
        "COMPLETED",
        "AVAILABLE",
        (("CONDITION_NOT_MET", 1),),
    ),
    "duplicate-price-condition": (1, "COMPLETED", "AVAILABLE", (("CANDIDATE", 1),)),
    "no-signal": (0, "COMPLETED", "AVAILABLE", (("CONDITION_NOT_MET", 1),)),
    "missing-required-history": (
        0,
        "UNAVAILABLE",
        "UNAVAILABLE",
        (("INPUT_MISSING", 1),),
    ),
    "simultaneous-buy-sell": (2, "COMPLETED", "AVAILABLE", (("CANDIDATE", 2),)),
}


def _compiled(case: matrix.BasicStrategyCase) -> dict[str, object]:
    boundary = getattr(matrix, "backend_compiled_plan", None)
    assert callable(boundary), (
        "production backend compiled-plan export boundary is missing"
    )
    return boundary(case)


def _step_shape(step: PlanStep) -> tuple[int, str, tuple[tuple[str, str], ...]]:
    return (
        step.sequence,
        step.operation,
        tuple(
            sorted((str(name), str(value)) for name, value in step.arguments.items())
        ),
    )


def _expected_steps_for_flow(case_name: str, flow_id: str):
    if case_name in EXPECTED_FLOW_SPECIFIC_STEPS:
        return EXPECTED_FLOW_SPECIFIC_STEPS[case_name][flow_id]
    return EXPECTED_SINGLE_CHAIN_STEPS[case_name]


def _expected_loaded_case_shape(case_name: str):
    resolution, sides, partition_count, instrument_count = EXPECTED_SHAPES[case_name]
    partition_keys = EXPECTED_PARTITION_KEYS[case_name]
    flow_keys_by_partition = EXPECTED_FLOW_KEYS[case_name]
    assert len(partition_keys) == partition_count
    assert len(flow_keys_by_partition) == partition_count

    expected = []
    for partition_key, flow_keys in zip(
        partition_keys, flow_keys_by_partition, strict=True
    ):
        for flow_id in flow_keys:
            steps = _expected_steps_for_flow(case_name, flow_id)
            terminal = steps[-1]
            terminal_arguments = dict(terminal[2])
            expected.append(
                (
                    partition_key,
                    flow_id,
                    10_000,
                    terminal_arguments["side"],
                    EXPECTED_LOADED_INSTRUMENT_IDS[instrument_count],
                    steps[:-1],
                    terminal,
                    "EQUAL",
                    ("ADJUSTED_BAR", resolution),
                )
            )
    assert {flow[3] for flow in expected} == set(sides)
    return tuple(expected)


def _assert_exact_loaded_case_shape(case_name: str, plan) -> None:
    assert set(EXPECTED_SINGLE_CHAIN_STEPS) | set(EXPECTED_FLOW_SPECIFIC_STEPS) == set(
        EXPECTED_SHAPES
    )
    assert set(EXPECTED_SINGLE_CHAIN_STEPS).isdisjoint(EXPECTED_FLOW_SPECIFIC_STEPS)
    for special_case, expected_by_flow in EXPECTED_FLOW_SPECIFIC_STEPS.items():
        assert set(expected_by_flow) == {
            flow_id
            for partition_flow_ids in EXPECTED_FLOW_KEYS[special_case]
            for flow_id in partition_flow_ids
        }

    actual = []
    for flow in plan.flows:
        assert flow.terminal_step is not None
        actual.append(
            (
                flow.partition_key,
                flow.flow_id,
                flow.budget_cap_bps,
                flow.side,
                flow.instrument_ids,
                tuple(_step_shape(step) for step in flow.condition_steps),
                _step_shape(flow.terminal_step),
                flow.allocation,
                flow.reference_series,
            )
        )
    expected = _expected_loaded_case_shape(case_name)
    assert tuple(actual) == expected, (
        f"loaded flow shapes for {case_name} differ:\n"
        f"actual={tuple(actual)!r}\nexpected={expected!r}"
    )


def test_generated_matrix_has_hand_checked_size_and_complete_catalog_coverage() -> None:
    cases = matrix.generated_cases()
    covered = frozenset(code for case in cases for code in case.element_codes)

    assert len(cases) == 19
    matrix.assert_complete_coverage(cases)
    assert covered == EXPECTED_ELEMENT_CODES
    assert matrix.required_element_codes() == EXPECTED_ELEMENT_CODES
    assert matrix.condition_element_codes() == EXPECTED_CONDITION_CODES
    assert {case.partition_count for case in cases} == {1, 2, 3, 4}
    assert {case.instrument_count for case in cases} == {1, 2, 3, 4, 5}


def test_pairwise_resolution_and_side_coverage_is_complete_and_deterministic() -> None:
    cases = matrix.generated_cases()
    pairwise = tuple(case for case in cases if case.name.startswith("pairwise-"))
    pairs = {(case.resolution, side) for case in pairwise for side in case.sides}

    assert len(pairwise) == 13
    assert pairs == {
        ("30m", "BUY"),
        ("30m", "SELL"),
        ("1h", "BUY"),
        ("1h", "SELL"),
        ("4h", "BUY"),
        ("4h", "SELL"),
        ("1d", "BUY"),
        ("1d", "SELL"),
    }
    assert matrix.generated_cases() == cases


def test_curated_cases_cover_all_six_special_shapes_without_losing_duplicates() -> None:
    by_name = {case.name: case for case in matrix.generated_cases()}

    assert set(by_name) >= {
        "maximum-four-partition-five-instrument-two-side",
        "contradictory-price-boundaries",
        "duplicate-price-condition",
        "no-signal",
        "missing-required-history",
        "simultaneous-buy-sell",
    }
    maximum = by_name["maximum-four-partition-five-instrument-two-side"]
    assert (maximum.partition_count, maximum.instrument_count) == (4, 5)
    assert frozenset(maximum.element_codes) == EXPECTED_ELEMENT_CODES
    assert maximum.sides == ("BUY", "SELL")
    contradiction = by_name["contradictory-price-boundaries"]
    drawdowns = [
        step for step in contradiction.steps if step.operation == "DRAWDOWN_FROM_PEAK"
    ]
    assert [step.arguments for step in drawdowns] == [
        {"operator": "GTE", "thresholdPercent": "10"},
        {"operator": "LT", "thresholdPercent": "5"},
    ]
    duplicate = by_name["duplicate-price-condition"]
    assert duplicate.element_codes.count("BASIC_PRICE_COMPARE") == 2
    assert duplicate.steps[0].arguments == duplicate.steps[1].arguments
    assert by_name["no-signal"].input_scenario == "false"
    assert by_name["missing-required-history"].input_scenario == "missing"
    simultaneous = by_name["simultaneous-buy-sell"]
    assert simultaneous.sides == ("BUY", "SELL")


def test_numeric_oracle_covers_every_published_boundary_independently() -> None:
    factory = getattr(matrix, "numeric_validation_cases", None)
    assert callable(factory), "numeric validation oracle is missing"
    cases = factory()

    assert len(cases) == 89
    assert (
        len(
            {
                (case.operation, case.parameter, case.arguments[case.parameter])
                for case in cases
            }
        )
        == 78
    )
    assert {
        (case.operation, case.parameter) for case in cases
    } == EXPECTED_NUMERIC_PARAMETERS
    assert Counter(case.category for case in cases) == {
        "minimum": 11,
        "maximum": 6,
        "inside": 11,
        "outside": 6,
        "zero": 11,
        "negative": 11,
        "decimal": 11,
        "empty": 11,
        "malformed": 11,
    }

    catalog = element_catalog("basic-elements:2026-08-25")
    for case in cases:
        step = PlanStep(sequence=1, operation=case.operation, arguments=case.arguments)
        if case.accepted:
            catalog.validate_step(step)
        else:
            with pytest.raises(ElementCompatibilityError, match=case.parameter):
                catalog.validate_step(step)


class _InputIdentityRuntime(BasicPlanRuntime):
    def __init__(self) -> None:
        super().__init__()
        self.input_ids: dict[str, set[int]] = {}

    def evaluation_for(self, instrument_id, instrument_input, as_of):
        self.input_ids.setdefault(instrument_id, set()).add(id(instrument_input))
        return super().evaluation_for(instrument_id, instrument_input, as_of)


class _StoredObjectReader:
    def iter_batches(self, manifest, policy, *, instrument_ids):
        if manifest["resolution"] != "30m":
            return iter(())
        table = pq.read_table(load_stored_market_snapshot().path)
        selected = table.filter(
            pc.and_(
                pc.is_in(
                    table["instrument_id"], value_set=pa.array(list(instrument_ids))
                ),
                pc.and_(
                    pc.greater_equal(
                        table["bar_start_at"], pa.scalar(policy.period_start)
                    ),
                    pc.less(table["bar_start_at"], pa.scalar(policy.period_end)),
                ),
            )
        )
        return iter(selected.to_batches())


class _PositionRecordingEngine(RecordingEngine):
    def runtime_values(self, instant, events):
        values = load_stored_market_snapshot().inputs[INSTRUMENT_ID].values
        return {INSTRUMENT_ID: values}


def _orchestrated_outcome(case, runtime, plan):
    snapshot = load_stored_market_snapshot()
    requirements = derive_data_requirements(
        plan,
        evaluation_from=snapshot.as_of,
        evaluation_through=snapshot.as_of + timedelta(minutes=30),
    )
    resolution = plan.flows[0].reference_series[1]
    manifest = {"resolution": resolution}
    run_id = str(uuid.uuid5(uuid.NAMESPACE_URL, f"task3:{case.name}"))
    job = BacktestJob(
        run_id=run_id,
        idempotency_key=f"TASK3:{case.name}",
        worker_execution_key=f"TASK3:{case.name}:attempt-1",
        manifest=manifest,
        execution_policy=D17_EXECUTION_POLICY_FIXTURE,
        requirements=requirements,
        data_kind="ADJUSTED_BAR",
        resolution=resolution,
        initial_cash=Decimal(100000),
        evaluation_from=snapshot.as_of,
        evaluation_through=snapshot.as_of + timedelta(minutes=30),
    )
    engine = _PositionRecordingEngine()
    publisher = RecordingPublisher()

    def replay_factory(*, clock, assessment):
        return BasicPlanReplay(
            runtime=runtime, plan=plan, clock=clock, assessment=assessment
        )

    orchestrator = BacktestOrchestrator(
        reader=_StoredObjectReader(),
        calendar=XNYS_CALENDAR,
        replay_factory=replay_factory,
        engine=engine,
        publisher=publisher,
        wall_clock=WallClock(),
    )
    coordinator = AttemptCoordinator(run_id, _policy(), WALL_T0)
    lease = coordinator.acquire("task3-worker", WALL_T0)
    outcome = orchestrator.run(
        job, coordinator=coordinator, lease=lease, monitor=FixedMonitor()
    )
    return outcome, len(engine.placed)


def _actual_case_outcome(
    case: matrix.BasicStrategyCase,
) -> tuple[int, ReplayStatus, AvailabilityStatus, tuple[tuple[str, int], ...]]:
    document = _compiled(case)
    runtime = _InputIdentityRuntime()
    plan = runtime.load(document)
    snapshot = load_stored_market_snapshot()
    missing = case.input_scenario == "missing"
    execution = runtime.execute(
        plan, {} if missing else snapshot.inputs, as_of=snapshot.as_of
    )
    assert all(len(ids) == 1 for ids in runtime.input_ids.values())
    runtime.input_ids.clear()
    outcome, signal_count = _orchestrated_outcome(case, runtime, plan)
    assert all(len(ids) == 1 for ids in runtime.input_ids.values())
    decision_counts = Counter(decision.status.value for decision in execution.decisions)
    return (
        signal_count,
        outcome.status,
        outcome.availability_status,
        tuple(sorted(decision_counts.items())),
    )


def test_materialized_documents_consume_resolution_side_partition_and_instruments() -> (
    None
):
    by_name = {case.name: case for case in matrix.generated_cases()}

    assert set(by_name) == set(EXPECTED_SHAPES)
    assert set(EXPECTED_PARTITION_KEYS) == set(EXPECTED_SHAPES)
    assert set(EXPECTED_FLOW_KEYS) == set(EXPECTED_SHAPES)
    for name, (resolution, sides, partitions, instruments) in EXPECTED_SHAPES.items():
        case = by_name[name]
        semantic = matrix.semantic_document(case)
        compiled = _compiled(case)
        plan = BasicPlanRuntime().load(compiled)

        _assert_exact_loaded_case_shape(name, plan)
        matrix.assert_loaded_partition_identities(
            compiled, plan, EXPECTED_PARTITION_KEYS[name]
        )
        raw_partitions = compiled["executionSnapshot"]["partitions"]
        assert (
            tuple(
                tuple(flow["key"] for flow in partition["flows"])
                for partition in raw_partitions
            )
            == EXPECTED_FLOW_KEYS[name]
        )
        assert (
            tuple(
                tuple(
                    flow.flow_id
                    for flow in plan.flows
                    if flow.partition_key == partition_key
                )
                for partition_key in EXPECTED_PARTITION_KEYS[name]
            )
            == EXPECTED_FLOW_KEYS[name]
        )

        assert {group["container"] for group in semantic["groups"]} == set(sides)
        assert all(
            len(
                [
                    block
                    for block in group["blocks"]
                    if block["elementCode"] != "BASIC_EQUAL_ALLOCATION_ORDER"
                ]
            )
            <= 5
            for group in semantic["groups"]
        )
        assert len(compiled["executionSnapshot"]["partitions"]) == partitions
        assert {flow.side for flow in plan.flows} == set(sides)
        assert len(plan.instrument_ids) == instruments
        assert plan.instrument_ids == EXPECTED_LOADED_INSTRUMENT_IDS[instruments]
        assert all(
            flow.instrument_ids == EXPECTED_LOADED_INSTRUMENT_IDS[instruments]
            for flow in plan.flows
        )
        assert {flow.reference_series for flow in plan.flows} == {
            ("ADJUSTED_BAR", resolution)
        }
        assert all(
            flow.terminal_step.operation == "EMIT_ORDER_CANDIDATE"
            for flow in plan.flows
        )
        assert all(
            raw_flow["steps"][-1]["operation"] == "EMIT_ORDER_CANDIDATE"
            and all(
                step["operation"] != "EMIT_ORDER_CANDIDATE"
                for step in raw_flow["steps"][:-1]
            )
            for partition in raw_partitions
            for raw_flow in partition["flows"]
        )
        assert all(flow.condition_steps for flow in plan.flows)


def test_loaded_partition_identity_oracle_rejects_a_mutated_backend_artifact() -> None:
    case = next(case for case in matrix.generated_cases() if case.name == "no-signal")
    compiled = copy.deepcopy(_compiled(case))
    compiled["executionSnapshot"]["partitions"][0]["key"] = (
        "ffffffff-ffff-4fff-8fff-ffffffffffff"
    )
    from backtest_engine.contracts import compute_compiled_plan_checksum

    compiled["planChecksum"] = compute_compiled_plan_checksum(compiled)
    plan = BasicPlanRuntime().load(compiled)

    with pytest.raises(AssertionError, match="partition identities"):
        matrix.assert_loaded_partition_identities(
            compiled, plan, EXPECTED_PARTITION_KEYS[case.name]
        )


def test_exact_loaded_step_shape_oracle_rejects_duplicate_condition_loss() -> None:
    case = next(
        case
        for case in matrix.generated_cases()
        if case.name == "duplicate-price-condition"
    )
    compiled = copy.deepcopy(_compiled(case))
    steps = compiled["executionSnapshot"]["partitions"][0]["flows"][0]["steps"]
    steps.pop(0)
    for sequence, step in enumerate(steps, start=1):
        step["sequence"] = sequence
    from backtest_engine.contracts import compute_compiled_plan_checksum

    compiled["planChecksum"] = compute_compiled_plan_checksum(compiled)
    plan = BasicPlanRuntime().load(compiled)

    with pytest.raises(AssertionError, match="loaded flow shapes"):
        _assert_exact_loaded_case_shape(case.name, plan)


def _swap_contradictory_bounds(document: dict[str, object]) -> None:
    steps = document["executionSnapshot"]["partitions"][0]["flows"][0]["steps"]
    steps[1], steps[2] = steps[2], steps[1]
    for sequence, step in enumerate(steps, start=1):
        step["sequence"] = sequence


def _change_condition_argument(document: dict[str, object]) -> None:
    document["executionSnapshot"]["partitions"][0]["flows"][0]["steps"][0]["arguments"][
        "operator"
    ] = "GT"


def _rename_compiled_group(document: dict[str, object]) -> None:
    document["executionSnapshot"]["partitions"][0]["flows"][0]["key"] = (
        "partition-1-renamed-buy-group"
    )


def _change_container_side(document: dict[str, object]) -> None:
    document["executionSnapshot"]["partitions"][0]["flows"][0]["steps"][-1][
        "arguments"
    ]["side"] = "SELL"


def _change_terminal_argument(document: dict[str, object]) -> None:
    document["executionSnapshot"]["partitions"][0]["flows"][0]["steps"][-1][
        "arguments"
    ]["orderPercent"] = "30"


def _reverse_instrument_order(document: dict[str, object]) -> None:
    instruments = document["executionSnapshot"]["partitions"][0]["flows"][0][
        "officialInstrumentIds"
    ]
    instruments.reverse()


@pytest.mark.parametrize(
    ("case_name", "mutate"),
    (
        ("contradictory-price-boundaries", _swap_contradictory_bounds),
        ("no-signal", _change_condition_argument),
        ("pairwise-basic_price_compare", _rename_compiled_group),
        ("pairwise-basic_price_compare", _change_container_side),
        ("pairwise-basic_price_compare", _change_terminal_argument),
        ("pairwise-basic_price_change_percent", _reverse_instrument_order),
    ),
    ids=(
        "condition-reordering",
        "condition-arguments",
        "group-identity",
        "container-side",
        "terminal-arguments",
        "instrument-order",
    ),
)
def test_exact_loaded_step_shape_oracle_rejects_semantic_mutations(
    case_name: str, mutate: Callable[[dict[str, object]], None]
) -> None:
    case = next(case for case in matrix.generated_cases() if case.name == case_name)
    compiled = copy.deepcopy(_compiled(case))
    mutate(compiled)
    from backtest_engine.contracts import compute_compiled_plan_checksum

    compiled["planChecksum"] = compute_compiled_plan_checksum(compiled)
    plan = BasicPlanRuntime().load(compiled)

    with pytest.raises(AssertionError, match="loaded flow shapes"):
        _assert_exact_loaded_case_shape(case.name, plan)


def test_maximum_distributes_occurrences_without_duplicate_side_containers() -> None:
    case = next(
        case
        for case in matrix.generated_cases()
        if case.name == "maximum-four-partition-five-instrument-two-side"
    )
    document = _compiled(case)
    partitions = document["executionSnapshot"]["partitions"]

    assert len(partitions) == 4
    assert all(
        Counter(flow["steps"][-1]["arguments"]["side"] for flow in partition["flows"])
        <= Counter({"BUY": 1, "SELL": 1})
        for partition in partitions
    )
    assert all(
        len(flow["steps"][:-1]) <= 5
        for partition in partitions
        for flow in partition["flows"]
    )
    actual_conditions = Counter(
        step["operation"]
        for partition in partitions
        for flow in partition["flows"]
        for step in flow["steps"][:-1]
    )
    assert actual_conditions == Counter(
        {
            "PRICE_COMPARE": 2,
            "PRICE_CHANGE_PERCENT": 2,
            "VOLUME_COMPARE": 2,
            "STREAK": 2,
            "SMA_CROSS": 2,
            "RSI_CROSS": 2,
            "MACD_CROSS": 2,
            "BOLLINGER_REVERSAL": 2,
            "POSITION_RETURN": 1,
            "HOLDING_PERIOD": 1,
            "PEAK_RETURN": 1,
            "DRAWDOWN_FROM_PEAK": 1,
            "SCHEDULE": 1,
        }
    )


@pytest.mark.parametrize(
    ("field", "corrupt"),
    (
        ("manifest_id", "00000000-0000-4000-8000-000000000000"),
        ("dataset_hash", "0" * 64),
        ("object_key", "wrong/object.parquet"),
        ("provider_version_id", "wrong-version"),
        ("content_hash", "0" * 64),
        ("byte_size", 1),
        ("dataset_row_count", 1),
        ("object_row_count", 1),
    ),
)
def test_stored_market_manifest_rejects_every_corrupt_immutable_pin(
    field: str, corrupt: object
) -> None:
    metadata = {
        "manifest_id": "bb559227-dec3-54bd-876d-167c12c6e355",
        "dataset_hash": "1bef63d47c134926e9011c3f3df6dba737fe48588a51d12ae78a0c68876f5e21",
        "manifest_status": "AVAILABLE",
        "object_count": 1,
        "dataset_row_count": 3258,
        "object_id": "4b0f38c4-5474-5564-8c64-be1799472082",
        "object_status": "AVAILABLE",
        "bucket": "idea2strategy-local-market-data",
        "object_key": (
            "historical/provider=alpaca/feed=sip/adjustment=all/session=regular/"
            "resolution=30m/revision=00000004/year=2024/shard=00-of-01/"
            "manifest_id=bb559227-dec3-54bd-876d-167c12c6e355/part-00001.parquet"
        ),
        "provider_version_id": "0879c1fb-df66-40c6-a955-695c6d531d03",
        "content_hash": "fa0cebb4e33275239b8ed4f801bdd137508f68bf2b6411f0ab036df3ec283d08",
        "byte_size": 381720,
        "object_row_count": 3258,
        "file_format": "PARQUET",
        "schema_version": "market-bars/1",
    }
    metadata[field] = corrupt

    with pytest.raises(AssertionError, match=field):
        stored_snapshot.validate_pinned_market_manifest(metadata)


def test_runtime_uses_one_verified_stored_snapshot_without_relabeling_market_values() -> (
    None
):
    snapshot = load_stored_market_snapshot()
    series = snapshot.inputs[INSTRUMENT_ID].series_for("ADJUSTED_BAR", "30m")

    assert (
        snapshot.object_sha256
        == "fa0cebb4e33275239b8ed4f801bdd137508f68bf2b6411f0ab036df3ec283d08"
    )
    assert (
        snapshot.corpus_sha256
        == "961c0b76f5638c397851e1e909acd8d495fa554904a0349b4aa799bbb90f9286"
    )
    assert snapshot.manifest_id == "bb559227-dec3-54bd-876d-167c12c6e355"
    assert (
        snapshot.dataset_sha256
        == "1bef63d47c134926e9011c3f3df6dba737fe48588a51d12ae78a0c68876f5e21"
    )
    assert snapshot.object_version_id == "0879c1fb-df66-40c6-a955-695c6d531d03"
    assert (snapshot.byte_size, snapshot.row_count) == (381720, 3258)
    assert series is not None
    assert [
        (bar.starts_at.isoformat(), str(bar.close), str(bar.volume))
        for bar in series.bars
    ] == [
        ("2024-01-02T14:30:00+00:00", "341.45", "2977488"),
        ("2024-01-02T15:00:00+00:00", "338.6", "1816210"),
        ("2024-01-02T15:30:00+00:00", "337.74", "1756774"),
        ("2024-01-02T16:00:00+00:00", "341.03", "1357032"),
    ]
    assert snapshot.event_ids == tuple(
        f"bb559227-dec3-54bd-876d-167c12c6e355:{index}" for index in range(1, 5)
    )


def test_special_outcomes_are_observed_from_loaded_plan_and_pinned_owner_inputs() -> (
    None
):
    by_name = {case.name: case for case in matrix.generated_cases()}
    expected = {
        "no-signal": (
            0,
            ReplayStatus.COMPLETED,
            AvailabilityStatus.AVAILABLE,
            ((BasicDecisionStatus.CONDITION_NOT_MET.value, 1),),
        ),
        "missing-required-history": (
            0,
            ReplayStatus.UNAVAILABLE,
            AvailabilityStatus.UNAVAILABLE,
            ((BasicDecisionStatus.INPUT_MISSING.value, 1),),
        ),
        "simultaneous-buy-sell": (
            2,
            ReplayStatus.COMPLETED,
            AvailabilityStatus.AVAILABLE,
            ((BasicDecisionStatus.CANDIDATE.value, 2),),
        ),
        "contradictory-price-boundaries": (
            0,
            ReplayStatus.COMPLETED,
            AvailabilityStatus.AVAILABLE,
            ((BasicDecisionStatus.CONDITION_NOT_MET.value, 1),),
        ),
    }

    assert {name: _actual_case_outcome(by_name[name]) for name in expected} == expected


def test_unknown_enum_oracle_rejects_every_published_enumerated_parameter() -> None:
    factory = getattr(matrix, "unknown_enum_cases", None)
    assert callable(factory), "unknown-enum oracle is missing"
    cases = factory()

    assert len(cases) == 43
    assert {
        (case.operation, case.parameter) for case in cases
    } == EXPECTED_ENUM_PARAMETERS

    catalog = element_catalog("basic-elements:2026-08-25")
    for case in cases:
        with pytest.raises(ElementCompatibilityError, match=case.parameter):
            catalog.validate_step(
                PlanStep(sequence=1, operation=case.operation, arguments=case.arguments)
            )


@pytest.mark.parametrize("seed", EXPECTED_SEEDS, ids=lambda seed: f"seed-{seed}")
def test_every_generated_element_uses_arguments_the_v2_runtime_really_accepts_in_shuffled_order(
    seed: int,
) -> None:
    shuffle = getattr(matrix, "shuffled_cases", None)
    assert callable(shuffle), "fixed-seed shuffle is missing"
    assert matrix.SHUFFLE_SEEDS == EXPECTED_SEEDS

    shuffled = shuffle(seed)
    assert shuffled == shuffle(seed)
    assert Counter(case.name for case in shuffled) == Counter(
        case.name for case in matrix.generated_cases()
    )
    assert tuple(case.name for case in shuffled) != tuple(
        case.name for case in matrix.generated_cases()
    )

    for generated in shuffled:
        try:
            semantic = matrix.semantic_document(generated)
            assert semantic["groups"]
            BasicPlanRuntime().load(_compiled(generated))
            signals, status, availability, decisions = _actual_case_outcome(generated)
            assert (signals, status.value, availability.value, decisions) == (
                EXPECTED_EXECUTIONS[generated.name]
            )
        except Exception as failure:  # noqa: BLE001 - seed/case identity must wrap every owner failure
            pytest.fail(
                f"seed={seed} case={generated.name}: {type(failure).__name__}: {failure}"
            )
