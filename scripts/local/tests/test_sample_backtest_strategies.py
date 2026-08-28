from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sample_backtest_strategies import (
    SAMPLE_REVISION,
    LocalSampleApi,
    build_samples,
    seed_samples,
)

CATALOG_ID = "0f5a0000-0000-4000-8000-000000000001"
INSTRUMENTS = {
    "AAPL": "aa268aa6-9401-49d0-a2d4-a2a490df7d84",
    "MSFT": "35ca27e4-8d72-4fe3-a54c-5066b4c15dcd",
    "SPY": "7f20f2a6-dd68-4ea1-a948-ff629edd9295",
    "QQQ": "eac80a3b-662f-432b-9d12-a2a2894c7738",
    "META": "7233ce25-2963-4f55-91cd-907f405c4518",
    "NVDA": "5a214db8-9b32-4534-9b5b-95df27bde5a4",
}


def test_samples_are_complex_editable_buy_and_sell_strategies() -> None:
    samples = build_samples(CATALOG_ID, INSTRUMENTS)

    assert [sample.key for sample in samples] == [
        "AAPL_MOMENTUM_REVERSAL",
        "MSFT_STREAK_REVERSAL",
        "LIQUID_MULTI_ASSET_CYCLE",
        "FULL_CATALOG_MIXED_RESOLUTION",
    ]
    for sample in samples:
        assert sample.minimum_fill_count > 0
        assert sample.minimum_closing_trade_count > 0
        assert sample.minimum_trade_month_count >= 2
        assert sample.semantic_document["catalogId"] == CATALOG_ID

        groups = sample.semantic_document["groups"]
        assert {group["container"] for group in groups} == {"BUY", "SELL"}
        for group in groups:
            conditions = [
                block
                for block in group["blocks"]
                if block["elementCode"] != "BASIC_EQUAL_ALLOCATION_ORDER"
            ]
            assert len(conditions) >= 2
            assert group["blocks"][-1]["elementCode"] == "BASIC_EQUAL_ALLOCATION_ORDER"
            assert len(group["connections"]) == len(group["blocks"]) - 1
            assert group["instrumentIds"]

        editor = sample.presentation_document["basicEditor"]
        assert sample.presentation_document["localSampleRevision"] == SAMPLE_REVISION
        assert editor["version"] == 1
        snapshot = editor["snapshot"]
        assert snapshot["sections"]
        assert snapshot["cardMeta"]
        assert snapshot["buySettings"]
        assert snapshot["sellSettings"]
        assert snapshot["symbolLimits"]
        for section in snapshot["sections"]:
            assert section["cards"]["buy"]
            assert section["cards"]["sell"]
            assert isinstance(section["cards"]["risk"], list)
            assert section["cardPositions"]


def test_full_catalog_sample_executes_every_block_across_all_four_resolutions() -> None:
    sample = next(
        item
        for item in build_samples(CATALOG_ID, INSTRUMENTS)
        if item.key == "FULL_CATALOG_MIXED_RESOLUTION"
    )
    blocks = [
        block
        for group in sample.semantic_document["groups"]
        for block in group["blocks"]
    ]

    assert {block["elementCode"] for block in blocks} == {
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
        "BASIC_SCHEDULE",
        "BASIC_EQUAL_ALLOCATION_ORDER",
    }
    assert {
        block["parameters"]["resolution"]
        for block in blocks
        if "resolution" in block["parameters"]
    } == {"30m", "1h", "4h", "1d"}
    assert (
        len(
            {group["allocationGroupId"] for group in sample.semantic_document["groups"]}
        )
        == 14
    )


def test_scheduled_flows_round_trip_with_the_editor_execution_mode() -> None:
    for sample in build_samples(CATALOG_ID, INSTRUMENTS):
        scheduled_groups = [
            group
            for group in sample.semantic_document["groups"]
            if any(
                block["elementCode"] == "BASIC_SCHEDULE"
                for block in group["blocks"]
            )
        ]
        for group in scheduled_groups:
            assert group["container"] == "BUY"
            order = group["blocks"][-1]
            assert order["parameters"]["executionMode"] == "주기마다"
            assert (
                sample.presentation_document["basicEditor"]["snapshot"][
                    "buySettings"
                ][group["allocationGroupId"]]["entryMode"]
                == "주기마다"
            )


def test_samples_use_only_catalog_instrument_ids() -> None:
    allowed = set(INSTRUMENTS.values())

    for sample in build_samples(CATALOG_ID, INSTRUMENTS):
        used = {
            instrument_id
            for group in sample.semantic_document["groups"]
            for instrument_id in group["instrumentIds"]
        }
        assert used <= allowed


def test_streak_parameters_use_values_published_by_the_basic_catalog() -> None:
    published_bars = {"2", "3", "5", "10", "20", "30"}

    for sample in build_samples(CATALOG_ID, INSTRUMENTS):
        streaks = [
            block
            for group in sample.semantic_document["groups"]
            for block in group["blocks"]
            if block["elementCode"] == "BASIC_STREAK"
        ]
        assert all(block["parameters"]["bars"] in published_bars for block in streaks)


def test_samples_reject_a_missing_required_symbol() -> None:
    incomplete = dict(INSTRUMENTS)
    incomplete.pop("AAPL")

    try:
        build_samples(CATALOG_ID, incomplete)
    except ValueError as error:
        assert str(error) == "Basic catalog is missing required sample instrument: AAPL"
    else:
        raise AssertionError("missing sample instrument was accepted")


class _RecordingApi:
    def __init__(
        self, existing: bool = False, partial: bool = False, stale: bool = False
    ) -> None:
        self.created: list[str] = []
        self.saved: list[str] = []
        self.validated: list[str] = []
        self.released: list[str] = []
        self.lease_released: list[str] = []
        self.existing = existing
        self.partial = partial
        self.stale = stale

    def get_catalog(self):
        return {
            "version": {"id": CATALOG_ID},
            "instruments": [
                {"id": value, "symbol": symbol} for symbol, value in INSTRUMENTS.items()
            ],
        }

    def list_strategies(self):
        if not self.existing and not self.partial:
            return []
        samples = build_samples(CATALOG_ID, INSTRUMENTS)
        if self.partial:
            return [
                {
                    "id": "partial-0",
                    "kind": "draft",
                    "name": samples[0].name,
                    "description": samples[0].description,
                }
            ]
        return [
            row
            for index, sample in enumerate(samples)
            for row in (
                {"id": f"released-{index}", "kind": "released", "name": sample.name},
                {"id": f"existing-{index}", "kind": "draft", "name": sample.name},
            )
        ]

    def get_document(self, strategy_id: str):
        if strategy_id.startswith("partial"):
            return {
                "editSequence": 0,
                "semanticDocument": {"mode": "BASIC", "groups": []},
                "presentationDocument": {},
            }
        index = int(strategy_id.rsplit("-", 1)[1])
        sample = build_samples(CATALOG_ID, INSTRUMENTS)[index]
        return {
            "presentationDocument": {
                "localSampleKey": sample.key,
                "localSampleRevision": SAMPLE_REVISION - 1
                if self.stale
                else SAMPLE_REVISION,
            }
        }

    def create_strategy(self, sample):
        self.created.append(sample.key)
        return f"created-{len(self.created)}-{sample.key}"

    def acquire_lease(self, strategy_id: str):
        return {"leaseToken": f"lease-{strategy_id}"}

    def save_document(self, strategy_id: str, lease_token: str, sample):
        self.saved.append(strategy_id)
        return {"editSequence": 1}

    def release_lease(self, strategy_id: str, lease_token: str):
        self.lease_released.append(strategy_id)

    def validate_strategy(self, strategy_id: str, catalog_id: str):
        self.validated.append(strategy_id)
        return {"validationRunId": f"validation-{strategy_id}", "status": "VALID"}

    def release_strategy(self, strategy_id: str, validation_id: str):
        self.released.append(strategy_id)
        return {"releaseId": f"release-{strategy_id}", "botId": f"bot-{strategy_id}"}


def test_seed_creates_validates_and_releases_each_new_sample_once() -> None:
    api = _RecordingApi()

    receipts = seed_samples(api)

    assert len(receipts) == 4
    assert len(api.created) == 8
    assert len(api.saved) == 8
    assert len(api.validated) == 8
    assert len(api.released) == 4
    assert api.lease_released == api.saved


def test_seed_keeps_a_separate_editable_copy_after_releasing_each_new_sample() -> None:
    api = _RecordingApi()

    receipts = seed_samples(api)

    assert len(api.created) == 8
    assert len(api.saved) == 8
    assert len(api.validated) == 8
    assert len(api.released) == 4
    assert [receipt["strategyId"] for receipt in receipts] == [
        "created-2-AAPL_MOMENTUM_REVERSAL",
        "created-4-MSFT_STREAK_REVERSAL",
        "created-6-LIQUID_MULTI_ASSET_CYCLE",
        "created-8-FULL_CATALOG_MIXED_RESOLUTION",
    ]


def test_seed_reuses_samples_with_the_same_stable_key() -> None:
    api = _RecordingApi(existing=True)

    receipts = seed_samples(api)

    assert [receipt["status"] for receipt in receipts] == [
        "reused",
        "reused",
        "reused",
        "reused",
    ]
    assert api.created == []
    assert api.saved == []
    assert api.validated == []
    assert api.released == []


def test_seed_updates_an_older_editable_revision_without_releasing_it_again() -> None:
    api = _RecordingApi(existing=True, stale=True)

    receipts = seed_samples(api)

    assert [receipt["status"] for receipt in receipts] == [
        "created",
        "created",
        "created",
        "created",
    ]
    assert api.created == []
    assert api.saved == ["existing-0", "existing-1", "existing-2", "existing-3"]
    assert api.released == []


def test_seed_resumes_an_empty_draft_left_by_an_interrupted_run() -> None:
    api = _RecordingApi(partial=True)

    receipts = seed_samples(api)

    assert receipts[0]["strategyId"] == "created-1-AAPL_MOMENTUM_REVERSAL"
    assert "partial-0" in api.saved
    assert "partial-0" in api.validated
    assert "partial-0" in api.released
    assert api.released[0] == "partial-0"
    assert api.created == [
        "AAPL_MOMENTUM_REVERSAL",
        "MSFT_STREAK_REVERSAL",
        "MSFT_STREAK_REVERSAL",
        "LIQUID_MULTI_ASSET_CYCLE",
        "LIQUID_MULTI_ASSET_CYCLE",
        "FULL_CATALOG_MIXED_RESOLUTION",
        "FULL_CATALOG_MIXED_RESOLUTION",
    ]


def test_http_adapter_sends_release_budget_without_exposing_credentials() -> None:
    calls = []

    def transport(method, url, body, token):
        calls.append((method, url, body, token))
        return {"releaseId": "release-1", "botId": "bot-1"}

    api = LocalSampleApi("http://localhost:15173", "access-token", transport=transport)

    result = api.release_strategy("strategy-1", "validation-1")

    assert result == {"releaseId": "release-1", "botId": "bot-1"}
    assert calls == [
        (
            "POST",
            "http://localhost:15173/api/v1/strategies/strategy-1/releases",
            {
                "validationRunId": "validation-1",
                "initialCashAmount": "100000.00000000",
                "budgetCapBps": 10000,
                "candidateConflictPolicy": {"policy": "FIRST_WINS"},
            },
            "access-token",
        )
    ]
