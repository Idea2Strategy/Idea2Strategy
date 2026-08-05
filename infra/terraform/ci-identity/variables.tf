variable "aws_region" {
  type    = string
  default = "ap-northeast-2"
}

variable "aws_profile" {
  type    = string
  default = ""
}

variable "expected_aws_account_id" {
  type = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_aws_account_id))
    error_message = "expected_aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "project_name" {
  type    = string
  default = "idea2strategy"
}

variable "environment" {
  type    = string
  default = "dev"

  validation {
    condition     = var.environment == "dev"
    error_message = "This root may create only the Development CI identity."
  }
}

variable "github_repository" {
  description = "GitHub organization/repository allowed to assume the deploy role."
  type        = string
  default     = "Idea2Strategy/Idea2Strategy"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be one exact GitHub owner/repository pair."
  }
}

variable "github_repository_owner_id" {
  description = "Immutable numeric GitHub organization ID included by the configured OIDC subject template."
  type        = string
  default     = "306821097"

  validation {
    condition     = can(regex("^[1-9][0-9]{0,19}$", var.github_repository_owner_id))
    error_message = "github_repository_owner_id must be a positive numeric GitHub organization ID."
  }
}

variable "github_repository_id" {
  description = "Immutable numeric GitHub repository ID included by the configured OIDC subject template."
  type        = string
  default     = "1305830332"

  validation {
    condition     = can(regex("^[1-9][0-9]{0,19}$", var.github_repository_id))
    error_message = "github_repository_id must be a positive numeric GitHub repository ID."
  }
}

variable "github_environment" {
  description = "Protected GitHub Actions Environment required for applying the exact reviewed plan."
  type        = string
  default     = "development"
}

variable "github_plan_environment" {
  description = "Separate protected GitHub Actions Environment used for read-only planning plus scoped artifact publication."
  type        = string
  default     = "development-plan"
}

variable "state_bucket_name" {
  description = "Existing Terraform state bucket. This root never creates or deletes it."
  type        = string
  default     = ""
}
