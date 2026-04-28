# ──────────────────────────────────────────────────────────────────────────────
# IAM Policy for Cluster Autoscaler
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_iam_policy" "cluster_autoscaler" {
  name        = "${var.project_name}-cluster-autoscaler-policy"
  description = "IAM policy for Cluster Autoscaler"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/enabled"        = "true"
            "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/${var.cluster_name}" = "owned"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeLaunchTemplates",
        ]
        Resource = "*"
      },
    ]
  })

  tags = {
    Name = "${var.project_name}-cluster-autoscaler-policy"
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# IRSA – IAM Role for Cluster Autoscaler Service Account
# ──────────────────────────────────────────────────────────────────────────────
data "aws_iam_policy_document" "cluster_autoscaler_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:kube-system:cluster-autoscaler"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster_autoscaler" {
  name               = "${var.project_name}-cluster-autoscaler-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_autoscaler_assume_role.json

  tags = {
    Name = "${var.project_name}-cluster-autoscaler-role"
  }
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  role       = aws_iam_role.cluster_autoscaler.name
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
}

# ──────────────────────────────────────────────────────────────────────────────
# Helm Release – Cluster Autoscaler
# ──────────────────────────────────────────────────────────────────────────────
resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = "9.37.0"

  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "awsRegion"
    value = "ap-northeast-2"
  }

  set {
    name  = "rbac.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.cluster_autoscaler.arn
  }

  set {
    name  = "extraArgs.scale-down-delay-after-add"
    value = "5m"
  }

  set {
    name  = "extraArgs.scale-down-unneeded-time"
    value = "3m"
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_autoscaler]
}
