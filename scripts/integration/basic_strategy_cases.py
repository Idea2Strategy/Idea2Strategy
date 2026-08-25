"""Deterministic Basic strategy coverage matrix shared by local and CI integration tests."""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CORPUS = ROOT / "contracts/fixtures/basic-strategy/v1/basic-element-conformance.v1.json"
RESOLUTIONS = ("30m", "1h", "4h", "1d")
SIDES = ("BUY", "SELL")


@dataclass(frozen=True, slots=True)
class BasicStrategyCase:
    name: str
    element_codes: frozenset[str]
    resolution: str
    side: str
    instrument_count: int = 1
    partition_count: int = 1
    expected_warning_codes: tuple[str, ...] = ()
    available: bool = True


def corpus() -> dict[str, object]:
    return json.loads(CORPUS.read_text(encoding="utf-8"))


def required_element_codes() -> frozenset[str]:
    return frozenset(str(case["elementCode"]) for case in corpus()["cases"])


def generated_cases() -> tuple[BasicStrategyCase, ...]:
    cases = corpus()["cases"]
    conditions = [case for case in cases if case["operation"] != "EMIT_ORDER_CANDIDATE"]
    terminal = next(case for case in cases if case["operation"] == "EMIT_ORDER_CANDIDATE")
    result: list[BasicStrategyCase] = []
    both_index = 0
    for index, condition in enumerate(conditions):
        containers = tuple(condition["containers"])
        if len(containers) == 2:
            resolution = RESOLUTIONS[(both_index // 2) % len(RESOLUTIONS)]
            side = SIDES[both_index % 2]
            both_index += 1
        else:
            resolution = RESOLUTIONS[index % len(RESOLUTIONS)]
            side = str(containers[0])
        result.append(BasicStrategyCase(
            name=f"single-{str(condition['elementCode']).lower()}",
            element_codes=frozenset((str(condition["elementCode"]), str(terminal["elementCode"]))),
            resolution=resolution,
            side=side,
            instrument_count=2 if index % 3 == 0 else 1,
            partition_count=1 + index % 4,
        ))

    result.extend((
        BasicStrategyCase(
            name="maximum-four-partition-five-instrument-two-side",
            element_codes=required_element_codes(),
            resolution="30m",
            side="BUY",
            instrument_count=5,
            partition_count=4,
        ),
        BasicStrategyCase(
            name="contradictory-price-boundaries",
            element_codes=frozenset((
                "BASIC_PRICE_COMPARE",
                "BASIC_PRICE_CHANGE_PERCENT",
                "BASIC_EQUAL_ALLOCATION_ORDER",
            )),
            resolution="1h",
            side="BUY",
            expected_warning_codes=("CONTRADICTORY_CONDITIONS",),
        ),
        BasicStrategyCase(
            name="missing-required-history",
            element_codes=frozenset(("BASIC_MACD_CROSS", "BASIC_EQUAL_ALLOCATION_ORDER")),
            resolution="4h",
            side="BUY",
            available=False,
        ),
    ))
    return tuple(result)


def assert_complete_coverage(cases: tuple[BasicStrategyCase, ...]) -> None:
    covered = frozenset(code for case in cases for code in case.element_codes)
    missing = sorted(required_element_codes() - covered)
    if missing:
        raise AssertionError(f"CATALOG_CASES_MISSING: {','.join(missing)}")
