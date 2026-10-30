# ==============================================================================
# EKS CLUSTER
# ==============================================================================

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  # VPC configuration
  vpc_config {
    subnet_ids              = concat(aws_subnet.private[*].id, aws_subnet.public[*].id)
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
    security_group_ids      = [aws_security_group.cluster.id]
  }

  # Enable logging
  enabled_cluster_log_types = var.cluster_enabled_log_types

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_cloudwatch_log_group.cluster,
  ]

  tags = {
    Name = var.cluster_name
  }
}

# ==============================================================================
# CLOUDWATCH LOG GROUP FOR EKS CLUSTER LOGS
# ==============================================================================

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 7 # Adjust as needed (1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653)

  tags = {
    Name = "${var.cluster_name}-cluster-logs"
  }
}

# ==============================================================================
# EKS ADD-ONS (Essential cluster components)
# ==============================================================================

# VPC CNI - Networking for pods
resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "vpc-cni"
  addon_version = "v1.20.0-eksbuild.1" # Updated for 1.31 compatibility

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_cluster.main]

  tags = {
    Name = "${var.cluster_name}-vpc-cni"
  }
}

# CoreDNS - DNS resolution for the cluster
resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "coredns"
  addon_version = "v1.11.4-eksbuild.14" # Latest version for K8s 1.31

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.main]

  tags = {
    Name = "${var.cluster_name}-coredns"
  }
}

# kube-proxy - Network proxy for Kubernetes services
resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "kube-proxy"
  addon_version = "v1.31.2-eksbuild.3" # Updated for 1.31 compatibility

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_cluster.main]

  tags = {
    Name = "${var.cluster_name}-kube-proxy"
  }
}

# EBS CSI Driver - For persistent storage
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.37.0-eksbuild.1" # Updated for 1.31 compatibility
  service_account_role_arn = aws_iam_role.ebs_csi.arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_cluster.main,
    aws_eks_node_group.main,
    aws_iam_role_policy_attachment.ebs_csi
  ]

  tags = {
    Name = "${var.cluster_name}-ebs-csi"
  }
}