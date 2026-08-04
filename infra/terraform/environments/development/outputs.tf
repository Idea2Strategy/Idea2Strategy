output "aws_account_id" {
  description = "AWS account that owns this Development environment."
  value       = data.aws_caller_identity.current.account_id
  sensitive   = true
}

output "vpc_id" {
  description = "Development VPC ID."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public application subnets used by egress-only runtimes and the CloudFront-restricted Core origin."
  value       = values(aws_subnet.public)[*].id
}

output "private_db_subnet_ids" {
  description = "Private subnets used only by the RDS subnet group."
  value       = values(aws_subnet.private_db)[*].id
}

output "service_url" {
  description = "Development service URL. HTTPS becomes valid after DNS delegation and enable_https=true."
  value       = local.enable_service_stack ? (var.enable_https ? "https://${var.frontend_domain_name}" : "https://${aws_cloudfront_distribution.frontend[0].domain_name}") : null
}

output "route53_zone_id" {
  description = "Hosted Zone used for ideatostrategy.com."
  value       = local.enable_service_stack ? local.hosted_zone_id : null
}

output "route53_name_servers" {
  description = "Copy and verify all existing DNS records before setting these at Gabia."
  value       = local.enable_service_stack && var.existing_hosted_zone_id == "" ? aws_route53_zone.this[0].name_servers : []
}

output "acm_certificate_status" {
  description = "CloudFront viewer ACM certificate ARN. The Core origin uses automated DNS-01 ACME on-host."
  value = {
    frontend = try(aws_acm_certificate.frontend[0].arn, null)
  }
}

output "service_instance_id" {
  description = "Service EC2 ID for SSM Session Manager and deployment."
  value       = try(aws_instance.service[0].id, null)
}

output "trading_instance_id" {
  description = "Trading EC2 ID for SSM deployment and diagnostics."
  value       = try(aws_instance.trading[0].id, null)
}

output "backtest_autoscaling_group" {
  description = "Scale-to-zero Backtest worker Auto Scaling Group."
  value       = try(aws_autoscaling_group.backtest[0].name, null)
}

output "rds_endpoint" {
  description = "Private RDS endpoint, reachable only from the two EC2 security groups."
  value       = aws_db_instance.this.address
}

output "rds_master_secret_arn" {
  description = "AWS-managed RDS master password secret ARN."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
  sensitive   = true
}

output "market_loader_secret_arn" {
  description = "Secrets Manager ARN for the Development market-loader database credentials."
  value       = aws_secretsmanager_secret.market_loader.arn
  sensitive   = true
}

output "market_data_bucket" {
  description = "Development market data bucket."
  value       = aws_s3_bucket.market_data.id
}

output "result_bucket" {
  description = "Development backtest and performance result bucket."
  value       = try(aws_s3_bucket.results[0].id, null)
}

output "frontend_bucket" {
  description = "Private frontend artifact bucket served only through CloudFront OAC."
  value       = try(aws_s3_bucket.frontend[0].id, null)
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution used for frontend and application ingress."
  value       = try(aws_cloudfront_distribution.frontend[0].id, null)
}

output "queue_urls" {
  description = "Durable backtest queue URLs keyed by lane."
  value       = { for key, queue in aws_sqs_queue.backtest : key => queue.url }
}

output "queue_dlq_urls" {
  description = "Durable backtest dead-letter queue URLs keyed by lane."
  value       = { for key, queue in aws_sqs_queue.backtest_dlq : key => queue.url }
}

output "cache_endpoint" {
  description = "Private TLS-only Valkey Serverless endpoint."
  value       = try(aws_elasticache_serverless_cache.this[0].endpoint[0].address, null)
}

output "core_elastic_ip" {
  description = "Fixed Core origin IPv4 address. Inbound is restricted to the CloudFront origin-facing prefix list."
  value       = try(aws_eip.service[0].public_ip, null)
}

output "ecr_repository_urls" {
  description = "ECR repository URLs keyed by deployable component."
  value       = { for name, repository in aws_ecr_repository.this : name => repository.repository_url }
}
