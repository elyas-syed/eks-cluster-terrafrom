# ==============================================================================
# EKS ACCESS ENTRIES
# ==============================================================================

# Data source to get current AWS caller identity
data "aws_caller_identity" "current" {}

resource "aws_eks_access_entry" "main" {
  for_each = var.access_entries

  cluster_name = aws_eks_cluster.main.name
  # Use current caller identity if principal_arn is "CURRENT_USER" or use provided ARN
  principal_arn     = local.access_principals[each.key]
  kubernetes_groups = try(each.value.kubernetes_groups, null)
  type              = try(each.value.type, "STANDARD")
  user_name         = try(each.value.user_name, null)

  depends_on = [aws_eks_cluster.main]

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-${each.key}-access-entry"
  })
}
# STS session ARNs are not valid EKS access principals. Resolve the persistent
# IAM role ARN, including its path, instead of rewriting the session string.
data "aws_iam_session_context" "current" {
  count = anytrue([for entry in values(var.access_entries) : entry.principal_arn == "CURRENT_USER"]) && strcontains(data.aws_caller_identity.current.arn, ":assumed-role/") ? 1 : 0
  arn   = data.aws_caller_identity.current.arn
}

locals {
  current_principal_arn = strcontains(data.aws_caller_identity.current.arn, ":assumed-role/") && length(data.aws_iam_session_context.current) > 0 ? data.aws_iam_session_context.current[0].issuer_arn : data.aws_caller_identity.current.arn
  access_principals     = { for name, entry in var.access_entries : name => entry.principal_arn == "CURRENT_USER" ? local.current_principal_arn : entry.principal_arn }
}

data "aws_partition" "current" {}

resource "aws_eks_access_policy_association" "cluster_admin" {
  for_each      = { for name, entry in var.access_entries : name => entry if entry.grant_cluster_admin }
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_eks_access_entry.main[each.key].principal_arn
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope { type = "cluster" }
}

resource "aws_eks_access_policy_association" "scoped" {
  for_each      = { for name, entry in var.access_entries : name => entry if entry.access_policy != null }
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_eks_access_entry.main[each.key].principal_arn
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/${each.value.access_policy.policy_name}"
  access_scope {
    type       = try(each.value.access_policy.access_scope.type, "cluster")
    namespaces = try(each.value.access_policy.access_scope.namespaces, null)
  }
}
