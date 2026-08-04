locals {
  name_prefix = "${var.project_name}-${var.environment}"
  repositories = toset([
    "admin-mcp",
    "backend-api",
    "backend-batch",
    "backend-worker",
    "backtest-api",
    "backtest-worker",
    "market-gateway",
    "pipeline-worker",
    "trading-worker"
  ])
}

resource "aws_ecr_repository" "runtime" {
  for_each = local.repositories

  name                 = "${local.name_prefix}/${each.value}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ecr_lifecycle_policy" "runtime" {
  for_each = local.repositories

  repository = aws_ecr_repository.runtime[each.key].name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the most recent 20 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = { type = "expire" }
      }
    ]
  })
}
