output "score_service_repo_url" {
  description = "ECR repository URL for score-service"
  value       = aws_ecr_repository.this["${var.project_name}-score-service"].repository_url
}

output "ranking_service_repo_url" {
  description = "ECR repository URL for ranking-service"
  value       = aws_ecr_repository.this["${var.project_name}-ranking-service"].repository_url
}
