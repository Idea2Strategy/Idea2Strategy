output "repository_urls" {
  description = "Immutable ECR repository URLs keyed by runtime component."
  value       = { for name, repository in aws_ecr_repository.runtime : name => repository.repository_url }
}
