resource "aws_sns_topic" "operations" {
  count = local.enable_service_stack ? 1 : 0

  name              = "${local.name_prefix}-operations"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_sns_topic_subscription" "operations_email" {
  count = local.enable_service_stack && var.operations_alert_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.operations[0].arn
  protocol  = "email"
  endpoint  = var.operations_alert_email
}

resource "aws_budgets_budget" "development" {
  count = local.enable_service_stack ? 1 : 0

  name         = "${local.name_prefix}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "TagKeyValue"
    values = [format("user:Environment$%s", var.environment)]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "FORECASTED"
    subscriber_sns_topic_arns = [aws_sns_topic.operations[0].arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.operations[0].arn]
  }
}
