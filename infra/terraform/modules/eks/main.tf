# ──────────────────────────────────────────────────────────────────────────────
# IAM Role – EKS Cluster
# ──────────────────────────────────────────────────────────────────────────────
data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume_role.json

  tags = {
    Name = "${var.cluster_name}-cluster-role"
  }
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ──────────────────────────────────────────────────────────────────────────────
# IAM Role – EKS Node
# ──────────────────────────────────────────────────────────────────────────────
data "aws_iam_policy_document" "node_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json

  tags = {
    Name = "${var.cluster_name}-node-role"
  }
}

resource "aws_iam_role_policy_attachment" "node_worker_policy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr_policy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_ssm_policy" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ──────────────────────────────────────────────────────────────────────────────
# Security Groups
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "EKS cluster security group"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-cluster-sg"
  }
}

resource "aws_security_group" "node" {
  name        = "${var.cluster_name}-node-sg"
  description = "EKS node security group"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow all traffic within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-node-sg"
  }
}

# Allow cluster SG to communicate with node SG
resource "aws_security_group_rule" "cluster_to_node" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
  description              = "Allow inbound from cluster SG"
}

resource "aws_security_group_rule" "node_to_cluster" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
  description              = "Allow HTTPS from node SG"
}

# ──────────────────────────────────────────────────────────────────────────────
# EKS Cluster
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.cluster_subnet_ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
  ]

  tags = {
    Name = var.cluster_name
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# OIDC Provider (for IRSA)
# ──────────────────────────────────────────────────────────────────────────────
data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = {
    Name = "${var.cluster_name}-oidc"
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# Node Group – general (t3.small + t3.medium, SPOT)
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_eks_node_group" "general" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-general"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids

  capacity_type  = "SPOT"
  ami_type       = "AL2023_x86_64_STANDARD"
  instance_types = ["t3.small", "t3.medium"]

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 6
  }

  labels = {
    role = "general"
  }

  tags = {
    Name                                                  = "${var.cluster_name}-general"
    "k8s.io/cluster-autoscaler/enabled"                   = "true"
    "k8s.io/cluster-autoscaler/${var.cluster_name}"       = "owned"
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_ecr_policy,
    aws_iam_role_policy_attachment.node_ssm_policy,
  ]
}

# ──────────────────────────────────────────────────────────────────────────────
# Node Group – loadtest (c5.large, SPOT)
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_eks_node_group" "loadtest" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-loadtest"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids

  capacity_type  = "SPOT"
  ami_type       = "AL2023_x86_64_STANDARD"
  instance_types = ["c5.large"]

  scaling_config {
    desired_size = 0
    min_size     = 0
    max_size     = 3
  }

  labels = {
    role = "loadtest"
  }

  taint {
    key    = "role"
    value  = "loadtest"
    effect = "NO_SCHEDULE"
  }

  tags = {
    Name                                                              = "${var.cluster_name}-loadtest"
    "k8s.io/cluster-autoscaler/enabled"                              = "true"
    "k8s.io/cluster-autoscaler/${var.cluster_name}"                  = "owned"
    # Scale-from-zero: tell Cluster Autoscaler about labels/taints before nodes exist
    "k8s.io/cluster-autoscaler/node-template/label/role"            = "loadtest"
    "k8s.io/cluster-autoscaler/node-template/taint/role"            = "loadtest:NoSchedule"
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker_policy,
    aws_iam_role_policy_attachment.node_cni_policy,
    aws_iam_role_policy_attachment.node_ecr_policy,
    aws_iam_role_policy_attachment.node_ssm_policy,
  ]
}
