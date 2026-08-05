resource "aws_ecs_cluster" "pipeline" {
  count = local.enable_service_stack ? 1 : 0
  name  = "${local.name_prefix}-pipeline"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_cloudwatch_log_group" "pipeline" {
  count             = local.enable_service_stack ? 1 : 0
  name              = "/${var.project_name}/${var.environment}/pipeline"
  retention_in_days = var.cloudwatch_log_retention_days
}

data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "pipeline_execution" {
  count              = local.enable_service_stack ? 1 : 0
  name               = "${local.name_prefix}-pipeline-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

resource "aws_iam_role_policy_attachment" "pipeline_execution" {
  count      = local.enable_service_stack ? 1 : 0
  role       = aws_iam_role.pipeline_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "pipeline_execution_secrets" {
  count = local.enable_service_stack ? 1 : 0
  statement {
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      data.aws_secretsmanager_secret.alpaca_api_key[0].arn,
      data.aws_secretsmanager_secret.alpaca_secret_key[0].arn,
      aws_secretsmanager_secret.runtime_database["pipeline"].arn
    ]
  }
}

resource "aws_iam_role_policy" "pipeline_execution_secrets" {
  count  = local.enable_service_stack ? 1 : 0
  role   = aws_iam_role.pipeline_execution[0].id
  policy = data.aws_iam_policy_document.pipeline_execution_secrets[0].json
}

resource "aws_iam_role" "pipeline_task" {
  count              = local.enable_service_stack ? 1 : 0
  name               = "${local.name_prefix}-pipeline-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

data "aws_iam_policy_document" "pipeline_task" {
  count = local.enable_service_stack ? 1 : 0
  statement {
    actions = ["s3:GetObject", "s3:PutObject", "s3:AbortMultipartUpload", "s3:ListBucket"]
    resources = [
      aws_s3_bucket.market_data.arn,
      "${aws_s3_bucket.market_data.arn}/*"
    ]
  }
  statement {
    actions   = ["ssm:GetParameter", "ssm:GetParametersByPath"]
    resources = ["arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${local.parameter_path}/*"]
  }
  statement {
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:ChangeMessageVisibility",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl"
    ]
    resources = [aws_sqs_queue.corporate_action_approval[0].arn]
  }
  statement {
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.corporate_action_approval_dlq[0].arn]
  }
}

resource "aws_iam_role_policy" "pipeline_task" {
  count  = local.enable_service_stack ? 1 : 0
  role   = aws_iam_role.pipeline_task[0].id
  policy = data.aws_iam_policy_document.pipeline_task[0].json
}

resource "aws_security_group" "pipeline" {
  count       = local.enable_service_stack ? 1 : 0
  name        = "${local.name_prefix}-pipeline"
  description = "Desired-zero Fargate pipeline has no inbound rules"
  vpc_id      = aws_vpc.this.id
}

resource "aws_vpc_security_group_egress_rule" "pipeline_all" {
  count             = local.enable_service_stack ? 1 : 0
  security_group_id = aws_security_group.pipeline[0].id
  description       = "Pipeline egress to AWS APIs, Alpaca and private PostgreSQL"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_ecs_task_definition" "pipeline" {
  count                    = local.enable_service_stack ? 1 : 0
  family                   = "${local.name_prefix}-pipeline"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.pipeline_execution[0].arn
  task_role_arn            = aws_iam_role.pipeline_task[0].arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  volume {
    name = "pipeline-state"
  }

  container_definitions = jsonencode([{
    name                   = "pipeline-worker"
    image                  = "${data.aws_ecr_repository.this["pipeline-worker"].repository_url}@${var.container_image_digests["pipeline-worker"]}"
    essential              = true
    stopTimeout            = 120
    readonlyRootFilesystem = true
    environment = [
      { name = "PIPELINE_WORKER_ENVIRONMENT", value = var.environment },
      { name = "PIPELINE_WORKER_MESSAGE_SOURCE", value = "sqs" },
      { name = "PIPELINE_WORKER_QUEUE_URL", value = aws_sqs_queue.corporate_action_approval[0].url },
      { name = "PIPELINE_WORKER_DEAD_LETTER_QUEUE_URL", value = aws_sqs_queue.corporate_action_approval_dlq[0].url },
      { name = "PIPELINE_WORKER_MAX_RECEIVE_COUNT", value = "5" },
      { name = "PIPELINE_WORKER_CATALOG_ROOT", value = "/var/lib/idea2strategy/pipeline/catalog-artifacts" },
      { name = "PIPELINE_WORKER_OBJECT_STORE_ROOT", value = "/var/lib/idea2strategy/pipeline/local-objects" },
      { name = "PIPELINE_WORKER_AWS_REGION", value = var.aws_region },
      { name = "PIPELINE_WORKER_HEALTH_FILE", value = "/tmp/idea2strategy-ready.json" },
      { name = "PIPELINE_WORKER_HEALTH_HOST", value = "0.0.0.0" },
      { name = "PIPELINE_WORKER_HEALTH_PORT", value = "8080" },
      {
        name = "PIPELINE_WORKER_CORPORATE_ACTION_APPROVAL"
        value = jsonencode({
          adjusted_feed_id       = "706f33aa-a461-5376-ae25-9c1bb64b9277"
          permission_id          = "20000000-0000-4000-8000-000000000012"
          request_schema_version = "schema-v1"
          object_bucket          = aws_s3_bucket.market_data.id
          object_prefix          = "market-data"
          staging_root           = "/var/lib/idea2strategy/pipeline/corporate-actions"
        })
      },
      { name = "MARKET_DATA_BUCKET", value = aws_s3_bucket.market_data.id },
      { name = "PIPELINE_MANIFEST_MODE", value = "content-addressed" },
      { name = "PIPELINE_WORKER_EXIT_AFTER_IDLE_POLLS", value = "6" }
    ]
    mountPoints = [{
      sourceVolume  = "pipeline-state"
      containerPath = "/var/lib/idea2strategy/pipeline"
      readOnly      = false
    }]
    secrets = [
      { name = "ALPACA_API_KEY", valueFrom = "${data.aws_secretsmanager_secret.alpaca_api_key[0].arn}:ALPACA_API_KEY::" },
      { name = "ALPACA_SECRET_KEY", valueFrom = "${data.aws_secretsmanager_secret.alpaca_secret_key[0].arn}:ALPACA_SECRET_KEY::" },
      { name = "PIPELINE_WORKER_DATABASE_URL", valueFrom = "${aws_secretsmanager_secret.runtime_database["pipeline"].arn}:PIPELINE_WORKER_DATABASE_URL::" }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.pipeline[0].name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "pipeline"
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "test -s /tmp/idea2strategy-ready.json"]
      interval    = 10
      timeout     = 5
      retries     = 3
      startPeriod = 20
    }
  }])
}

resource "aws_ecs_service" "pipeline" {
  count           = local.enable_service_stack ? 1 : 0
  name            = "${local.name_prefix}-pipeline"
  cluster         = aws_ecs_cluster.pipeline[0].id
  task_definition = aws_ecs_task_definition.pipeline[0].arn
  desired_count   = 0

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  network_configuration {
    subnets          = values(aws_subnet.public)[*].id
    security_groups  = [aws_security_group.pipeline[0].id]
    assign_public_ip = true
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}

resource "aws_appautoscaling_target" "pipeline" {
  count              = local.enable_service_stack ? 1 : 0
  max_capacity       = 1
  min_capacity       = 0
  resource_id        = "service/${aws_ecs_cluster.pipeline[0].name}/${aws_ecs_service.pipeline[0].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "pipeline_scale_out" {
  count              = local.enable_service_stack ? 1 : 0
  name               = "${local.name_prefix}-pipeline-scale-out"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.pipeline[0].resource_id
  scalable_dimension = aws_appautoscaling_target.pipeline[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.pipeline[0].service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ExactCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"
    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }
}

resource "aws_appautoscaling_policy" "pipeline_scale_in" {
  count              = local.enable_service_stack ? 1 : 0
  name               = "${local.name_prefix}-pipeline-scale-in"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.pipeline[0].resource_id
  scalable_dimension = aws_appautoscaling_target.pipeline[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.pipeline[0].service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ExactCapacity"
    cooldown                = 300
    metric_aggregation_type = "Maximum"
    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = 0
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "pipeline_queue_has_work" {
  count               = local.enable_service_stack ? 1 : 0
  alarm_name          = "${local.name_prefix}-pipeline-queue-has-work"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { QueueName = aws_sqs_queue.corporate_action_approval[0].name }
  alarm_actions       = [aws_appautoscaling_policy.pipeline_scale_out[0].arn]
}

resource "aws_cloudwatch_metric_alarm" "pipeline_queue_idle" {
  count               = local.enable_service_stack ? 1 : 0
  alarm_name          = "${local.name_prefix}-pipeline-queue-idle"
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_appautoscaling_policy.pipeline_scale_in[0].arn]

  metric_query {
    id          = "backlog"
    expression  = "visible + in_flight"
    label       = "Corporate action approval backlog"
    return_data = true
  }

  metric_query {
    id          = "visible"
    return_data = false
    metric {
      namespace   = "AWS/SQS"
      metric_name = "ApproximateNumberOfMessagesVisible"
      period      = 60
      stat        = "Maximum"
      dimensions  = { QueueName = aws_sqs_queue.corporate_action_approval[0].name }
    }
  }

  metric_query {
    id          = "in_flight"
    return_data = false
    metric {
      namespace   = "AWS/SQS"
      metric_name = "ApproximateNumberOfMessagesNotVisible"
      period      = 60
      stat        = "Maximum"
      dimensions  = { QueueName = aws_sqs_queue.corporate_action_approval[0].name }
    }
  }
}

resource "aws_cloudwatch_event_rule" "pipeline" {
  count               = local.enable_service_stack && var.pipeline_schedule_expression != "" ? 1 : 0
  name                = "${local.name_prefix}-pipeline"
  schedule_expression = var.pipeline_schedule_expression
}

resource "aws_iam_role" "pipeline_events" {
  count              = local.enable_service_stack && var.pipeline_schedule_expression != "" ? 1 : 0
  name               = "${local.name_prefix}-pipeline-events"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "events.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}

resource "aws_iam_role_policy" "pipeline_events" {
  count = local.enable_service_stack && var.pipeline_schedule_expression != "" ? 1 : 0
  role  = aws_iam_role.pipeline_events[0].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["ecs:RunTask"], Resource = [aws_ecs_task_definition.pipeline[0].arn] },
    { Effect = "Allow", Action = ["iam:PassRole"], Resource = [aws_iam_role.pipeline_execution[0].arn, aws_iam_role.pipeline_task[0].arn] }
  ] })
}

resource "aws_cloudwatch_event_target" "pipeline" {
  count    = local.enable_service_stack && var.pipeline_schedule_expression != "" ? 1 : 0
  rule     = aws_cloudwatch_event_rule.pipeline[0].name
  arn      = aws_ecs_cluster.pipeline[0].arn
  role_arn = aws_iam_role.pipeline_events[0].arn

  ecs_target {
    task_definition_arn = aws_ecs_task_definition.pipeline[0].arn
    task_count          = 1
    capacity_provider_strategy {
      capacity_provider = "FARGATE_SPOT"
      weight            = 1
    }
    network_configuration {
      subnets          = values(aws_subnet.public)[*].id
      security_groups  = [aws_security_group.pipeline[0].id]
      assign_public_ip = true
    }
  }
}
