resource "random_password" "cloudfront_origin_header" {
  count   = local.enable_service_stack ? 1 : 0
  length  = 48
  special = false
}

resource "aws_secretsmanager_secret" "cloudfront_origin_header" {
  count                   = local.enable_service_stack ? 1 : 0
  name                    = "${local.name_prefix}/edge/origin-header"
  recovery_window_in_days = 7
  lifecycle { prevent_destroy = true }
}

resource "aws_secretsmanager_secret_version" "cloudfront_origin_header" {
  count         = local.enable_service_stack ? 1 : 0
  secret_id     = aws_secretsmanager_secret.cloudfront_origin_header[0].id
  secret_string = random_password.cloudfront_origin_header[0].result
}

data "aws_secretsmanager_secret" "alpaca_api_key" {
  count = local.enable_service_stack ? 1 : 0
  name  = var.alpaca_api_key_secret_name
}

data "aws_secretsmanager_secret" "alpaca_secret_key" {
  count = local.enable_service_stack ? 1 : 0
  name  = var.alpaca_secret_key_secret_name
}

resource "aws_ssm_parameter" "alpaca_api_key_secret_arn" {
  count = local.enable_service_stack ? 1 : 0
  name  = "${local.parameter_path}/provider/alpaca-api-key-secret-arn"
  type  = "String"
  value = data.aws_secretsmanager_secret.alpaca_api_key[0].arn
}

resource "aws_ssm_parameter" "alpaca_secret_key_secret_arn" {
  count = local.enable_service_stack ? 1 : 0
  name  = "${local.parameter_path}/provider/alpaca-secret-key-secret-arn"
  type  = "String"
  value = data.aws_secretsmanager_secret.alpaca_secret_key[0].arn
}

resource "aws_security_group" "service" {
  count       = local.enable_service_stack ? 1 : 0
  name        = "${local.name_prefix}-core"
  description = "Core HTTPS origin restricted to the CloudFront origin-facing prefix list"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${local.name_prefix}-core" }
}

resource "aws_vpc_security_group_ingress_rule" "service_from_cloudfront" {
  count             = local.enable_service_stack ? 1 : 0
  security_group_id = aws_security_group.service[0].id
  description       = "HTTPS origin traffic from CloudFront only"
  from_port         = var.service_target_port
  to_port           = var.service_target_port
  ip_protocol       = "tcp"
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront_origin[0].id
}

resource "aws_vpc_security_group_egress_rule" "service_all" {
  count             = local.enable_service_stack ? 1 : 0
  security_group_id = aws_security_group.service[0].id
  description       = "Core runtime egress to AWS APIs, package sources and private data endpoints"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "trading" {
  count       = local.enable_service_stack ? 1 : 0
  name        = "${local.name_prefix}-trading"
  description = "Trading runtime has no inbound rules"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${local.name_prefix}-trading" }
}

resource "aws_vpc_security_group_egress_rule" "trading_all" {
  count             = local.enable_service_stack ? 1 : 0
  security_group_id = aws_security_group.trading[0].id
  description       = "Trading egress to Alpaca, AWS APIs and private data endpoints"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "batch" {
  name        = "${local.name_prefix}-batch-ec2-sg"
  description = "Batch EC2 has no public ingress"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${local.name_prefix}-batch-ec2-sg" }
}

resource "aws_vpc_security_group_egress_rule" "batch_all" {
  security_group_id = aws_security_group.batch.id
  description       = "Backtest egress to S3, SQS, AWS APIs and private PostgreSQL"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "database_bootstrap" {
  #checkov:skip=CKV2_AWS_5:The reviewed orchestrator attaches this SG only to its exact ephemeral EC2 ID and terminates that host in finally.
  name        = "${local.name_prefix}-database-bootstrap"
  description = "Ephemeral SSM database bootstrap host with no inbound rules"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${local.name_prefix}-database-bootstrap" }
}

resource "aws_vpc_security_group_egress_rule" "database_bootstrap_all" {
  security_group_id = aws_security_group.database_bootstrap.id
  description       = "Bootstrap egress to AWS APIs, package sources and private PostgreSQL"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Private PostgreSQL from approved application EC2 security groups only"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${local.name_prefix}-rds-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_runtime" {
  for_each = local.enable_service_stack ? {
    core     = aws_security_group.service[0].id
    trading  = aws_security_group.trading[0].id
    backtest = aws_security_group.batch.id
    pipeline = aws_security_group.pipeline[0].id
  } : { backtest = aws_security_group.batch.id }

  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL from ${each.key}"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = each.value
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_database_bootstrap" {
  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL from the ephemeral database bootstrap boundary"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.database_bootstrap.id
}
