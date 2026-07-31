resource "aws_security_group" "alb" {
  count = local.enable_service_stack ? 1 : 0

  name        = "${local.name_prefix}-alb-sg"
  description = "Internet ingress to the public ALB only"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  count = local.enable_service_stack ? 1 : 0

  security_group_id = aws_security_group.alb[0].id
  description       = "Public HTTP; redirected after HTTPS activation"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  count = local.enable_service_stack && var.enable_https ? 1 : 0

  security_group_id = aws_security_group.alb[0].id
  description       = "Public HTTPS"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_service" {
  count = local.enable_service_stack ? 1 : 0

  security_group_id            = aws_security_group.alb[0].id
  description                  = "ALB to Caddy target"
  from_port                    = var.service_target_port
  to_port                      = var.service_target_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.service[0].id
}

resource "aws_security_group" "service" {
  count = local.enable_service_stack ? 1 : 0

  name        = "${local.name_prefix}-service-ec2-sg"
  description = "Service EC2 accepts only the ALB Caddy target"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-service-ec2-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "service_from_alb" {
  count = local.enable_service_stack ? 1 : 0

  security_group_id            = aws_security_group.service[0].id
  description                  = "Caddy target from ALB only"
  from_port                    = var.service_target_port
  to_port                      = var.service_target_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb[0].id
}

resource "aws_vpc_security_group_egress_rule" "service_all" {
  count = local.enable_service_stack ? 1 : 0

  security_group_id = aws_security_group.service[0].id
  description       = "AWS APIs, SIP, package repositories, RDS and internal backtest API"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "batch" {
  name        = "${local.name_prefix}-batch-ec2-sg"
  description = "Batch EC2 has no public ingress"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-batch-ec2-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "batch_backtest_from_service" {
  count = local.enable_service_stack ? 1 : 0

  security_group_id            = aws_security_group.batch.id
  description                  = "Private Backtest Spring API from service EC2 only"
  from_port                    = var.backtest_internal_port
  to_port                      = var.backtest_internal_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.service[0].id
}

resource "aws_vpc_security_group_egress_rule" "batch_all" {
  security_group_id = aws_security_group.batch.id
  description       = "AWS APIs, Alpaca, package repositories and RDS"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Private PostgreSQL from approved application EC2 security groups only"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-rds-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_service" {
  count = local.enable_service_stack ? 1 : 0

  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL from service EC2"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.service[0].id
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_batch" {
  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL from batch EC2"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.batch.id
}

resource "aws_vpc_security_group_egress_rule" "rds_all" {
  security_group_id = aws_security_group.rds.id
  description       = "Default RDS egress"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
