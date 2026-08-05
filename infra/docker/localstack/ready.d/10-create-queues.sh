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
