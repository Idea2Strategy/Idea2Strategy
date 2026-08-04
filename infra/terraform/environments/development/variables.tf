variable "aws_region" {
  description = "AWS region for Development."
  type        = string
  default     = "ap-northeast-2"
}

variable "aws_profile" {
  description = "Local AWS CLI profile. CI can override this value."
  type        = string
  default     = "idea2strategy-terraform"
}

variable "expected_aws_account_id" {
  description = "Exact AWS account allowed for this Development stack. Required for the full phase."
  type        = string
  default     = ""

  validation {
    condition     = var.expected_aws_account_id == "" || can(regex("^[0-9]{12}$", var.expected_aws_account_id))
    error_message = "expected_aws_account_id must be empty or an exact 12-digit AWS account ID."
  }
}

variable "development_iam_user_names" {
  description = "IAM users who receive MFA-protected Development application access. Login profiles and passwords remain outside Terraform."
  type        = set(string)
  default = [
    "SeoDongWi",
    "hjcud",
    "hoyow",
    "kcrmin",
    "pjy"
  ]
}

variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string
  default     = "idea2strategy"
}

variable "environment" {
  description = "Environment name. This root intentionally supports Development only."
  type        = string
  default     = "dev"

  validation {
    condition     = var.environment == "dev"
    error_message = "This Terraform root may create only the dev environment."
  }
}

variable "deployment_phase" {
  description = "Development rollout phase. market_data_bootstrap creates only historical-data loading prerequisites; full adds the public service stack."
  type        = string
  default     = "market_data_bootstrap"

  validation {
    condition     = contains(["market_data_bootstrap", "full"], var.deployment_phase)
    error_message = "deployment_phase must be market_data_bootstrap or full."
  }
}

variable "vpc_cidr" {
  description = "Development VPC CIDR."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Two public subnet CIDRs used only by the ALB and managed egress."
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Exactly two public subnet CIDRs are required."
  }
}

variable "private_app_subnet_cidrs" {
  description = "Two private application subnet CIDRs used by the three runtime hosts and managed cache."
  type        = list(string)
  default     = ["10.20.4.0/24", "10.20.5.0/24"]

  validation {
    condition     = length(var.private_app_subnet_cidrs) == 2
    error_message = "Exactly two private application subnet CIDRs are required."
  }
}

variable "nat_gateway_mode" {
  description = "Development egress topology. single minimizes cost; per_az avoids a cross-AZ egress dependency."
  type        = string
  default     = "single"

  validation {
    condition     = contains(["single", "per_az"], var.nat_gateway_mode)
    error_message = "nat_gateway_mode must be single or per_az."
  }
}

variable "private_db_subnet_cidrs" {
  description = "Two private DB subnet CIDRs used by the RDS subnet group."
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.11.0/24"]

  validation {
    condition     = length(var.private_db_subnet_cidrs) == 2
    error_message = "Exactly two private DB subnet CIDRs are required."
  }
}

variable "service_instance_type" {
  description = "Initial service EC2 measurement size."
  type        = string
  default     = "t3.small"
}

variable "trading_instance_type" {
  description = "Initial market-gateway and trading-worker EC2 measurement size."
  type        = string
  default     = "t3.small"
}

variable "batch_instance_type" {
  description = "Initial batch and backtest EC2 measurement size."
  type        = string
  default     = "m7i-flex.large"
}

variable "service_root_volume_gib" {
  description = "Encrypted gp3 root volume size for the service EC2."
  type        = number
  default     = 30

  validation {
    condition     = var.service_root_volume_gib >= 8
    error_message = "service_root_volume_gib must be at least 8 GiB."
  }
}

variable "batch_root_volume_gib" {
  description = "Encrypted gp3 root volume size for batch staging and temporary Parquet files."
  type        = number
  default     = 100

  validation {
    condition     = var.batch_root_volume_gib >= 30
    error_message = "batch_root_volume_gib must be at least 30 GiB."
  }
}

variable "batch_swap_gib" {
  description = "Swap file size that keeps host management agents responsive during batch memory pressure."
  type        = number
  default     = 4

  validation {
    condition     = var.batch_swap_gib >= 2 && var.batch_swap_gib <= 16
    error_message = "batch_swap_gib must be between 2 and 16 GiB."
  }
}

variable "service_target_port" {
  description = "Caddy target port reached only from the ALB security group."
  type        = number
  default     = 8080
}

variable "backtest_internal_port" {
  description = "Private Backtest Spring port reached only from the service EC2 security group."
  type        = number
  default     = 8081
}

variable "trading_internal_port" {
  description = "Private market gateway port reached only by approved application runtimes."
  type        = number
  default     = 8090
}

variable "frontend_domain_name" {
  description = "Public hostname served by CloudFront."
  type        = string
  default     = "dev.ideatostrategy.com"
}

variable "origin_domain_name" {
  description = "Private-to-CloudFront ALB origin hostname."
  type        = string
  default     = "origin.dev.ideatostrategy.com"
}

variable "domain_name" {
  description = "Authoritative domain to move to Route 53 after existing records are copied."
  type        = string
  default     = "ideatostrategy.com"
}

variable "service_domain_name" {
  description = "Public Development service hostname."
  type        = string
  default     = "dev.ideatostrategy.com"
}

variable "existing_hosted_zone_id" {
  description = "Existing Route 53 Hosted Zone ID. Empty creates a new zone without changing registrar delegation."
  type        = string
  default     = ""
}

variable "enable_https" {
  description = "Enable ACM validation, HTTPS listener, and HTTP redirect after Route 53 delegation is complete."
  type        = bool
  default     = false
}

variable "cache_node_type" {
  description = "Cost-controlled Development Valkey node type."
  type        = string
  default     = "cache.t4g.micro"
}

variable "cache_engine_version" {
  description = "AWS-supported Valkey engine version."
  type        = string
  default     = "8.0"
}

variable "cache_automatic_failover" {
  description = "Create a second cache node and enable automatic failover. Keep false for low-cost Development."
  type        = bool
  default     = false
}

variable "queue_visibility_timeout_seconds" {
  description = "Visibility timeout for durable worker queues."
  type        = number
  default     = 900
}

variable "queue_max_receive_count" {
  description = "Receive attempts before SQS moves a message to its DLQ."
  type        = number
  default     = 5
}

variable "rds_instance_class" {
  description = "Initial low-cost RDS measurement size."
  type        = string
  default     = "db.t4g.micro"
}

variable "rds_allocated_storage_gib" {
  description = "Initial RDS gp3 storage."
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage_gib" {
  description = "RDS storage autoscaling ceiling."
  type        = number
  default     = 100
}

variable "rds_backup_retention_days" {
  description = "Automatic backup and point-in-time recovery retention."
  type        = number
  default     = 7
}

variable "rds_deletion_protection" {
  description = "Protect Development RDS against accidental deletion."
  type        = bool
  default     = true
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch application and host log retention."
  type        = number
  default     = 14
}

variable "enable_waf" {
  description = "Attach a minimal CloudFront WAF policy before public Development access."
  type        = bool
  default     = true
}

variable "waf_rate_limit" {
  description = "Maximum requests from one IP in a five-minute WAF evaluation window."
  type        = number
  default     = 2000
}

variable "operations_alert_email" {
  description = "Optional operations email for SNS alarms. Subscription remains pending until confirmed."
  type        = string
  default     = ""
}

variable "monthly_budget_usd" {
  description = "Development monthly cost budget in USD."
  type        = number
  default     = 300
}

variable "container_image_digests" {
  description = "Immutable sha256 digests keyed by every deployable runtime image. Required for the full phase."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for digest in values(var.container_image_digests) : can(regex("^sha256:[0-9a-f]{64}$", digest))
    ])
    error_message = "Every container image digest must use the exact sha256:<64 lowercase hex> form."
  }
}

variable "frontend_release_id" {
  description = "Immutable frontend build/release identifier uploaded to the private frontend bucket."
  type        = string
  default     = ""
}
