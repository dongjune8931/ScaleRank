output "cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  description = "RDS MySQL endpoint"
  value       = module.rds.db_endpoint
}

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = module.elasticache.redis_endpoint
}

output "score_service_repo_url" {
  description = "ECR repository URL for score-service"
  value       = module.ecr.score_service_repo_url
}

output "ranking_service_repo_url" {
  description = "ECR repository URL for ranking-service"
  value       = module.ecr.ranking_service_repo_url
}

output "web_repo_url" {
  description = "ECR repository URL for web"
  value       = module.ecr.web_repo_url
}

output "bastion_ip" {
  description = "Bastion host public IP address"
  value       = module.bastion.bastion_public_ip
}
