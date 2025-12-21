# ==============================================================================
# EKS CLUSTER SECURITY GROUP
# ==============================================================================

resource "aws_security_group" "cluster" {
  name_prefix = "${var.cluster_name}-cluster-sg"
  vpc_id      = var.vpc_id
  description = "Security group for EKS cluster control plane"

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-cluster-sg"
    Type = "EKS-Cluster"
  })
}

# ==============================================================================
# EKS NODE GROUP SECURITY GROUP
# ==============================================================================

resource "aws_security_group" "node_group" {
  name_prefix = "${var.cluster_name}-node-sg"
  vpc_id      = var.vpc_id
  description = "Security group for EKS worker nodes"

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-node-sg"
    Type = "EKS-NodeGroup"
  })
}