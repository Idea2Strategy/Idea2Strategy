variable "aws_region" {
  description = "AWS region used by the Development environment."
  type        = string
  default     = "ap-northeast-2"
}

variable "aws_profile" {
  description = "Local AWS CLI profile. CI can override this value."
  type        = string
  default     = "idea2strategy-terraform"
}

variable "project_name" {
  description = "Project name used in resource names and tags."
  type        = string
  default     = "idea2strategy"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"

  validation {
    condition     = var.environment == "dev"
    error_message = "The current Terraform root may create only the dev environment."
  }
}

variable "state_bucket_name" {
  description = "Optional globally unique state bucket name. Empty uses project-environment-account-id-tfstate."
  type        = string
  default     = ""
}

variable "github_repository" {
  description = "GitHub organization/repository allowed to assume the Development deploy role."
  type        = string
  default     = "Idea2Strategy/Idea2Strategy"
}

variable "github_environment" {
  description = "Protected GitHub Actions Environment required in the OIDC subject."
  type        = string
  default     = "development"
}
