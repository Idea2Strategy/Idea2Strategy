"""Generated complex-shape contract matrix complementing the three-lane runtime proof."""

from __future__ import annotations

import pytest
from backtest_engine.elements import PlanStep, element_catalog

from basic_strategy_cases import (
    RESOLUTIONS,
    SIDES,
    assert_complete_coverage,
    corpus,
    generated_cases,
    required_element_codes,
)


pytestmark = pytest.mark.docker


def test_generated_matrix_has_hand_checked_size_and_complete_catalog_coverage() -> None:
    cases = generated_cases()

    assert len(cases) == 16
    assert_complete_coverage(cases)
    assert frozenset(code for case in cases for code in case.element_codes) == required_element_codes()


def test_pairwise_resolution_and_side_coverage_is_complete_and_deterministic() -> None:
    cases = generated_cases()
    pairs = {(case.resolution, case.side) for case in cases if case.available}

    assert pairs >= {(resolution, side) for resolution in RESOLUTIONS for side in SIDES}
    assert generated_cases() == cases


def test_curated_cases_cover_maximum_warning_and_unavailable_shapes() -> None:
    by_name = {case.name: case for case in generated_cases()}

    maximum = by_name["maximum-four-partition-five-instrument-two-side"]
    assert (maximum.partition_count, maximum.instrument_count) == (4, 5)
    assert maximum.element_codes == required_element_codes()
    assert by_name["contradictory-price-boundaries"].expected_warning_codes == (
        "CONTRADICTORY_CONDITIONS",
    )
    assert by_name["missing-required-history"].available is False


def test_every_generated_element_uses_arguments_the_v2_runtime_really_accepts() -> None:
    document = corpus()
    catalog = element_catalog(str(document["catalogVersion"]))
    for case in document["cases"]:
        arguments = dict(case["arguments"])
        if case["operation"] == "EMIT_ORDER_CANDIDATE":
            arguments.update(
                allocation="EQUAL", orderType="MARKET", timeInForce="DAY", side="BUY"
            )
        catalog.validate_step(
            PlanStep(sequence=1, operation=case["operation"], arguments=arguments)
        )
