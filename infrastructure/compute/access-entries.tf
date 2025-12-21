# ==============================================================================
# EKS ACCESS ENTRIES
# ==============================================================================

# Data source to get current AWS caller identity
data "aws_caller_identity" "current" {}

resource "aws_eks_access_entry" "main" {
  for_each = var.access_entries

  cluster_name      = aws_eks_cluster.main.name
  # Use current caller identity if principal_arn is "CURRENT_USER" or use provided ARN
  principal_arn     = each.value.principal_arn == "CURRENT_USER" ? data.aws_caller_identity.current.arn : each.value.principal_arn
  kubernetes_groups = try(each.value.kubernetes_groups, null)
  type              = try(each.value.type, "STANDARD")
  user_name         = try(each.value.user_name, null)

  depends_on = [aws_eks_cluster.main]

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-${each.key}-access-entry"
  })
}