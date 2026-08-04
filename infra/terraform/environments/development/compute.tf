resource "aws_instance" "service" {
  count = local.enable_service_stack ? 1 : 0

  ami                         = data.aws_ami.ubuntu_2404_arm64.id
  instance_type               = var.service_instance_type
  subnet_id                   = aws_subnet.public["a"].id
  vpc_security_group_ids      = [aws_security_group.service[0].id]
  iam_instance_profile        = aws_iam_instance_profile.service[0].name
  associate_public_ip_address = true
  source_dest_check           = true

  user_data = templatefile("${path.module}/templates/ec2-user-data.sh.tftpl", {
    runtime_role                 = "service"
    aws_region                   = var.aws_region
    parameter_path               = local.parameter_path
    log_group_name               = aws_cloudwatch_log_group.service[0].name
    origin_domain_name           = var.origin_domain_name
    origin_header_secret_arn     = aws_secretsmanager_secret.cloudfront_origin_header[0].arn
    backend_port                 = 8080
    database_host                = aws_db_instance.this.address
    database_name                = aws_db_instance.this.db_name
    core_database_secret_arn     = data.aws_secretsmanager_secret.runtime_database["backend"].arn
    batch_database_secret_arn    = data.aws_secretsmanager_secret.runtime_database["batch"].arn
    backtest_database_secret_arn = data.aws_secretsmanager_secret.runtime_database["backtest"].arn
    trading_database_secret_arn  = data.aws_secretsmanager_secret.runtime_database["trading"].arn
    core_internal_secret_arn     = aws_secretsmanager_secret.core_internal[0].arn
    backtest_internal_secret_arn = aws_secretsmanager_secret.backtest_internal[0].arn
    alpaca_api_key_secret_arn    = data.aws_secretsmanager_secret.alpaca_api_key[0].arn
    alpaca_secret_key_secret_arn = data.aws_secretsmanager_secret.alpaca_secret_key[0].arn
    market_data_bucket           = aws_s3_bucket.market_data.id
    result_bucket                = aws_s3_bucket.results[0].id
    cache_endpoint               = aws_elasticache_serverless_cache.this[0].endpoint[0].address
    core_public_url              = "https://${var.frontend_domain_name}"
    backtest_policy_manifest     = base64encode(jsonencode(var.backtest_policy_artifacts))
    trading_artifact_manifest    = base64encode(jsonencode(var.trading_runtime_artifacts))
    enable_backtest_outbox_relay = var.enable_backtest_outbox_relay
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

  credit_specification { cpu_credits = "standard" }
  monitoring = false

  lifecycle { create_before_destroy = true }

  tags = {
    Name = "${local.name_prefix}-core"
    Role = "core"
  }

  depends_on = [
    aws_route_table_association.public,
    aws_iam_role_policy_attachment.service_managed,
    aws_iam_role_policy.service_origin_tls,
    aws_ssm_parameter.runtime_image
  ]
}

resource "aws_eip" "service" {
  count = local.enable_service_stack ? 1 : 0

  domain   = "vpc"
  instance = aws_instance.service[0].id

  tags       = { Name = "${local.name_prefix}-core-eip" }
  depends_on = [aws_internet_gateway.this]
}

resource "aws_instance" "trading" {
  count = local.enable_service_stack ? 1 : 0

  ami                         = data.aws_ami.ubuntu_2404_arm64.id
  instance_type               = var.trading_instance_type
  subnet_id                   = aws_subnet.public["b"].id
  vpc_security_group_ids      = [aws_security_group.trading[0].id]
  iam_instance_profile        = aws_iam_instance_profile.trading[0].name
  associate_public_ip_address = true
  source_dest_check           = true

  user_data = templatefile("${path.module}/templates/ec2-user-data.sh.tftpl", {
    runtime_role                 = "trading"
    aws_region                   = var.aws_region
    parameter_path               = local.parameter_path
    log_group_name               = aws_cloudwatch_log_group.trading[0].name
    origin_domain_name           = ""
    origin_header_secret_arn     = ""
    backend_port                 = 0
    database_host                = aws_db_instance.this.address
    database_name                = aws_db_instance.this.db_name
    core_database_secret_arn     = data.aws_secretsmanager_secret.runtime_database["backend"].arn
    batch_database_secret_arn    = data.aws_secretsmanager_secret.runtime_database["batch"].arn
    backtest_database_secret_arn = data.aws_secretsmanager_secret.runtime_database["backtest"].arn
    trading_database_secret_arn  = data.aws_secretsmanager_secret.runtime_database["trading"].arn
    core_internal_secret_arn     = aws_secretsmanager_secret.core_internal[0].arn
    backtest_internal_secret_arn = aws_secretsmanager_secret.backtest_internal[0].arn
    alpaca_api_key_secret_arn    = data.aws_secretsmanager_secret.alpaca_api_key[0].arn
    alpaca_secret_key_secret_arn = data.aws_secretsmanager_secret.alpaca_secret_key[0].arn
    market_data_bucket           = aws_s3_bucket.market_data.id
    result_bucket                = aws_s3_bucket.results[0].id
    cache_endpoint               = aws_elasticache_serverless_cache.this[0].endpoint[0].address
    core_public_url              = "https://${var.frontend_domain_name}"
    backtest_policy_manifest     = base64encode(jsonencode(var.backtest_policy_artifacts))
    trading_artifact_manifest    = base64encode(jsonencode(var.trading_runtime_artifacts))
    enable_backtest_outbox_relay = var.enable_backtest_outbox_relay
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
    volume_size           = var.trading_root_volume_gib
    encrypted             = true
    delete_on_termination = true
  }

  monitoring = false
  lifecycle { create_before_destroy = true }

  tags = {
    Name = "${local.name_prefix}-trading"
    Role = "trading"
  }

  depends_on = [
    aws_route_table_association.public,
    aws_iam_role_policy_attachment.trading_managed,
    aws_ssm_parameter.runtime_image
  ]
}

resource "aws_launch_template" "backtest" {
  count = local.enable_service_stack ? 1 : 0

  name_prefix   = "${local.name_prefix}-backtest-"
  image_id      = data.aws_ami.ubuntu_2404_arm64.id
  instance_type = var.backtest_instance_type

  iam_instance_profile { name = aws_iam_instance_profile.batch.name }
  vpc_security_group_ids = [aws_security_group.batch.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  credit_specification {
    cpu_credits = "standard"
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      encrypted             = true
      volume_size           = var.backtest_root_volume_gib
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/templates/ec2-user-data.sh.tftpl", {
    runtime_role                 = "backtest-worker"
    aws_region                   = var.aws_region
    parameter_path               = local.parameter_path
    log_group_name               = aws_cloudwatch_log_group.compute[0].name
    origin_domain_name           = ""
    origin_header_secret_arn     = ""
    backend_port                 = 0
    database_host                = aws_db_instance.this.address
    database_name                = aws_db_instance.this.db_name
    core_database_secret_arn     = data.aws_secretsmanager_secret.runtime_database["backend"].arn
    batch_database_secret_arn    = data.aws_secretsmanager_secret.runtime_database["batch"].arn
    backtest_database_secret_arn = data.aws_secretsmanager_secret.runtime_database["backtest"].arn
    trading_database_secret_arn  = data.aws_secretsmanager_secret.runtime_database["trading"].arn
    core_internal_secret_arn     = aws_secretsmanager_secret.core_internal[0].arn
    backtest_internal_secret_arn = aws_secretsmanager_secret.backtest_internal[0].arn
    alpaca_api_key_secret_arn    = data.aws_secretsmanager_secret.alpaca_api_key[0].arn
    alpaca_secret_key_secret_arn = data.aws_secretsmanager_secret.alpaca_secret_key[0].arn
    market_data_bucket           = aws_s3_bucket.market_data.id
    result_bucket                = aws_s3_bucket.results[0].id
    cache_endpoint               = aws_elasticache_serverless_cache.this[0].endpoint[0].address
    core_public_url              = "https://${var.frontend_domain_name}"
    backtest_policy_manifest     = base64encode(jsonencode(var.backtest_policy_artifacts))
    trading_artifact_manifest    = base64encode(jsonencode(var.trading_runtime_artifacts))
    enable_backtest_outbox_relay = var.enable_backtest_outbox_relay
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.name_prefix}-backtest-worker"
      Role = "backtest-worker"
    }
  }

  depends_on = [aws_ssm_parameter.runtime_image]
}

resource "aws_autoscaling_group" "backtest" {
  count = local.enable_service_stack ? 1 : 0

  depends_on = [
    aws_ssm_parameter.backtest_queue_url,
    aws_ssm_parameter.backtest_dlq_url,
    aws_ssm_parameter.backtest_lane_concurrency,
    aws_ssm_parameter.backtest_total_concurrency,
    aws_ssm_parameter.runtime_image,
  ]

  name                = "${local.name_prefix}-backtest"
  min_size            = 0
  desired_capacity    = 0
  max_size            = 1
  vpc_zone_identifier = values(aws_subnet.public)[*].id
  health_check_type   = "EC2"

  launch_template {
    id      = aws_launch_template.backtest[0].id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences { min_healthy_percentage = 0 }
  }

  lifecycle { ignore_changes = [desired_capacity] }
}

resource "aws_autoscaling_policy" "backtest_start" {
  count = local.enable_service_stack ? 1 : 0

  name                   = "${local.name_prefix}-backtest-start"
  autoscaling_group_name = aws_autoscaling_group.backtest[0].name
  adjustment_type        = "ExactCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "backtest_queue_start" {
  for_each = local.backtest_lanes

  alarm_name          = "${local.name_prefix}-backtest-${each.key}-start"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_autoscaling_policy.backtest_start[0].arn]
  dimensions          = { QueueName = aws_sqs_queue.backtest[each.key].name }
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

resource "aws_ssm_parameter" "backtest_asg_name" {
  count = local.enable_service_stack ? 1 : 0
  name  = "${local.parameter_path}/backtest/asg-name"
  type  = "String"
  value = aws_autoscaling_group.backtest[0].name
}
