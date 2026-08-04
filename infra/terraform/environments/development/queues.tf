resource "aws_sqs_queue" "backtest_dlq" {
  for_each = local.backtest_lanes

  name                      = "${local.name_prefix}-backtest-${each.key}-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true

  tags = { Lane = each.key, Role = "dead-letter" }
}

resource "aws_sqs_queue" "backtest" {
  for_each = local.backtest_lanes

  name                       = "${local.name_prefix}-backtest-${each.key}"
  visibility_timeout_seconds = var.queue_visibility_timeout_seconds
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 20
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.backtest_dlq[each.key].arn
    maxReceiveCount     = var.queue_max_receive_count
  })

  tags = { Lane = each.key, Role = "work" }
}

resource "aws_sqs_queue_redrive_allow_policy" "backtest_dlq" {
  for_each = local.backtest_lanes

  queue_url = aws_sqs_queue.backtest_dlq[each.key].id
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.backtest[each.key].arn]
  })
}

resource "aws_ssm_parameter" "backtest_queue_url" {
  for_each = local.backtest_lanes

  name  = "${local.parameter_path}/queues/backtest-${each.key}/url"
  type  = "String"
  value = aws_sqs_queue.backtest[each.key].url
}

resource "aws_ssm_parameter" "backtest_lane_concurrency" {
  for_each = local.backtest_lanes

  name  = "${local.parameter_path}/backtest/lanes/${each.key}/max-concurrency"
  type  = "String"
  value = each.key == "basic" ? "2" : "1"
}

resource "aws_ssm_parameter" "backtest_total_concurrency" {
  count = local.enable_service_stack ? 1 : 0
  name  = "${local.parameter_path}/backtest/max-total-concurrency"
  type  = "String"
  value = "4"

  lifecycle {
    precondition {
      condition     = var.backtest_idle_grace_minutes >= 15
      error_message = "Backtest scale-down requires an idle grace period of at least 15 minutes."
    }
  }
}
