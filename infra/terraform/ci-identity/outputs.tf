output "github_deploy_role_arn" {
  description = "Role assumed by the protected GitHub development Environment through OIDC."
  value       = aws_iam_role.github_deploy.arn
}
