# ==============================================================================
# EKS ADDONS MANAGEMENT
# ==============================================================================

# VPC CNI - Networking for pods
resource "aws_eks_addon" "vpc_cni" {
  count = contains(keys(var.cluster_addons), "vpc-cni") ? 1 : 0

  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  addon_version               = try(var.cluster_addons["vpc-cni"].addon_version, null)
  resolve_conflicts_on_create = try(var.cluster_addons["vpc-cni"].resolve_conflicts_on_create, "OVERWRITE")
  resolve_conflicts_on_update = try(var.cluster_addons["vpc-cni"].resolve_conflicts_on_update, "OVERWRITE")
  service_account_role_arn    = try(var.cluster_addons["vpc-cni"].service_account_role_arn, null)
  configuration_values        = try(var.cluster_addons["vpc-cni"].configuration_values, null)

  depends_on = [aws_eks_cluster.main]

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-vpc-cni"
  })
}

# CoreDNS - DNS resolution for the cluster
resource "aws_eks_addon" "coredns" {
  count = contains(keys(var.cluster_addons), "coredns") ? 1 : 0

  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  addon_version               = try(var.cluster_addons["coredns"].addon_version, null)
  resolve_conflicts_on_create = try(var.cluster_addons["coredns"].resolve_conflicts_on_create, "OVERWRITE")
  resolve_conflicts_on_update = try(var.cluster_addons["coredns"].resolve_conflicts_on_update, "OVERWRITE")
  service_account_role_arn    = try(var.cluster_addons["coredns"].service_account_role_arn, null)
  configuration_values        = try(var.cluster_addons["coredns"].configuration_values, null)

  depends_on = [aws_eks_node_group.main]

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-coredns"
  })
}

# kube-proxy - Network proxy for Kubernetes services
resource "aws_eks_addon" "kube_proxy" {
  count = contains(keys(var.cluster_addons), "kube-proxy") ? 1 : 0

  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  addon_version               = try(var.cluster_addons["kube-proxy"].addon_version, null)
  resolve_conflicts_on_create = try(var.cluster_addons["kube-proxy"].resolve_conflicts_on_create, "OVERWRITE")
  resolve_conflicts_on_update = try(var.cluster_addons["kube-proxy"].resolve_conflicts_on_update, "OVERWRITE")
  service_account_role_arn    = try(var.cluster_addons["kube-proxy"].service_account_role_arn, null)
  configuration_values        = try(var.cluster_addons["kube-proxy"].configuration_values, null)

  depends_on = [aws_eks_cluster.main]

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-kube-proxy"
  })
}

# EBS CSI Driver - Moved to main.tf to avoid circular dependency with IRSA module
# The addon is now created in the root module after both eks_cluster and irsa modules

# # CloudWatch Observability
# resource "aws_eks_addon" "cloudwatch_observability" {
#   count = contains(keys(var.cluster_addons), "amazon-cloudwatch-observability") ? 1 : 0

#   cluster_name                = aws_eks_cluster.main.name
#   addon_name                  = "amazon-cloudwatch-observability"
#   addon_version              = try(var.cluster_addons["amazon-cloudwatch-observability"].addon_version, null)
#   resolve_conflicts_on_create = try(var.cluster_addons["amazon-cloudwatch-observability"].resolve_conflicts_on_create, "OVERWRITE")
#   resolve_conflicts_on_update = try(var.cluster_addons["amazon-cloudwatch-observability"].resolve_conflicts_on_update, "OVERWRITE")
#   service_account_role_arn   = try(var.cluster_addons["amazon-cloudwatch-observability"].service_account_role_arn, null)
#   configuration_values       = try(var.cluster_addons["amazon-cloudwatch-observability"].configuration_values, null)

#   depends_on = [aws_eks_cluster.main]

#   tags = merge(var.tags, {
#     Name = "${var.cluster_name}-cloudwatch-observability"
#   })
# }