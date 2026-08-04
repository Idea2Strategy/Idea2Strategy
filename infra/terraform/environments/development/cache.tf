resource "aws_elasticache_subnet_group" "this" {
  count = local.enable_service_stack ? 1 : 0

  name       = "${local.name_prefix}-cache-subnets"
  subnet_ids = values(aws_subnet.private_app)[*].id
}

resource "random_password" "cache_auth_token" {
  count = local.enable_service_stack ? 1 : 0

  length  = 40
  special = false
}

resource "aws_secretsmanager_secret" "cache" {
  count = local.enable_service_stack ? 1 : 0

  name                    = "${local.name_prefix}/cache/auth"
  description             = "Valkey AUTH token for the Development runtime."
  recovery_window_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "cache" {
  count = local.enable_service_stack ? 1 : 0

  secret_id = aws_secretsmanager_secret.cache[0].id
  secret_string = jsonencode({
    username = "default"
    password = random_password.cache_auth_token[0].result
  })
}

resource "aws_security_group" "cache" {
  count = local.enable_service_stack ? 1 : 0

  name        = "${local.name_prefix}-cache-sg"
  description = "Private Valkey access from approved runtimes only"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-cache-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "cache_from_service" {
  count = local.enable_service_stack ? 1 : 0

  security_group_id            = aws_security_group.cache[0].id
  description                  = "Valkey TLS from core runtime"
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.service[0].id
}

resource "aws_vpc_security_group_ingress_rule" "cache_from_trading" {
  count = local.enable_service_stack ? 1 : 0

  security_group_id            = aws_security_group.cache[0].id
  description                  = "Valkey TLS from trading runtime"
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.trading[0].id
}

resource "aws_elasticache_replication_group" "this" {
  count = local.enable_service_stack ? 1 : 0

  replication_group_id = "${local.name_prefix}-cache"
  description          = "Idea2Strategy Development shared ephemeral market and session cache"

  engine         = "valkey"
  engine_version = var.cache_engine_version
  node_type      = var.cache_node_type
  port           = 6379

  num_cache_clusters         = var.cache_automatic_failover ? 2 : 1
  automatic_failover_enabled = var.cache_automatic_failover
  multi_az_enabled           = var.cache_automatic_failover

  subnet_group_name  = aws_elasticache_subnet_group.this[0].name
  security_group_ids = [aws_security_group.cache[0].id]

  transit_encryption_enabled = true
  transit_encryption_mode    = "required"
  at_rest_encryption_enabled = true
  auth_token                 = random_password.cache_auth_token[0].result
  auth_token_update_strategy = "ROTATE"

  snapshot_retention_limit = 1
  snapshot_window          = "17:00-18:00"
  maintenance_window       = "sun:18:00-sun:19:00"
  apply_immediately        = true

  tags = {
    Name = "${local.name_prefix}-cache"
  }
}

resource "aws_ssm_parameter" "cache_endpoint" {
  count = local.enable_service_stack ? 1 : 0

  name  = "${local.parameter_path}/cache/endpoint"
  type  = "String"
  value = aws_elasticache_replication_group.this[0].primary_endpoint_address
}

resource "aws_ssm_parameter" "cache_port" {
  count = local.enable_service_stack ? 1 : 0

  name  = "${local.parameter_path}/cache/port"
  type  = "String"
  value = "6379"
}

resource "aws_ssm_parameter" "cache_tls" {
  count = local.enable_service_stack ? 1 : 0

  name  = "${local.parameter_path}/cache/tls"
  type  = "String"
  value = "true"
}

resource "aws_ssm_parameter" "cache_secret_arn" {
  count = local.enable_service_stack ? 1 : 0

  name  = "${local.parameter_path}/cache/auth-secret-arn"
  type  = "String"
  value = aws_secretsmanager_secret.cache[0].arn
}
