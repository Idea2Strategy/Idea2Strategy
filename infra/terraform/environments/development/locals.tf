locals {
  name_prefix = "${var.project_name}-${var.environment}"

  enable_service_stack  = var.deployment_phase == "full"
  enable_dns_foundation = contains(["dns_foundation", "full"], var.deployment_phase)

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = "Infrastructure"
  }

  public_subnets = {
    a = {
      cidr_block = var.public_subnet_cidrs[0]
      az         = data.aws_availability_zones.available.names[0]
    }
    b = {
      cidr_block = var.public_subnet_cidrs[1]
      az         = data.aws_availability_zones.available.names[1]
    }
  }

  private_db_subnets = {
    a = {
      cidr_block = var.private_db_subnet_cidrs[0]
      az         = data.aws_availability_zones.available.names[0]
    }
    b = {
      cidr_block = var.private_db_subnet_cidrs[1]
      az         = data.aws_availability_zones.available.names[1]
    }
  }

  market_data_bucket_name = "${local.name_prefix}-${data.aws_caller_identity.current.account_id}-market-data"
  result_bucket_name      = "${local.name_prefix}-${data.aws_caller_identity.current.account_id}-backtest-results"
  frontend_bucket_name    = "${local.name_prefix}-${data.aws_caller_identity.current.account_id}-frontend"

  ecr_repositories = local.enable_service_stack ? toset([
    "admin-mcp",
    "backend-api",
    "backend-batch",
    "backend-worker",
    "backtest-api",
    "backtest-worker",
    "market-gateway",
    "pipeline-worker",
    "trading-worker"
  ]) : toset([])

  required_runtime_images = toset([
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

  backtest_lanes = local.enable_service_stack ? toset(["basic", "custom", "competition"]) : toset([])

  parameter_path = "/${var.project_name}/${var.environment}"

  alarm_action_arns = local.enable_service_stack ? [aws_sns_topic.operations[0].arn] : []

  hosted_zone_id = local.enable_dns_foundation ? (
    var.existing_hosted_zone_id != "" ? var.existing_hosted_zone_id : aws_route53_zone.this[0].zone_id
  ) : null
}

check "two_availability_zones" {
  assert {
    condition     = length(data.aws_availability_zones.available.names) >= 2
    error_message = "The selected region must expose at least two available Availability Zones."
  }
}

check "full_phase_account_guard" {
  assert {
    condition     = !local.enable_service_stack || var.expected_aws_account_id != ""
    error_message = "expected_aws_account_id is required before planning or applying the full phase."
  }
}

check "full_phase_dns_delegation" {
  assert {
    condition     = !local.enable_service_stack || var.dns_delegation_verified
    error_message = "The full phase requires independently verified registrar delegation to the reviewed Route 53 zone."
  }
}

check "full_phase_database_recovery" {
  assert {
    condition     = !local.enable_service_stack || var.rds_backup_retention_days >= 7
    error_message = "The full phase requires at least seven days of RDS PITR retention."
  }
}

check "full_phase_immutable_artifacts" {
  assert {
    condition = !local.enable_service_stack || (
      toset(keys(var.container_image_digests)) == local.required_runtime_images &&
      var.frontend_release_id != ""
    )
    error_message = "The full phase requires every runtime image digest and an immutable frontend_release_id."
  }
}
