output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = aws_nat_gateway.this.id
}

output "db_subnet_ids" {
  description = "Subnet IDs for RDS/ElastiCache subnet groups (2 AZs required by AWS)"
  value       = [aws_subnet.private[0].id, aws_subnet.private_db.id]
}
