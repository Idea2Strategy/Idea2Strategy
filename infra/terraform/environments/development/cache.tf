resource "aws_security_group" "cache" {
  count = local.enable_service_stack ? 1 : 0

  name        = "${local.name_prefix}-valkey-serverless"
  description = "Private Valkey Serverless endpoint; no public ingress"
  vpc_id      = aws_vpc.this.id
  tags        = { Name = "${local.name_prefix}-valkey-serverless" }
}

resource "aws_vpc_security_group_ingress_rule" "cache_from_runtime" {
  for_each = local.enable_service_stack ? {
    core     = aws_security_group.service[0].id
    trading  = aws_security_group.trading[0].id
    backtest = aws_security_group.batch.id
    pipeline = aws_security_group.pipeline[0].id
  } : {}

  security_group_id            = aws_security_group.cache[0].id
  description                  = "Valkey TLS from ${each.key}"
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  referenced_security_group_id = each.value
}

resource "aws_elasticache_serverless_cache" "this" {
  count = local.enable_service_stack ? 1 : 0

  name                     = "${local.name_prefix}-valkey"
  description              = "Ephemeral sessions, market-data read models and transient streams; durable source data remains in PostgreSQL and S3"
  engine                   = "valkey"
  major_engine_version     = "8"
  subnet_ids               = values(aws_subnet.private_db)[*].id
  security_group_ids       = [aws_security_group.cache[0].id]
  snapshot_retention_limit = 1

  cache_usage_limits {
    data_storage {
      maximum = 1
      unit    = "GB"
    }
    ecpu_per_second {
      maximum = 1000
    }
  }

  tags = { Name = "${local.name_prefix}-valkey" }
}

resource "aws_ssm_parameter" "cache_endpoint" {
  count = local.enable_service_stack ? 1 : 0
  name  = "${local.parameter_path}/cache/endpoint"
  type  = "String"
  value = aws_elasticache_serverless_cache.this[0].endpoint[0].address
}

resource "aws_ssm_parameter" "cache_port" {
  count = local.enable_service_stack ? 1 : 0
  name  = "${local.parameter_path}/cache/port"
  type  = "String"
  value = tostring(aws_elasticache_serverless_cache.this[0].endpoint[0].port)
}

resource "aws_ssm_parameter" "cache_tls" {
  count = local.enable_service_stack ? 1 : 0
  name  = "${local.parameter_path}/cache/tls"
  type  = "String"
  value = "true"
}
