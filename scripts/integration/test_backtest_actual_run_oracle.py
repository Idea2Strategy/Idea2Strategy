from __future__ import annotations

from collections import deque
from decimal import Decimal

import pytest
from backtest_actual_run_oracle import consume_fifo, expected_fill_values, infer_side


def test_fill_math_is_hand_calculated_at_eight_decimal_places() -> None:
    assert expected_fill_values(
        base_price=Decimal("100.25000000"),
        quantity=Decimal("122.00000000"),
        side="BUY",
        slippage_bps=Decimal(5),
        fee_rate=Decimal("0.002"),
    ) == (
        Decimal("100.30012500"),
        Decimal("12236.61525000"),
        Decimal("6.11525000"),
        Decimal("24.47323050"),
    )


def test_fifo_oracle_consumes_partial_lots_without_production_helpers() -> None:
    lots = deque(
        ([Decimal(2), Decimal("20.00000000")], [Decimal(3), Decimal("36.00000000")])
    )

    assert consume_fifo(lots, Decimal(4)) == Decimal("44.00000000")
    assert lots == deque(([Decimal(1), Decimal("12.00000000")],))


def test_ledger_side_requires_exactly_one_security_entry() -> None:
    assert infer_side([{"account_code": "SECURITY", "direction": "DEBIT"}]) == "BUY"
    assert infer_side([{"account_code": "SECURITY", "direction": "CREDIT"}]) == "SELL"
    with pytest.raises(AssertionError, match="exactly one"):
        infer_side([])
