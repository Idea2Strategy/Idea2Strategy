resource "aws_cloudwatch_log_group" "service" {
  count = local.enable_service_stack ? 1 : 0

  name              = "/${var.project_name}/${var.environment}/service"
  retention_in_days = var.cloudwatch_log_retention_days
}

resource "aws_cloudwatch_log_group" "batch" {
  name              = "/${var.project_name}/${var.environment}/batch"
  retention_in_days = var.cloudwatch_log_retention_days
}

resource "aws_cloudwatch_log_group" "trading" {
  count = local.enable_service_stack ? 1 : 0

  name              = "/${var.project_name}/${var.environment}/trading"
  retention_in_days = var.cloudwatch_log_retention_days
}

resource "aws_cloudwatch_log_group" "compute" {
  count = local.enable_service_stack ? 1 : 0

  name              = "/${var.project_name}/${var.environment}/compute"
  retention_in_days = var.cloudwatch_log_retention_days
}

resource "aws_cloudwatch_metric_alarm" "service_cpu_high" {
  count = local.enable_service_stack ? 1 : 0

  alarm_name          = "${local.name_prefix}-service-cpu-high"
  alarm_description   = "Service EC2 CPU has exceeded 80 percent for 15 minutes."
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_action_arns

  dimensions = {
    InstanceId = aws_instance.service[0].id
  }
}

resource "aws_cloudwatch_metric_alarm" "batch_cpu_high" {
  alarm_name          = "${local.name_prefix}-batch-cpu-high"
  alarm_description   = "Batch EC2 CPU has exceeded 80 percent for 15 minutes."
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_action_arns

  dimensions = {
    InstanceId = aws_instance.batch.id
  }
}

resource "aws_cloudwatch_metric_alarm" "trading_cpu_high" {
  count = local.enable_service_stack ? 1 : 0

  alarm_name          = "${local.name_prefix}-trading-cpu-high"
  alarm_description   = "Trading EC2 CPU has exceeded 80 percent for 15 minutes."
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_action_arns

  dimensions = {
    InstanceId = aws_instance.trading[0].id
  }
}

resource "aws_cloudwatch_metric_alarm" "compute_cpu_high" {
  count = local.enable_service_stack ? 1 : 0

  alarm_name          = "${local.name_prefix}-compute-cpu-high"
  alarm_description   = "Compute EC2 CPU has exceeded 80 percent for 15 minutes."
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_action_arns

  dimensions = {
    InstanceId = aws_instance.compute[0].id
  }
}

resource "aws_cloudwatch_metric_alarm" "compute_memory_high" {
  count = local.enable_service_stack ? 1 : 0

  alarm_name          = "${local.name_prefix}-compute-memory-high"
  alarm_description   = "Compute EC2 memory has exceeded 80 percent for 5 minutes."
  namespace           = "Idea2Strategy/Development"
  metric_name         = "mem_used_percent"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 5
  threshold           = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_action_arns

  dimensions = {
    InstanceId = aws_instance.compute[0].id
  }
}

resource "aws_cloudwatch_metric_alarm" "queue_oldest_message" {
  for_each = local.work_queues

  alarm_name          = "${each.value.name}-oldest-message"
  alarm_description   = "A durable work item has remained visible for more than 15 minutes."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateAgeOfOldestMessage"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 900
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_action_arns

  dimensions = {
    QueueName = aws_sqs_queue.work[each.key].name
  }
}

resource "aws_cloudwatch_metric_alarm" "queue_dead_letter_visible" {
  for_each = local.work_queues

  alarm_name          = "${each.value.name}-dlq-visible"
  alarm_description   = "A durable work item has reached the dead-letter queue."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_action_arns

  dimensions = {
    QueueName = aws_sqs_queue.dead_letter[each.key].name
  }
}

resource "aws_cloudwatch_metric_alarm" "cache_evictions" {
  count = local.enable_service_stack ? 1 : 0

  alarm_name          = "${local.name_prefix}-cache-evictions"
  alarm_description   = "Valkey evicted one or more keys in the last five minutes."
  namespace           = "AWS/ElastiCache"
  metric_name         = "Evictions"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_action_arns

  dimensions = {
    ReplicationGroupId = aws_elasticache_replication_group.this[0].replication_group_id
  }
}

resource "aws_cloudwatch_metric_alarm" "batch_memory_high" {
  alarm_name          = "${local.name_prefix}-batch-memory-high"
  alarm_description   = "Batch EC2 memory has exceeded 80 percent for 5 minutes."
  namespace           = "Idea2Strategy/Development"
  metric_name         = "mem_used_percent"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 5
  threshold           = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_action_arns

  dimensions = {
    InstanceId = aws_instance.batch.id
  }
}

resource "aws_cloudwatch_metric_alarm" "service_status_check_failed" {
  count = local.enable_service_stack ? 1 : 0

  alarm_name          = "${local.name_prefix}-service-status-check-failed"
  alarm_description   = "Service EC2 has failed an instance or system status check."
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_System"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = concat(local.alarm_action_arns, ["arn:aws:automate:${var.aws_region}:ec2:recover"])

  dimensions = {
    InstanceId = aws_instance.service[0].id
  }
}

resource "aws_cloudwatch_metric_alarm" "batch_status_check_failed" {
  alarm_name          = "${local.name_prefix}-batch-status-check-failed"
  alarm_description   = "Batch EC2 has failed an instance or system status check."
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_System"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = concat(local.alarm_action_arns, ["arn:aws:automate:${var.aws_region}:ec2:recover"])

  dimensions = {
    InstanceId = aws_instance.batch.id
  }
}


resource "aws_cloudwatch_metric_alarm" "trading_status_check_failed" {
  count = local.enable_service_stack ? 1 : 0

  alarm_name          = "${local.name_prefix}-trading-status-check-failed"
  alarm_description   = "Trading EC2 failed an instance or system status check; recover it in place."
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_System"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = concat(local.alarm_action_arns, ["arn:aws:automate:${var.aws_region}:ec2:recover"])

  dimensions = {
    InstanceId = aws_instance.trading[0].id
  }
}


resource "aws_cloudwatch_metric_alarm" "compute_status_check_failed" {
  count = local.enable_service_stack ? 1 : 0

  alarm_name          = "${local.name_prefix}-compute-status-check-failed"
  alarm_description   = "Compute EC2 failed a system status check; recover it in place."
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_System"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = concat(local.alarm_action_arns, ["arn:aws:automate:${var.aws_region}:ec2:recover"])

  dimensions = {
    InstanceId = aws_instance.compute[0].id
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${local.name_prefix}-rds-cpu-high"
  alarm_description   = "Development RDS CPU has exceeded 80 percent for 15 minutes."
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_action_arns

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.this.identifier
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_target" {
  count = local.enable_service_stack ? 1 : 0

  alarm_name          = "${local.name_prefix}-alb-unhealthy-target"
  alarm_description   = "The service target is unhealthy behind the Development ALB."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_action_arns

  dimensions = {
    LoadBalancer = aws_lb.this[0].arn_suffix
    TargetGroup  = aws_lb_target_group.service[0].arn_suffix
  }
}
