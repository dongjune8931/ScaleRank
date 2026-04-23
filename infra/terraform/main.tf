terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"

  default_tags {
    tags = {
      Project = var.project_name
    }
  }
}

data "aws_eks_cluster" "this" {
  name = module.eks.cluster_name

  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name

  depends_on = [module.eks]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# VPC
# ──────────────────────────────────────────────────────────────────────────────
module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  cluster_name = var.cluster_name
}

# ──────────────────────────────────────────────────────────────────────────────
# EKS
# ──────────────────────────────────────────────────────────────────────────────
module "eks" {
  source = "./modules/eks"

  project_name       = var.project_name
  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
}

# ──────────────────────────────────────────────────────────────────────────────
# RDS
# ──────────────────────────────────────────────────────────────────────────────
module "rds" {
  source = "./modules/rds"

  project_name            = var.project_name
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  node_security_group_id  = module.eks.cluster_security_group_id
  db_name                 = var.db_name
  db_username             = var.db_username
  db_password             = var.db_password
}

# ──────────────────────────────────────────────────────────────────────────────
# ElastiCache
# ──────────────────────────────────────────────────────────────────────────────
module "elasticache" {
  source = "./modules/elasticache"

  project_name           = var.project_name
  vpc_id                 = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  node_security_group_id = module.eks.cluster_security_group_id
}

# ──────────────────────────────────────────────────────────────────────────────
# ECR
# ──────────────────────────────────────────────────────────────────────────────
module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
}

# ──────────────────────────────────────────────────────────────────────────────
# Bastion
# ──────────────────────────────────────────────────────────────────────────────
module "bastion" {
  source = "./modules/bastion"

  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  public_subnet_id  = module.vpc.public_subnet_ids[0]
  key_pair_name     = var.bastion_key_pair_name
}

# ──────────────────────────────────────────────────────────────────────────────
# AWS Load Balancer Controller
# ──────────────────────────────────────────────────────────────────────────────
module "alb_controller" {
  source = "./modules/alb_controller"

  project_name       = var.project_name
  cluster_name       = module.eks.cluster_name
  vpc_id             = module.vpc.vpc_id
  oidc_provider_arn  = module.eks.oidc_provider_arn
  oidc_provider_url  = module.eks.oidc_provider_url

  depends_on = [module.eks]
}

# ──────────────────────────────────────────────────────────────────────────────
# ArgoCD
# ──────────────────────────────────────────────────────────────────────────────
module "argocd" {
  source = "./modules/argocd"

  project_name = var.project_name
  cluster_name = module.eks.cluster_name

  depends_on = [module.alb_controller]
}

# ──────────────────────────────────────────────────────────────────────────────
# Cluster Autoscaler
# ──────────────────────────────────────────────────────────────────────────────
module "cluster_autoscaler" {
  source = "./modules/cluster_autoscaler"

  project_name      = var.project_name
  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  depends_on = [module.eks]
}

# ──────────────────────────────────────────────────────────────────────────────
# Monitoring (Prometheus + Grafana + OTel + Jaeger)
# ──────────────────────────────────────────────────────────────────────────────
module "monitoring" {
  source = "./modules/monitoring"

  project_name           = var.project_name
  grafana_admin_password = var.grafana_admin_password

  depends_on = [module.alb_controller]
}

# ──────────────────────────────────────────────────────────────────────────────
# k6 Operator
# ──────────────────────────────────────────────────────────────────────────────
module "k6_operator" {
  source = "./modules/k6_operator"

  project_name = var.project_name

  depends_on = [module.eks]
}
