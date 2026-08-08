#!/bin/sh
set -eu

create_queue() {
  queue_name="$1"
  awslocal sqs create-queue --queue-name "${queue_name}-dlq" >/dev/null
  dlq_url="$(awslocal sqs get-queue-url --queue-name "${queue_name}-dlq" --query QueueUrl --output text)"
  dlq_arn="$(awslocal sqs get-queue-attributes --queue-url "${dlq_url}" --attribute-names QueueArn --query Attributes.QueueArn --output text)"
  awslocal sqs create-queue \
    --queue-name "${queue_name}" \
    --attributes "{\"RedrivePolicy\":\"{\\\"deadLetterTargetArn\\\":\\\"${dlq_arn}\\\",\\\"maxReceiveCount\\\":\\\"5\\\"}\"}" \
    >/dev/null
}

create_queue "bot-commands"
create_queue "backtest-jobs"
create_queue "pipeline-jobs"
create_queue "domain-events"

# B's official backtest requests get their own queue rather than sharing
# backtest-jobs. That queue carries D's own job messages, and a single queue
# holding two contracts would force each consumer to parse the other's — D's
# release intake says exactly that about its own.
create_queue "official-backtest-requests"

# Backtest execution jobs and provider request envelopes are separate trust
# boundaries. The worker additionally reserves independent 2/1/1 execution
# lanes, matching the deployment scheduler rather than silently serializing all
# work through the legacy backtest-jobs queue.
create_queue "backtest-basic"
create_queue "backtest-custom"
create_queue "backtest-competition"
create_queue "backtest-basic-request"
create_queue "backtest-custom-request"
create_queue "backtest-competition-request"

# 방 원장 흐름. backend 가 요청을 operations.outbox_messages 에 쓰고, trading 의 poller 가
# 같은 테이블을 DB 로 읽어 계좌를 열고 결과를 다시 그 테이블에 쓴다. 두 서비스가 한 DB 를
# 공유하므로 backend 의 relay 가 그 결과 행을 아래 큐로 내보내고, backend 의 결과 소비자가
# 되받아 방에 적용한다. 결과 소비자는 opened 와 rejected 두 URL 이 모두 있어야 기동한다.
create_queue "room-ledger-open-request"
create_queue "room-ledger-opened"
create_queue "room-ledger-rejected"

# 기업행사 승인 결정이 파이프라인으로 넘어가는 경로. backend 의 relay 가 매핑하고 있으나
# 큐가 없으면 빈 URL 로 남아 조용히 아무것도 발행하지 않는다.
create_queue "corporate-action-approval"
