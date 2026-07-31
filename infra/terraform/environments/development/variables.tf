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

variable "development_iam_user_names" {
  description = "IAM users who receive MFA-protected Development application access. Login profiles and passwords remain outside Terraform."
  type        = set(string)
  default     = ["pjy"]
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
  description = "Two public subnet CIDRs used by ALB and EC2."
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
  description = "Initial service EC2 measurement size."
  type        = string
  default     = "t3.small"
}

variable "batch_instance_type" {
  description = "Initial batch and backtest EC2 measurement size."
  type        = string
  default     = "t3.small"
}

variable "ec2_root_volume_gib" {
  description = "Encrypted gp3 root volume size for each EC2."
  type        = number
  default     = 30
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
