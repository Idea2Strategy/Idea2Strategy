output "github_deploy_role_arn" {
  description = "Privileged role assumed only by the protected GitHub development Environment to apply the exact reviewed saved plan."
  value       = aws_iam_role.github_deploy.arn
}

output "github_plan_role_arn" {
  description = "Read-only planning and scoped immutable artifact publication role assumed by the separate development-plan Environment."
  value       = aws_iam_role.github_plan.arn
}
