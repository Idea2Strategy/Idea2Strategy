resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.name_prefix}-default-deny" }
}

resource "aws_cloudwatch_log_group" "vpc_flow" {
  count             = local.enable_service_stack ? 1 : 0
  name              = "/${var.project_name}/${var.environment}/vpc-flow-reject"
  retention_in_days = var.cloudwatch_log_retention_days
}

data "aws_iam_policy_document" "vpc_flow_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "vpc_flow" {
  count              = local.enable_service_stack ? 1 : 0
  name               = "${local.name_prefix}-vpc-flow"
  assume_role_policy = data.aws_iam_policy_document.vpc_flow_assume.json
}

resource "aws_iam_role_policy" "vpc_flow" {
  count = local.enable_service_stack ? 1 : 0
  role  = aws_iam_role.vpc_flow[0].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect   = "Allow"
    Action   = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"]
    Resource = "${aws_cloudwatch_log_group.vpc_flow[0].arn}:*"
  }] })
}

resource "aws_flow_log" "reject" {
  count                = local.enable_service_stack ? 1 : 0
  iam_role_arn         = aws_iam_role.vpc_flow[0].arn
  log_destination      = aws_cloudwatch_log_group.vpc_flow[0].arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "REJECT"
  vpc_id               = aws_vpc.this.id
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value.az
  cidr_block              = each.value.cidr_block
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-${each.key}"
    Tier = "public"
  }
}

resource "aws_subnet" "private_db" {
  for_each = local.private_db_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value.az
  cidr_block              = each.value.cidr_block
  map_public_ip_on_launch = false

  tags = {
    Name = "${local.name_prefix}-private-db-${each.key}"
    Tier = "private-db"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_db" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-private-db-rt"
  }
}

resource "aws_route_table_association" "private_db" {
  for_each = aws_subnet.private_db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_db.id
}

resource "aws_vpc_endpoint" "s3" {
  count = local.enable_service_stack ? 1 : 0

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.public.id]

  tags = {
    Name = "${local.name_prefix}-s3-endpoint"
  }
}
