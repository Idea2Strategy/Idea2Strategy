resource "aws_instance" "service" {
  count = local.enable_service_stack ? 1 : 0

  ami                         = data.aws_ami.ubuntu_2404.id
  instance_type               = var.service_instance_type
  subnet_id                   = aws_subnet.public["a"].id
  vpc_security_group_ids      = [aws_security_group.service[0].id]
  iam_instance_profile        = aws_iam_instance_profile.service[0].name
  associate_public_ip_address = true
  source_dest_check           = true

  user_data = templatefile("${path.module}/templates/ec2-user-data.sh.tftpl", {
    runtime_role   = "service"
    aws_region     = var.aws_region
    parameter_path = local.parameter_path
    log_group_name = aws_cloudwatch_log_group.service[0].name
  })
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.service_root_volume_gib
    encrypted             = true
    delete_on_termination = true
  }

  dynamic "credit_specification" {
    for_each = startswith(var.service_instance_type, "t") ? [1] : []

    content {
      cpu_credits = "standard"
    }
  }

  monitoring = false

  lifecycle {
    # A stopped instance temporarily loses its auto-assigned public IPv4
    # association. Do not replace healthy compute solely because of that drift.
    ignore_changes = [associate_public_ip_address]
  }

  tags = {
    Name = "${local.name_prefix}-service-ec2"
    Role = "service"
  }

  depends_on = [
    aws_route_table_association.public,
    aws_iam_role_policy_attachment.service_managed
  ]
}

resource "aws_instance" "batch" {
  ami                         = data.aws_ami.ubuntu_2404.id
  instance_type               = var.batch_instance_type
  subnet_id                   = aws_subnet.public["b"].id
  vpc_security_group_ids      = [aws_security_group.batch.id]
  iam_instance_profile        = aws_iam_instance_profile.batch.name
  associate_public_ip_address = true
  source_dest_check           = true

  user_data = templatefile("${path.module}/templates/ec2-user-data.sh.tftpl", {
    runtime_role   = "batch"
    aws_region     = var.aws_region
    parameter_path = local.parameter_path
    log_group_name = aws_cloudwatch_log_group.batch.name
  })
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.batch_root_volume_gib
    encrypted             = true
    delete_on_termination = true
  }

  dynamic "credit_specification" {
    for_each = startswith(var.batch_instance_type, "t") ? [1] : []

    content {
      cpu_credits = "standard"
    }
  }

  monitoring = false

  lifecycle {
    # A stopped instance temporarily loses its auto-assigned public IPv4
    # association. Preserve the instance and its staging volume during resize.
    ignore_changes = [associate_public_ip_address]
  }

  tags = {
    Name = "${local.name_prefix}-batch-ec2"
    Role = "batch"
  }

  depends_on = [
    aws_route_table_association.public,
    aws_iam_role_policy_attachment.batch_managed
  ]
}

resource "aws_ssm_parameter" "market_data_bucket" {
  name  = "${local.parameter_path}/storage/market-data-bucket"
  type  = "String"
  value = aws_s3_bucket.market_data.id
}

resource "aws_ssm_parameter" "result_bucket" {
  count = local.enable_service_stack ? 1 : 0

  name  = "${local.parameter_path}/storage/result-bucket"
  type  = "String"
  value = aws_s3_bucket.results[0].id
}

resource "aws_ssm_parameter" "backtest_base_url" {
  count = local.enable_service_stack ? 1 : 0

  name  = "${local.parameter_path}/services/backtest-base-url"
  type  = "String"
  value = "http://${aws_instance.batch.private_ip}:${var.backtest_internal_port}"
}
