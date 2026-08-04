data "aws_iam_policy_document" "scheduler_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "trading_scheduler" {
  count              = local.enable_service_stack ? 1 : 0
  name               = "${local.name_prefix}-trading-scheduler"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume.json
}

data "aws_iam_policy_document" "trading_scheduler" {
  count = local.enable_service_stack ? 1 : 0
  statement {
    actions   = ["ec2:StartInstances", "ec2:StopInstances"]
    resources = [aws_instance.trading[0].arn]
  }
}

resource "aws_iam_role_policy" "trading_scheduler" {
  count  = local.enable_service_stack ? 1 : 0
  role   = aws_iam_role.trading_scheduler[0].id
  policy = data.aws_iam_policy_document.trading_scheduler[0].json
}

resource "aws_scheduler_schedule" "trading_start" {
  count = local.enable_service_stack ? 1 : 0

  name                         = "${local.name_prefix}-trading-start"
  schedule_expression          = "cron(0 8 ? * MON-FRI *)"
  schedule_expression_timezone = "America/New_York"
  state                        = "ENABLED"
  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:startInstances"
    role_arn = aws_iam_role.trading_scheduler[0].arn
    input    = jsonencode({ InstanceIds = [aws_instance.trading[0].id] })
    retry_policy {
      maximum_event_age_in_seconds = 3600
      maximum_retry_attempts       = 3
    }
  }
}

resource "aws_scheduler_schedule" "trading_stop" {
  count = local.enable_service_stack ? 1 : 0

  name                         = "${local.name_prefix}-trading-stop"
  schedule_expression          = "cron(0 17 ? * MON-FRI *)"
  schedule_expression_timezone = "America/New_York"
  state                        = "ENABLED"
  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:ec2:stopInstances"
    role_arn = aws_iam_role.trading_scheduler[0].arn
    input    = jsonencode({ InstanceIds = [aws_instance.trading[0].id] })
    retry_policy {
      maximum_event_age_in_seconds = 3600
      maximum_retry_attempts       = 3
    }
  }
}
