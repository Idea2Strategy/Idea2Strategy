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
}

variable "github_environment" {
  description = "Protected GitHub Actions Environment required in the OIDC subject."
  type        = string
  default     = "development"
}

variable "state_bucket_name" {
  description = "Existing Terraform state bucket. This root never creates or deletes it."
  type        = string
  default     = ""
}
