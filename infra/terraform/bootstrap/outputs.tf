output "state_bucket_name" {
  description = "S3 bucket name to place in environments/development/backend.hcl."
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_region" {
  description = "Region of the Terraform state bucket."
  value       = var.aws_region
}

output "development_state_key" {
  description = "Recommended Development state object key."
  value       = "idea2strategy/development/terraform.tfstate"
}

output "github_deploy_role_arn" {
  description = "Role assumed by the protected GitHub development Environment through OIDC."
  value       = aws_iam_role.github_deploy.arn
}
