resource "aws_cloudwatch_log_group" "service" {
  count             = local.enable_service_stack ? 1 : 0
  name              = "/${var.project_name}/${var.environment}/core"
  retention_in_days = var.cloudwatch_log_retention_days
}

resource "aws_cloudwatch_log_group" "trading" {
  count             = local.enable_service_stack ? 1 : 0
  name              = "/${var.project_name}/${var.environment}/trading"
  retention_in_days = var.cloudwatch_log_retention_days
}

resource "aws_cloudwatch_log_group" "compute" {
  count             = local.enable_service_stack ? 1 : 0
  name              = "/${var.project_name}/${var.environment}/backtest"
  retention_in_days = var.cloudwatch_log_retention_days
}

# Preserve historical bootstrap logs while the stopped legacy host is retired
# through a separately reviewed, snapshot-first operation.
resource "aws_cloudwatch_log_group" "batch" {
  name              = "/${var.project_name}/${var.environment}/batch"
  retention_in_days = var.cloudwatch_log_retention_days
}

resource "aws_cloudwatch_metric_alarm" "runtime_cpu_high" {
  for_each = local.enable_service_stack ? {
    core    = aws_instance.service[0].id
    trading = aws_instance.trading[0].id
  } : {}

  alarm_name          = "${local.name_prefix}-${each.key}-cpu-high"
  alarm_description   = "${each.key} CPU exceeded 80 percent for 15 minutes"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_action_arns
  dimensions          = { InstanceId = each.value }
}

resource "aws_cloudwatch_metric_alarm" "runtime_memory_high" {
  for_each = local.enable_service_stack ? {
    core    = aws_instance.service[0].id
    trading = aws_instance.trading[0].id
  } : {}

  alarm_name          = "${local.name_prefix}-${each.key}-memory-high"
  alarm_description   = "${each.key} memory exceeded 70 percent for 5 minutes"
  namespace           = "Idea2Strategy/Development"
  metric_name         = "mem_used_percent"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  threshold           = 70
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_action_arns
  dimensions          = { InstanceId = each.value }
}

resource "aws_cloudwatch_metric_alarm" "runtime_container_unhealthy" {
  for_each = local.enable_service_stack ? {
    core     = { InstanceId = aws_instance.service[0].id }
    trading  = { InstanceId = aws_instance.trading[0].id }
    backtest = { AutoScalingGroupName = aws_autoscaling_group.backtest[0].name }
  } : {}

  alarm_name          = "${local.name_prefix}-${each.key}-container-unhealthy"
  alarm_description   = "${each.key} has a missing, stopped, starting beyond bootstrap, or unhealthy required container"
  namespace           = "Idea2Strategy/Development"
  metric_name         = "RuntimeUnhealthyContainerCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_action_arns
  dimensions          = each.value
}

resource "aws_cloudwatch_metric_alarm" "runtime_container_restart" {
  for_each = local.enable_service_stack ? {
    core     = { InstanceId = aws_instance.service[0].id }
    trading  = { InstanceId = aws_instance.trading[0].id }
    backtest = { AutoScalingGroupName = aws_autoscaling_group.backtest[0].name }
  } : {}

  alarm_name          = "${local.name_prefix}-${each.key}-container-restart"
  alarm_description   = "${each.key} restarted one or more required containers during the last observation interval"
  namespace           = "Idea2Strategy/Development"
  metric_name         = "RuntimeRestartDelta"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_action_arns
  dimensions          = each.value
}

resource "aws_cloudwatch_metric_alarm" "core_runtime_heartbeat_missing" {
  count = local.enable_service_stack ? 1 : 0

  alarm_name          = "${local.name_prefix}-core-runtime-heartbeat-missing"
  alarm_description   = "The always-on Core host stopped reporting its container observer heartbeat"
  namespace           = "Idea2Strategy/Development"
  metric_name         = "RuntimeObserverHeartbeat"
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = local.alarm_action_arns
  dimensions          = { InstanceId = aws_instance.service[0].id }
}

resource "aws_cloudwatch_metric_alarm" "core_status_check_failed" {
  count = local.enable_service_stack ? 1 : 0

  alarm_name          = "${local.name_prefix}-core-status-check-failed"
  alarm_description   = "The always-on Core EC2 instance failed an AWS system or instance status check"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_action_arns
  dimensions          = { InstanceId = aws_instance.service[0].id }
}

resource "aws_cloudwatch_metric_alarm" "backtest_cpu_high" {
  count = local.enable_service_stack ? 1 : 0

  alarm_name          = "${local.name_prefix}-backtest-cpu-high"
  alarm_description   = "Backtest CPU exceeded 80 percent for 15 minutes; review t4g.medium sizing and queue latency"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_action_arns
  dimensions          = { AutoScalingGroupName = aws_autoscaling_group.backtest[0].name }
}

resource "aws_cloudwatch_metric_alarm" "backtest_cpu_credit_low" {
  count = local.enable_service_stack ? 1 : 0

  alarm_name          = "${local.name_prefix}-backtest-cpu-credit-low"
  alarm_description   = "Backtest t4g.medium CPU credits fell below 20; inspect throttling before increasing instance size"
  namespace           = "AWS/EC2"
  metric_name         = "CPUCreditBalance"
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 20
  comparison_operator = "LessThanOrEqualToThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_action_arns
  dimensions          = { AutoScalingGroupName = aws_autoscaling_group.backtest[0].name }
}

resource "aws_cloudwatch_metric_alarm" "backtest_memory_high" {
  count = local.enable_service_stack ? 1 : 0

  alarm_name          = "${local.name_prefix}-backtest-memory-high"
  alarm_description   = "Backtest memory exceeded 80 percent for 5 minutes; inspect concurrency and t4g.medium sizing"
  namespace           = "Idea2Strategy/Development"
  metric_name         = "mem_used_percent"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 5
  threshold           = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_action_arns
  dimensions          = { AutoScalingGroupName = aws_autoscaling_group.backtest[0].name }
}

resource "aws_cloudwatch_metric_alarm" "queue_oldest_message" {
  for_each = local.backtest_lanes

  alarm_name          = "${local.name_prefix}-backtest-${each.key}-oldest"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateAgeOfOldestMessage"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = each.key == "competition" ? 300 : 900
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_action_arns
  dimensions          = { QueueName = aws_sqs_queue.backtest[each.key].name }
}

resource "aws_cloudwatch_metric_alarm" "queue_dead_letter_visible" {
  for_each = local.backtest_lanes

  alarm_name          = "${local.name_prefix}-backtest-${each.key}-dlq"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_action_arns
  dimensions          = { QueueName = aws_sqs_queue.backtest_dlq[each.key].name }
}

resource "aws_cloudwatch_metric_alarm" "pipeline_dead_letter_visible" {
  count = local.enable_service_stack ? 1 : 0

  alarm_name          = "${local.name_prefix}-pipeline-dlq"
  alarm_description   = "Pipeline corporate-action or feature work reached the dead-letter queue"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_action_arns
  dimensions          = { QueueName = aws_sqs_queue.corporate_action_approval_dlq[0].name }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${local.name_prefix}-rds-cpu-high"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_action_arns
  dimensions          = { DBInstanceIdentifier = aws_db_instance.this.identifier }
}

resource "aws_cloudwatch_metric_alarm" "rds_storage_low" {
  alarm_name          = "${local.name_prefix}-rds-storage-low"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 3
  threshold           = 5368709120
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_action_arns
  dimensions          = { DBInstanceIdentifier = aws_db_instance.this.identifier }
}
