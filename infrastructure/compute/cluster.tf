# ==============================================================================
# EKS CLUSTER
# ==============================================================================

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = var.cluster_service_role_arn

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
    security_group_ids      = [var.cluster_security_group_id]
  }

  # EKS 1.28+ enables envelope encryption by default. A customer-managed key
  # is optional and must have an appropriate EKS key policy.
  dynamic "encryption_config" {
    for_each = var.cluster_kms_key_arn == null ? [] : [var.cluster_kms_key_arn]
    content {
      resources = ["secrets"]
      provider { key_arn = encryption_config.value }
    }
  }

  # Authentication mode for access entries
  access_config {
    authentication_mode                         = var.authentication_mode
    bootstrap_cluster_creator_admin_permissions = var.bootstrap_cluster_creator_admin_permissions
  }

  # Enable logging
  enabled_cluster_log_types = var.cluster_enabled_log_types

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  depends_on = [
    aws_cloudwatch_log_group.cluster,
  ]

  tags = merge(var.tags, {
    Name = var.cluster_name
  })
}

# ==============================================================================
# CLOUDWATCH LOG GROUP FOR EKS CLUSTER LOGS
# ==============================================================================

# CloudWatch Log Group for EKS cluster
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cluster_log_retention_days
  kms_key_id        = var.cluster_log_kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-cluster-logs"
  })
}