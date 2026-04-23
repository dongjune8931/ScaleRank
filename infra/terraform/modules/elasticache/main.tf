# ──────────────────────────────────────────────────────────────────────────────
# Security Group
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_security_group" "redis" {
  name        = "${var.project_name}-redis-sg"
  description = "Allow Redis access from EKS nodes"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis from EKS nodes"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.node_security_group_id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-redis-sg"
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# ElastiCache Subnet Group
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_elasticache_subnet_group" "this" {
  name        = "${var.project_name}-redis-subnet-group"
  subnet_ids  = var.private_subnet_ids
  description = "Subnet group for ${var.project_name} Redis"

  tags = {
    Name = "${var.project_name}-redis-subnet-group"
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# ElastiCache Cluster (Redis single node)
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_elasticache_cluster" "this" {
  cluster_id           = "${var.project_name}-redis"
  engine               = "redis"
  engine_version       = "7.1"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  subnet_group_name    = aws_elasticache_subnet_group.this.name
  security_group_ids   = [aws_security_group.redis.id]
  port                 = 6379

  tags = {
    Name = "${var.project_name}-redis"
  }
}
