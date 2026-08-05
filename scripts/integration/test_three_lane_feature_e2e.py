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
import json
import time
import uuid
from dataclasses import replace
from datetime import timedelta
from pathlib import Path
from typing import Any

import pytest
from backtest_engine.attempt_coordinator import ResourceSample
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
from sqlalchemy import Engine, text
from test_feature_outputs import Source, _parquet, _record

pytestmark = pytest.mark.docker

LANES = (RunLane.BASIC, RunLane.CUSTOM, RunLane.COMPETITION)
MATERIALIZATION_ID = uuid.UUID("00000000-0000-4000-8000-0000000000e1")


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
    body = _parquet()
    s3.put_bucket_versioning(
        Bucket=bucket, VersioningConfiguration={"Status": "Enabled"}
    )
    key = f"issue248/{uuid.uuid4()}/rsi.parquet"
    original = s3.put_object(Bucket=bucket, Key=key, Body=body)
    replacement = s3.put_object(Bucket=bucket, Key=key, Body=b"later-corrupt-revision")
    assert original["VersionId"] != replacement["VersionId"]

    record = _record(body)
    record["id"] = MATERIALIZATION_ID
    # build_stack intentionally uses Backend's published fixture catalog id;
    # bind the materialization to that exact compiled-plan requirement.
    record["feature_definition_id"] = uuid.UUID("00000000-0000-4000-8000-000000000401")
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
    )
    stack.handler._feature_materializations = Source({MATERIALIZATION_ID: record})
    stack.handler._feature_object_reader = S3VersionedFeatureObjectReader(s3)

    accepted = stack.accept()
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
    second = _poll_until_message(workers[RunLane.CUSTOM])
    basic = workers[RunLane.BASIC].poll_once()
    competition = workers[RunLane.COMPETITION].poll_once()
    duplicate = workers[RunLane.COMPETITION].poll_once()

    assert [item.disposition for item in first] == [MessageDisposition.RETURNED], [
        item.reason_code for item in first
    ]
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
