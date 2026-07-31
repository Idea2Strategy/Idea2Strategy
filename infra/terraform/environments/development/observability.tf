resource "aws_cloudwatch_log_group" "service" {
  count = local.enable_service_stack ? 1 : 0

  name              = "/${var.project_name}/${var.environment}/service"
  retention_in_days = var.cloudwatch_log_retention_days
}

resource "aws_cloudwatch_log_group" "batch" {
  name              = "/${var.project_name}/${var.environment}/batch"
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

  dimensions = {
    InstanceId = aws_instance.batch.id
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

  dimensions = {
    InstanceId = aws_instance.batch.id
  }
}

resource "aws_cloudwatch_metric_alarm" "service_status_check_failed" {
  count = local.enable_service_stack ? 1 : 0

  alarm_name          = "${local.name_prefix}-service-status-check-failed"
  alarm_description   = "Service EC2 has failed an instance or system status check."
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"

  dimensions = {
    InstanceId = aws_instance.service[0].id
  }
}

resource "aws_cloudwatch_metric_alarm" "batch_status_check_failed" {
  alarm_name          = "${local.name_prefix}-batch-status-check-failed"
  alarm_description   = "Batch EC2 has failed an instance or system status check."
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"

  dimensions = {
    InstanceId = aws_instance.batch.id
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

  dimensions = {
    LoadBalancer = aws_lb.this[0].arn_suffix
    TargetGroup  = aws_lb_target_group.service[0].arn_suffix
  }
}
