"""Root #248: feature-bearing BASIC/CUSTOM/COMPETITION shared-runtime proof.

This is intentionally a release integration harness, not a second implementation:
it wires the pinned service's production persistence, worker, S3 version reader,
result HTTP endpoint and execution engine to one PostgreSQL 16, one LocalStack S3
bucket and three LocalStack SQS lanes.  Test-only arrangement creates the two runs
that Backend normally creates before publishing CUSTOM/COMPETITION messages; no
success response or result is synthesized by this suite.
"""

from __future__ import annotations

import copy
import hashlib
import json
import time
import uuid
from dataclasses import replace
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

import pyarrow as pa
import pyarrow.parquet as pq
import pytest
from backtest_engine.attempt_coordinator import ResourceSample
from backtest_engine.contracts import compute_compiled_plan_checksum
from backtest_engine.persistence import (
    BacktestPersistence,
    RunLane,
    RunStatus,
)
from backtest_engine.production import S3VersionedFeatureObjectReader
from backtest_engine.wiring import PersistenceExecutionKeyStore
from backtest_engine.worker import (
    BacktestWorker,
    MessageDisposition,
    WorkerConfig,
)
from d_integration_stack import ScriptedMonitor, build_stack, sql_all, sql_one
from d_reproducibility_testkit import (
    DATASET_MANIFEST_ID,
    FIRST_BAR_START,
    bar_rows,
    compiled_plan,
    dataset_manifest,
    market_bars_parquet,
    official_backtest_request,
)
from sqlalchemy import Engine, text
from test_feature_outputs import INPUT_HASH, INSTRUMENT_ID, Source, _parquet, _record

pytestmark = pytest.mark.docker

LANES = (RunLane.BASIC, RunLane.CUSTOM, RunLane.COMPETITION)
MATERIALIZATION_ID = uuid.UUID("00000000-0000-4000-8000-0000000000e1")
RSI_30M_DEFINITION_ID = "4b1c6801-0259-5176-a857-0e5ea923d898"
RSI_30M_DEFINITION_HASH = (
    "363f534dc77c6af0ebfe58f35be4fd2aa208906b1eaa36b550b17e9acb8692e4"
)
RSI_30M_FEED_ID = uuid.UUID("57794d8c-2254-53e4-966e-44f97edd9e6a")
RSI_30M_FEED_CODE = "FEATURE_RSI_14_30M_RSI_1_0_0"


def _production_plan() -> dict[str, Any]:
    plan = copy.deepcopy(compiled_plan())
    plan["elementCatalogVersion"] = "basic-elements:2026-08-25"
    requirement = plan["requiredFeatures"][0]
    requirement.update(
        {
            "requirementId": "rsi-14-pt30m",
            "featureId": RSI_30M_DEFINITION_ID,
            "resolution": "PT30M",
        }
    )
    plan["steps"] = [
        {
            "sequence": 1,
            "operation": "RSI_CROSS",
            "arguments": {
                "resolution": "30m",
                "direction": "UP",
                "period": "14",
                "threshold": "30",
            },
        },
        {
            "sequence": 2,
            "operation": "EMIT_ORDER_CANDIDATE",
            "arguments": {
                "allocation": "EQUAL",
                "orderType": "MARKET",
                "timeInForce": "DAY",
                "side": "BUY",
                "orderPercent": "100",
                "maxPositionPercent": "40",
                "executionMode": "1회만",
                "waitMode": "조건 재충족",
                "waitInterval": "1",
                "maxExecutions": "1",
            },
        },
    ]
    plan["planChecksum"] = compute_compiled_plan_checksum(plan)
    return plan


def _production_bar_starts() -> tuple[datetime, ...]:
    next_session = FIRST_BAR_START + timedelta(days=1)
    return tuple(
        [FIRST_BAR_START + timedelta(minutes=30 * index) for index in range(13)]
        + [next_session + timedelta(minutes=30 * index) for index in range(7)]
    )


def _production_market_data() -> tuple[bytes, dict[str, Any]]:
    rows = bar_rows()
    starts = _production_bar_starts()
    for row, starts_at in zip(rows, starts, strict=True):
        row["bar_start_at"] = starts_at
        row["session_date_et"] = starts_at.date()
    schema = pq.read_table(pa.BufferReader(market_bars_parquet())).schema
    table = pa.Table.from_pylist(rows, schema=schema)
    sink = pa.BufferOutputStream()
    pq.write_table(
        table,
        sink,
        compression="none",
        use_dictionary=False,
        write_statistics=True,
        version="2.6",
        data_page_version="2.0",
        row_group_size=len(rows),
    )
    body = bytes(sink.getvalue().to_pybytes())
    manifest = dataset_manifest(
        hashlib.sha256(body).hexdigest(),
        row_count=len(rows),
        coverage_end=starts[-1] + timedelta(minutes=30),
    )
    return body, manifest


def _production_feature_rows() -> list[dict[str, str]]:
    starts = _production_bar_starts()
    values = (
        "0.00000000",
        "68.18181818",
        "70.45454545",
        "72.72727273",
        "75.00000000",
        "77.27272727",
    )
    return [
        {
            "at": starts_at.astimezone(UTC).isoformat().replace("+00:00", "Z"),
            "value": value,
        }
        for starts_at, value in zip(starts[14:], values, strict=True)
    ]


def _production_feature_result_hash(rows: list[dict[str, str]]) -> str:
    starts = _production_bar_starts()
    payload = {
        "definition_hash": RSI_30M_DEFINITION_HASH,
        "input_dataset_set_hash": INPUT_HASH,
        "instrument_id": INSTRUMENT_ID,
        "period_end": (starts[-1] + timedelta(minutes=30))
        .astimezone(UTC)
        .isoformat()
        .replace("+00:00", "Z"),
        "period_start": starts[0].astimezone(UTC).isoformat().replace("+00:00", "Z"),
        "result_schema_version": 1,
        "rows": rows,
    }
    encoded = json.dumps(
        payload,
        sort_keys=True,
        ensure_ascii=False,
        separators=(",", ":"),
        allow_nan=False,
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _queues(sqs: Any) -> dict[RunLane, tuple[str, str]]:
    result: dict[RunLane, tuple[str, str]] = {}
    suffix = uuid.uuid4().hex[:10]
    for lane in LANES:
        name = lane.value.lower()
        main = sqs.create_queue(
            QueueName=f"issue248-{name}-{suffix}",
            Attributes={
                "VisibilityTimeout": "30",
                "ReceiveMessageWaitTimeSeconds": "0",
            },
        )["QueueUrl"]
        dead = sqs.create_queue(QueueName=f"issue248-{name}-dlq-{suffix}")["QueueUrl"]
        result[lane] = (main, dead)
    return result


def _visible(sqs: Any, queue: str) -> int:
    attributes = sqs.get_queue_attributes(
        QueueUrl=queue,
        AttributeNames=[
            "ApproximateNumberOfMessages",
            "ApproximateNumberOfMessagesNotVisible",
        ],
    )["Attributes"]
    return int(attributes["ApproximateNumberOfMessages"])


def _worker(
    *,
    lane: RunLane,
    sqs: Any,
    queues: dict[RunLane, tuple[str, str]],
    handler: Any,
    persistence: BacktestPersistence,
) -> BacktestWorker:
    main, dead = queues[lane]
    return BacktestWorker(
        client=sqs,
        config=WorkerConfig(
            queue_url=main,
            dead_letter_queue_url=dead,
            worker_id=f"issue248-{lane.value.lower()}",
            max_receive_count=3,
            visibility_timeout=timedelta(seconds=30),
            wait_time=timedelta(0),
            max_messages=1,
            heartbeat_interval=timedelta(seconds=10),
        ),
        handler=handler,
        store=PersistenceExecutionKeyStore(persistence),
    )


def _poll_until_message(worker: BacktestWorker) -> tuple[Any, ...]:
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        handled = worker.poll_once()
        if handled:
            return handled
        time.sleep(0.1)
    raise AssertionError(
        "the LocalStack redelivery did not become visible within 5 seconds"
    )


def _receive_until_message(sqs: Any, queue: str) -> dict[str, Any]:
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        messages = sqs.receive_message(
            QueueUrl=queue,
            MaxNumberOfMessages=1,
            WaitTimeSeconds=0,
            VisibilityTimeout=30,
            MessageSystemAttributeNames=["ApproximateReceiveCount"],
            MessageAttributeNames=["All"],
        ).get("Messages", [])
        if messages:
            return messages[0]
        time.sleep(0.1)
    raise AssertionError(
        "the LocalStack message did not become visible within 5 seconds"
    )


def _clone_run(
    persistence: BacktestPersistence,
    *,
    source_run_id: uuid.UUID,
    lane: RunLane,
) -> tuple[uuid.UUID, uuid.UUID]:
    """Arrange the provider-owned durable rows that authorize one lane job."""

    run_id = uuid.uuid4()
    bundle_id = uuid.uuid4()
    with persistence.unit_of_work() as uow:
        source = uow.runs.get(source_run_id)
        source_pin = uow.pins.get(source_run_id)
        source_bundle = uow.inputs.get_by_run(source_run_id)
        uow.runs.accept(
            replace(
                source,
                id=run_id,
                lane=lane,
                status=RunStatus.QUEUED,
                started_at=None,
                completed_at=None,
                failure_code=None,
                result_hash=None,
                result_manifest_id=None,
                retryable=None,
                missing_requirements=None,
                message_id=uuid.uuid4(),
                idempotency_key=f"ISSUE248:{lane.value}:{run_id}",
                idempotency_scope=str(run_id),
            )
        )
        uow.inputs.lock(
            replace(source_bundle, id=bundle_id, run_id=run_id),
            datasets=tuple(
                replace(dataset, input_bundle_id=bundle_id)
                for dataset in uow.inputs.datasets_for(source_bundle.id)
            ),
        )
        uow.pins.pin(
            replace(
                source_pin,
                run_id=run_id,
                input_bundle_id=bundle_id,
            )
        )
    return run_id, bundle_id


def _job_for(
    template: dict[str, Any],
    *,
    run_id: uuid.UUID,
    bundle_id: uuid.UUID,
    feature_id: uuid.UUID = MATERIALIZATION_ID,
    locked_hash: str,
) -> dict[str, Any]:
    job = copy.deepcopy(template)
    job.update(
        {
            "backtestRunId": str(run_id),
            "inputBundleId": str(bundle_id),
            "idempotencyKey": f"ISSUE248:{run_id}",
            "featureMaterializations": [
                {
                    "featureMaterializationId": str(feature_id),
                    "lockedResultHash": locked_hash,
                }
            ],
        }
    )
    return job


def _send(sqs: Any, queue: str, job: dict[str, Any], lane: RunLane) -> None:
    sqs.send_message(
        QueueUrl=queue,
        MessageBody=json.dumps(job, sort_keys=True, separators=(",", ":")),
        MessageAttributes={
            "BacktestLane": {"DataType": "String", "StringValue": lane.value},
            "BacktestRunId": {
                "DataType": "String",
                "StringValue": job["backtestRunId"],
            },
        },
    )


def test_three_feature_lanes_reach_results_with_shared_retry_dedup_and_fail_closed(
    persistence: BacktestPersistence,
    admin_engine: Engine,
    sqs: Any,
    s3: Any,
    bucket: str,
    tmp_path: Path,
) -> None:
    queues = _queues(sqs)
    plan = _production_plan()
    market_body, manifest = _production_market_data()
    feature_rows = _production_feature_rows()
    body = _parquet(feature_rows)
    s3.put_bucket_versioning(
        Bucket=bucket, VersioningConfiguration={"Status": "Enabled"}
    )
    key = f"issue248/{uuid.uuid4()}/rsi.parquet"
    original = s3.put_object(Bucket=bucket, Key=key, Body=body)
    replacement = s3.put_object(Bucket=bucket, Key=key, Body=b"later-corrupt-revision")
    assert original["VersionId"] != replacement["VersionId"]

    record = _record(
        body,
        id=MATERIALIZATION_ID,
        feature_definition_id=uuid.UUID(RSI_30M_DEFINITION_ID),
        resolution="30m",
        definition_hash=RSI_30M_DEFINITION_HASH,
        period_start=_production_bar_starts()[0],
        period_end=_production_bar_starts()[-1] + timedelta(minutes=30),
        output_dataset_feed_id=RSI_30M_FEED_ID,
        output_feed_code=RSI_30M_FEED_CODE,
        output_feed_resolution="30m",
        output_dataset_resolution="30m",
        result_hash=_production_feature_result_hash(feature_rows),
    )
    record["objects"] = (
        {
            **record["objects"][0],
            "bucket_name": bucket,
            "object_key": key,
            "provider_version_id": original["VersionId"],
        },
    )
    locked_hash = "sha256:" + str(record["result_hash"])

    # The first execution is deliberately over budget. Its real SQS message is
    # returned and then succeeds on redelivery; the other lanes share the same
    # handler, database and bucket.
    monitor = ScriptedMonitor(
        ResourceSample(timedelta(minutes=5, microseconds=1), 64 * 1024 * 1024)
    )
    stack = build_stack(
        persistence=persistence,
        sqs_client=sqs,
        s3_client=s3,
        queues=queues[RunLane.BASIC],
        bucket=bucket,
        root=tmp_path / "market-data",
        monitor=monitor,
        plans={plan["planChecksum"]: plan},
        manifests={DATASET_MANIFEST_ID: manifest},
        request=official_backtest_request(plan=plan),
    )
    stack.market_data.path.write_bytes(market_body)
    stack.handler._feature_materializations = Source({MATERIALIZATION_ID: record})
    stack.handler._feature_object_reader = S3VersionedFeatureObjectReader(s3)

    accepted = stack.accept(compiledPlan=plan)
    assert accepted.status_code == 202, accepted.text
    basic_run = uuid.UUID(accepted.json()["run"]["backtestRunId"])
    received = sqs.receive_message(
        QueueUrl=queues[RunLane.BASIC][0],
        MaxNumberOfMessages=1,
        WaitTimeSeconds=0,
        MessageAttributeNames=["All"],
    )["Messages"][0]
    template = json.loads(received["Body"])
    sqs.delete_message(
        QueueUrl=queues[RunLane.BASIC][0], ReceiptHandle=received["ReceiptHandle"]
    )
    with persistence.unit_of_work() as uow:
        basic_bundle = uow.pins.get(basic_run).input_bundle_id

    custom_run, custom_bundle = _clone_run(
        persistence, source_run_id=basic_run, lane=RunLane.CUSTOM
    )
    competition_run, competition_bundle = _clone_run(
        persistence, source_run_id=basic_run, lane=RunLane.COMPETITION
    )
    jobs = {
        RunLane.BASIC: _job_for(
            template,
            run_id=basic_run,
            bundle_id=basic_bundle,
            locked_hash=locked_hash,
        ),
        RunLane.CUSTOM: _job_for(
            template,
            run_id=custom_run,
            bundle_id=custom_bundle,
            locked_hash=locked_hash,
        ),
        RunLane.COMPETITION: _job_for(
            template,
            run_id=competition_run,
            bundle_id=competition_bundle,
            locked_hash=locked_hash,
        ),
    }
    for lane in LANES:
        _send(sqs, queues[lane][0], jobs[lane], lane)
    # Standard SQS duplicate: it must not create a second attempt/result.
    _send(
        sqs,
        queues[RunLane.COMPETITION][0],
        jobs[RunLane.COMPETITION],
        RunLane.COMPETITION,
    )

    workers = {
        lane: _worker(
            lane=lane,
            sqs=sqs,
            queues=queues,
            handler=stack.handler,
            persistence=persistence,
        )
        for lane in LANES
    }

    # Deliberately process out of producer order. CUSTOM is returned once by the
    # resource policy and then succeeds on its real redelivery.
    first = _poll_until_message(workers[RunLane.CUSTOM])
    assert [item.disposition for item in first] == [MessageDisposition.RETURNED], [
        item.reason_code for item in first
    ]
    second = _poll_until_message(workers[RunLane.CUSTOM])
    basic = workers[RunLane.BASIC].poll_once()
    competition = workers[RunLane.COMPETITION].poll_once()
    duplicate = workers[RunLane.COMPETITION].poll_once()

    assert [item.disposition for item in second] == [MessageDisposition.DELETED]
    assert [item.disposition for item in basic] == [MessageDisposition.DELETED]
    assert [item.disposition for item in competition] == [MessageDisposition.DELETED]
    assert [item.disposition for item in duplicate] == [MessageDisposition.DELETED]

    run_ids = [basic_run, custom_run, competition_run]
    rows = sql_all(
        admin_engine,
        "SELECT id, lane::text AS lane, status::text AS status, result_hash "
        "FROM backtest.runs WHERE id = ANY(:ids) ORDER BY lane",
        ids=run_ids,
    )
    assert {row["lane"] for row in rows} == {lane.value for lane in LANES}
    assert {row["status"] for row in rows} == {"COMPLETED"}
    assert all(row["result_hash"] for row in rows)
    attempts = sql_all(
        admin_engine,
        "SELECT run_id, attempt_number, status::text AS status FROM backtest.run_attempts "
        "WHERE run_id = ANY(:ids) ORDER BY run_id, attempt_number",
        ids=run_ids,
    )
    assert len(attempts) == 4  # CUSTOM retry + one attempt in the other two lanes.
    assert sum(row["status"] == "SUCCEEDED" for row in attempts) == 3
    assert sum(row["status"] == "FAILED" for row in attempts) == 1
    assert all(_visible(sqs, queues[lane][0]) == 0 for lane in LANES)
    assert all(_visible(sqs, queues[lane][1]) == 0 for lane in LANES)

    pins = sql_all(
        admin_engine,
        "SELECT b.run_id, f.feature_materialization_id, f.locked_result_hash "
        "FROM backtest.input_bundles b JOIN backtest.input_feature_materializations f "
        "ON f.input_bundle_id = b.id WHERE b.run_id = ANY(:ids)",
        ids=run_ids,
    )
    assert len(pins) == 3
    assert {row["feature_materialization_id"] for row in pins} == {MATERIALIZATION_ID}
    assert {row["locked_result_hash"] for row in pins} == {locked_hash}

    # A new run points at the overwritten (wrong) object version while claiming
    # the original bytes. Production binding must fail before execution/result.
    failed_run, failed_bundle = _clone_run(
        persistence, source_run_id=basic_run, lane=RunLane.CUSTOM
    )
    bad_id = uuid.uuid4()
    bad_record = copy.deepcopy(record)
    bad_record["id"] = bad_id
    bad_record["objects"] = (
        {**bad_record["objects"][0], "provider_version_id": replacement["VersionId"]},
    )
    stack.handler._feature_materializations.records[bad_id] = bad_record
    bad_job = _job_for(
        template,
        run_id=failed_run,
        bundle_id=failed_bundle,
        feature_id=bad_id,
        locked_hash=locked_hash,
    )
    _send(sqs, queues[RunLane.CUSTOM][0], bad_job, RunLane.CUSTOM)
    bad_message = _receive_until_message(sqs, queues[RunLane.CUSTOM][0])
    failed = workers[RunLane.CUSTOM].handle_message(bad_message)
    assert failed.disposition is MessageDisposition.DEAD_LETTERED
    assert failed.reason_code == "REQUIRED_INPUT_UNAVAILABLE"
    failed_row = sql_one(
        admin_engine,
        "SELECT status::text AS status FROM backtest.runs WHERE id = :id",
        id=failed_run,
    )
    assert failed_row["status"] != "COMPLETED"
    with admin_engine.connect() as connection:
        assert (
            connection.execute(
                text(
                    "SELECT count(*) FROM backtest.performance_summaries WHERE run_id = :id"
                ),
                {"id": failed_run},
            ).scalar_one()
            == 0
        )
    assert _visible(sqs, queues[RunLane.CUSTOM][1]) == 1
