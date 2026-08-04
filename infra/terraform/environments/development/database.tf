resource "aws_db_subnet_group" "this" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = values(aws_subnet.private_db)[*].id

  tags = {
    Name = "${local.name_prefix}-db-subnet-group"
  }
}

resource "aws_db_parameter_group" "postgres16" {
  name        = "${local.name_prefix}-postgres16"
  family      = "postgres16"
  description = "Idea2Strategy Development PostgreSQL 16 security parameters"

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "immediate"
  }
}

resource "random_id" "rds_final_snapshot" {
  byte_length = 4

  keepers = {
    identifier = "${local.name_prefix}-postgres"
  }
}

resource "aws_db_instance" "this" {
  identifier = "${local.name_prefix}-postgres"

  engine                      = "postgres"
  engine_version              = "16"
  auto_minor_version_upgrade  = true
  instance_class              = var.rds_instance_class
  allocated_storage           = var.rds_allocated_storage_gib
  max_allocated_storage       = var.rds_max_allocated_storage_gib
  storage_type                = "gp3"
  storage_encrypted           = true
  multi_az                    = false
  publicly_accessible         = false
  db_subnet_group_name        = aws_db_subnet_group.this.name
  vpc_security_group_ids      = [aws_security_group.rds.id]
  parameter_group_name        = aws_db_parameter_group.postgres16.name
  port                        = 5432
  db_name                     = "idea2strategy"
  username                    = "idea2strategy_admin"
  manage_master_user_password = true

  backup_retention_period = var.rds_backup_retention_days
  backup_window           = "18:00-18:30"
  maintenance_window      = "sun:19:00-sun:20:00"

  deletion_protection       = var.rds_deletion_protection
  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.name_prefix}-postgres-final-${random_id.rds_final_snapshot.hex}"
  copy_tags_to_snapshot     = true
  apply_immediately         = false

  performance_insights_enabled    = false
  monitoring_interval             = 0
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = {
    Name = "${local.name_prefix}-postgres"
  }
}

resource "aws_ssm_parameter" "rds_endpoint" {
  name  = "${local.parameter_path}/database/host"
  type  = "String"
  value = aws_db_instance.this.address
}

resource "aws_ssm_parameter" "rds_port" {
  name  = "${local.parameter_path}/database/port"
  type  = "String"
  value = tostring(aws_db_instance.this.port)
}

resource "aws_ssm_parameter" "rds_name" {
  name  = "${local.parameter_path}/database/name"
  type  = "String"
  value = aws_db_instance.this.db_name
}

resource "aws_ssm_parameter" "rds_secret_arn" {
  name  = "${local.parameter_path}/database/master-secret-arn"
  type  = "String"
  value = aws_db_instance.this.master_user_secret[0].secret_arn
}

resource "aws_secretsmanager_secret" "market_loader" {
  name                    = "${local.name_prefix}/database/market-loader"
  description             = "PostgreSQL credentials for the Development historical market-data loader."
  recovery_window_in_days = 7

  tags = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ssm_parameter" "market_loader_secret_arn" {
  name  = "${local.parameter_path}/database/market-loader-secret-arn"
  type  = "String"
  value = aws_secretsmanager_secret.market_loader.arn
}
