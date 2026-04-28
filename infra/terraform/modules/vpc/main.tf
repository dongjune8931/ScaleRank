locals {
  azs = ["ap-northeast-2a"]
}

# ──────────────────────────────────────────────────────────────────────────────
# VPC
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# Internet Gateway
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# Public Subnets
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_subnet" "public" {
  count = 1

  vpc_id                  = aws_vpc.this.id
  cidr_block              = ["10.0.1.0/24"][count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "${var.project_name}-public-${local.azs[count.index]}"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# Private Subnets
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_subnet" "private" {
  count = 1

  vpc_id            = aws_vpc.this.id
  cidr_block        = ["10.0.11.0/24"][count.index]
  availability_zone = local.azs[count.index]

  tags = {
    Name                                        = "${var.project_name}-private-${local.azs[count.index]}"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# Elastic IP + NAT Gateway (single, in first public subnet)
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.project_name}-nat"
  }

  depends_on = [aws_internet_gateway.this]
}

# ──────────────────────────────────────────────────────────────────────────────
# DB-only Subnet (ap-northeast-2c) — required for RDS DB subnet group (min 2 AZs)
# No NAT route needed: RDS/Redis are internal only
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_subnet" "private_db" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "ap-northeast-2c"

  tags = {
    Name = "${var.project_name}-private-db-ap-northeast-2c"
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# Second Public Subnet (ap-northeast-2c) — ALB requires min 2 AZs for internet-facing
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_subnet" "public_alb" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "${var.project_name}-public-ap-northeast-2c"
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_route_table_association" "public_alb" {
  subnet_id      = aws_subnet.public_alb.id
  route_table_id = aws_route_table.public.id
}

# ──────────────────────────────────────────────────────────────────────────────
# Route Tables
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.project_name}-rt-public"
  }
}

resource "aws_route_table_association" "public" {
  count = 1

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = {
    Name = "${var.project_name}-rt-private"
  }
}

resource "aws_route_table_association" "private" {
  count = 1

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
