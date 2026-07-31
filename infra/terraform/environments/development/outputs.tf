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
  description = "Public subnets used by ALB and EC2."
  value       = values(aws_subnet.public)[*].id
}

output "private_db_subnet_ids" {
  description = "Private subnets used only by the RDS subnet group."
  value       = values(aws_subnet.private_db)[*].id
}

output "alb_dns_name" {
  description = "Development ALB DNS name."
  value       = try(aws_lb.this[0].dns_name, null)
}

output "service_url" {
  description = "Development service URL. HTTPS becomes valid after DNS delegation and enable_https=true."
  value       = local.enable_service_stack ? (var.enable_https ? "https://${var.service_domain_name}" : "http://${var.service_domain_name}") : null
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
  description = "ACM certificate ARN. Check status with AWS CLI before enabling HTTPS."
  value       = try(aws_acm_certificate.service[0].arn, null)
}

output "service_instance_id" {
  description = "Service EC2 ID for SSM Session Manager and deployment."
  value       = try(aws_instance.service[0].id, null)
}

output "batch_instance_id" {
  description = "Batch EC2 ID for SSM Session Manager and deployment."
  value       = aws_instance.batch.id
}

output "batch_instance_type" {
  description = "Applied batch EC2 instance type."
  value       = aws_instance.batch.instance_type
}

output "batch_root_volume_gib" {
  description = "Applied batch EC2 root volume size in GiB."
  value       = aws_instance.batch.root_block_device[0].volume_size
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

output "ecr_repository_urls" {
  description = "ECR repository URLs keyed by deployable component."
  value       = { for name, repository in aws_ecr_repository.this : name => repository.repository_url }
}
