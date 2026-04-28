output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_ca" {
  description = "EKS cluster certificate authority data"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider"
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_provider_url" {
  description = "URL of the EKS OIDC provider (without https://)"
  value       = replace(aws_iam_openid_connect_provider.this.url, "https://", "")
}

output "node_role_arn" {
  description = "IAM role ARN of the EKS node group"
  value       = aws_iam_role.node.arn
}

output "cluster_security_group_id" {
  description = "EKS-managed cluster security group ID (attached to all managed nodes)"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}
