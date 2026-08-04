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
      data.aws_secretsmanager_secret.runtime_database["pipeline"].arn
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

  container_definitions = jsonencode([{
    name        = "pipeline-worker"
    image       = "${data.aws_ecr_repository.this["pipeline-worker"].repository_url}@${var.container_image_digests["pipeline-worker"]}"
    essential   = true
    stopTimeout = 120
    environment = [
      { name = "PIPELINE_WORKER_ENVIRONMENT", value = var.environment },
      { name = "PIPELINE_WORKER_MESSAGE_SOURCE", value = "inprocess" },
      { name = "PIPELINE_WORKER_CATALOG_ROOT", value = "/var/lib/idea2strategy/catalog" },
      { name = "PIPELINE_WORKER_OBJECT_STORE_ROOT", value = "/var/lib/idea2strategy/objects" },
      { name = "PIPELINE_WORKER_AWS_REGION", value = var.aws_region },
      { name = "PIPELINE_WORKER_HEALTH_FILE", value = "/tmp/idea2strategy-ready.json" },
      { name = "MARKET_DATA_BUCKET", value = aws_s3_bucket.market_data.id },
      { name = "PIPELINE_MANIFEST_MODE", value = "content-addressed" },
      { name = "PIPELINE_WORKER_EXIT_AFTER_IDLE_POLLS", value = "3" }
    ]
    secrets = [
      { name = "ALPACA_API_KEY", valueFrom = "${data.aws_secretsmanager_secret.alpaca_api_key[0].arn}:ALPACA_API_KEY::" },
      { name = "ALPACA_SECRET_KEY", valueFrom = "${data.aws_secretsmanager_secret.alpaca_secret_key[0].arn}:ALPACA_SECRET_KEY::" },
      { name = "PIPELINE_WORKER_DATABASE_URL", valueFrom = "${data.aws_secretsmanager_secret.runtime_database["pipeline"].arn}:PIPELINE_WORKER_DATABASE_URL::" }
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
