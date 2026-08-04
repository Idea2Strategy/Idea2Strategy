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
  description = "Development rollout phase. market_data_bootstrap preserves historical-data prerequisites; full adds the public service stack after the separate artifact-foundation root is applied."
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
  description = "Two public application subnets. Runtime security groups remain egress-only except the CloudFront-restricted Core origin."
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Exactly two public subnet CIDRs are required."
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
  description = "Core EC2 size. Increase only after memory, GC, latency and CPU-credit evidence."
  type        = string
  default     = "t4g.medium"
}

variable "trading_instance_type" {
  description = "On-Demand ARM64 trading runtime size."
  type        = string
  default     = "c7g.xlarge"
}

variable "backtest_instance_type" {
  description = "Scale-to-zero ARM64 backtest worker size."
  type        = string
  default     = "t4g.medium"
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

variable "trading_root_volume_gib" {
  description = "Encrypted gp3 root volume size for the trading runtime."
  type        = number
  default     = 20

  validation {
    condition     = var.trading_root_volume_gib >= 8
    error_message = "trading_root_volume_gib must be at least 8 GiB."
  }
}

variable "backtest_root_volume_gib" {
  description = "Encrypted gp3 scratch volume for streaming backtests; durable recovery remains in S3 and PostgreSQL."
  type        = number
  default     = 40

  validation {
    condition     = var.backtest_root_volume_gib >= 20
    error_message = "backtest_root_volume_gib must be at least 20 GiB."
  }
}

variable "service_target_port" {
  description = "Core HTTPS origin port reached only from the CloudFront origin-facing prefix list."
  type        = number
  default     = 443
}

variable "frontend_domain_name" {
  description = "Public hostname served by CloudFront."
  type        = string
  default     = "ideatostrategy.com"
}

variable "origin_domain_name" {
  description = "Public DNS name for the fixed-EIP Core HTTPS origin. The security group permits CloudFront origin-facing addresses only."
  type        = string
  default     = "origin.ideatostrategy.com"
}

variable "domain_name" {
  description = "Authoritative domain to move to Route 53 after existing records are copied."
  type        = string
  default     = "ideatostrategy.com"
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
  default     = "db.t4g.small"
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
  default     = 180
}

variable "alpaca_api_key_secret_name" {
  description = "Existing Secrets Manager secret containing the ALPACA_API_KEY JSON field. Terraform reads metadata only."
  type        = string
  default     = "idea2strategy-dev/backtest/alpaca"
}

variable "alpaca_secret_key_secret_name" {
  description = "Existing Secrets Manager secret containing the ALPACA_SECRET_KEY JSON field. Terraform reads metadata only."
  type        = string
  default     = "idea2strategy-dev/backtest/alpaca-secret"
}

variable "backtest_idle_grace_minutes" {
  description = "Minimum verified idle period before a worker may set the Backtest ASG to zero."
  type        = number
  default     = 15
}

variable "pipeline_schedule_expression" {
  description = "Optional EventBridge schedule for the desired-zero pipeline task. Empty disables scheduled runs."
  type        = string
  default     = ""
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
