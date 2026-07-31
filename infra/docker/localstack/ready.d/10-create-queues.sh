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
