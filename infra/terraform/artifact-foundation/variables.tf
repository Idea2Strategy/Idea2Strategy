variable "aws_region" {
  description = "AWS region for immutable Development artifacts."
  type        = string
  default     = "ap-northeast-2"
}

variable "aws_profile" {
  description = "Optional local AWS CLI profile. CI uses OIDC and leaves this empty."
  type        = string
  default     = ""
}

variable "expected_aws_account_id" {
  description = "Required AWS account guard."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_aws_account_id))
    error_message = "expected_aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "project_name" {
  description = "Resource name prefix."
  type        = string
  default     = "idea2strategy"
}

variable "environment" {
  description = "Environment name. This root intentionally supports Development only."
  type        = string
  default     = "dev"

  validation {
    condition     = var.environment == "dev"
    error_message = "This Terraform root may create only the dev artifact foundation."
  }
}
