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

resource "aws_ssm_parameter" "backtest_dlq_url" {
  for_each = local.backtest_lanes

  name  = "${local.parameter_path}/queues/backtest-${each.key}/dlq-url"
  type  = "String"
  value = aws_sqs_queue.backtest_dlq[each.key].url
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

}

resource "aws_sqs_queue" "corporate_action_approval_dlq" {
  count                     = local.enable_service_stack ? 1 : 0
  name                      = "${local.name_prefix}-corporate-action-approval-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true

  tags = { Role = "dead-letter", Workload = "corporate-action-approval" }
}

resource "aws_sqs_queue" "corporate_action_approval" {
  count                      = local.enable_service_stack ? 1 : 0
  name                       = "${local.name_prefix}-corporate-action-approval"
  visibility_timeout_seconds = 900
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 20
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.corporate_action_approval_dlq[0].arn
    maxReceiveCount     = 5
  })

  tags = { Role = "work", Workload = "corporate-action-approval" }
}

resource "aws_sqs_queue_redrive_allow_policy" "corporate_action_approval_dlq" {
  count     = local.enable_service_stack ? 1 : 0
  queue_url = aws_sqs_queue.corporate_action_approval_dlq[0].id
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.corporate_action_approval[0].arn]
  })
}

resource "aws_ssm_parameter" "corporate_action_approval_queue_url" {
  count = local.enable_service_stack ? 1 : 0
  name  = "${local.parameter_path}/queues/corporate-action-approval/url"
  type  = "String"
  value = aws_sqs_queue.corporate_action_approval[0].url
}

resource "aws_ssm_parameter" "corporate_action_approval_dlq_url" {
  count = local.enable_service_stack ? 1 : 0
  name  = "${local.parameter_path}/queues/corporate-action-approval/dlq-url"
  type  = "String"
  value = aws_sqs_queue.corporate_action_approval_dlq[0].url
}

resource "aws_sqs_queue" "room_ledger_opened_dlq" {
  count                     = local.enable_service_stack ? 1 : 0
  name                      = "${local.name_prefix}-room-ledger-opened-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true

  tags = { Role = "dead-letter", Workload = "room-ledger-opened" }
}

resource "aws_sqs_queue" "room_ledger_open_rejected_dlq" {
  count                     = local.enable_service_stack ? 1 : 0
  name                      = "${local.name_prefix}-room-ledger-open-rejected-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true

  tags = { Role = "dead-letter", Workload = "room-ledger-open-rejected" }
}

resource "aws_sqs_queue" "room_ledger_opened" {
  count                      = local.enable_service_stack ? 1 : 0
  name                       = "${local.name_prefix}-room-ledger-opened"
  visibility_timeout_seconds = 180
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 20
  sqs_managed_sse_enabled    = true
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.room_ledger_opened_dlq[0].arn
    maxReceiveCount     = 5
  })
  tags = { Role = "work", Workload = "room-ledger-opened" }
}

resource "aws_sqs_queue" "room_ledger_open_rejected" {
  count                      = local.enable_service_stack ? 1 : 0
  name                       = "${local.name_prefix}-room-ledger-open-rejected"
  visibility_timeout_seconds = 180
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 20
  sqs_managed_sse_enabled    = true
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.room_ledger_open_rejected_dlq[0].arn
    maxReceiveCount     = 5
  })
  tags = { Role = "work", Workload = "room-ledger-open-rejected" }
}

resource "aws_sqs_queue_redrive_allow_policy" "room_ledger_opened_dlq" {
  count     = local.enable_service_stack ? 1 : 0
  queue_url = aws_sqs_queue.room_ledger_opened_dlq[0].id
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.room_ledger_opened[0].arn]
  })
}

resource "aws_sqs_queue_redrive_allow_policy" "room_ledger_open_rejected_dlq" {
  count     = local.enable_service_stack ? 1 : 0
  queue_url = aws_sqs_queue.room_ledger_open_rejected_dlq[0].id
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.room_ledger_open_rejected[0].arn]
  })
}

resource "aws_ssm_parameter" "room_ledger_opened_queue_url" {
  count = local.enable_service_stack ? 1 : 0
  name  = "${local.parameter_path}/queues/room-ledger-opened/url"
  type  = "String"
  value = aws_sqs_queue.room_ledger_opened[0].url
}

resource "aws_ssm_parameter" "room_ledger_rejected_queue_url" {
  count = local.enable_service_stack ? 1 : 0
  name  = "${local.parameter_path}/queues/room-ledger-open-rejected/url"
  type  = "String"
  value = aws_sqs_queue.room_ledger_open_rejected[0].url
}
