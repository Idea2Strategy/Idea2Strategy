resource "aws_sqs_queue" "dead_letter" {
  for_each = local.work_queues

  name                      = "${each.value.name}-dlq"
  message_retention_seconds = 1209600
  sqs_managed_sse_enabled   = true

  tags = {
    Workload = each.key
    Role     = "dead-letter"
  }
}

resource "aws_sqs_queue" "work" {
  for_each = local.work_queues

  name                       = each.value.name
  visibility_timeout_seconds = each.value.visibility_timeout_seconds
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 20
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dead_letter[each.key].arn
    maxReceiveCount     = var.queue_max_receive_count
  })

  tags = {
    Workload = each.key
    Role     = "work"
  }
}

resource "aws_sqs_queue_redrive_allow_policy" "dead_letter" {
  for_each = local.work_queues

  queue_url = aws_sqs_queue.dead_letter[each.key].id
  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns   = [aws_sqs_queue.work[each.key].arn]
  })
}

resource "aws_ssm_parameter" "queue_url" {
  for_each = local.work_queues

  name  = "${local.parameter_path}/queues/${replace(each.key, "_", "-")}/url"
  type  = "String"
  value = aws_sqs_queue.work[each.key].url
}

resource "aws_ssm_parameter" "queue_dlq_url" {
  for_each = local.work_queues

  name  = "${local.parameter_path}/queues/${replace(each.key, "_", "-")}/dlq-url"
  type  = "String"
  value = aws_sqs_queue.dead_letter[each.key].url
}
