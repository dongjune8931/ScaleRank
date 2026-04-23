# ──────────────────────────────────────────────────────────────────────────────
# Security Group
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow MySQL access from EKS nodes"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from EKS nodes"
    from_port       = 3306
    to_port         = 3306
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
    Name = "${var.project_name}-rds-sg"
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# DB Subnet Group
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_db_subnet_group" "this" {
  name        = "${var.project_name}-db-subnet-group"
  subnet_ids  = var.private_subnet_ids
  description = "Subnet group for ${var.project_name} RDS"

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# DB Parameter Group
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_db_parameter_group" "this" {
  name        = "${var.project_name}-mysql8-params"
  family      = "mysql8.0"
  description = "Custom parameter group for ${var.project_name} MySQL 8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  tags = {
    Name = "${var.project_name}-mysql8-params"
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# RDS Instance
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_db_instance" "this" {
  identifier             = "${var.project_name}-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_type           = "gp2"
  db_name                = var.db_name
  username               = var.db_username
  password               = var.db_password
  parameter_group_name   = aws_db_parameter_group.this.name
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  multi_az               = false
  skip_final_snapshot    = true
  backup_retention_period = 7
  publicly_accessible    = false

  tags = {
    Name = "${var.project_name}-mysql"
  }
}
