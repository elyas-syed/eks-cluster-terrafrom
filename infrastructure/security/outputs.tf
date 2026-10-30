output "cluster_service_role_arn" {
  description = "ARN of the EKS cluster service role"
  value       = aws_iam_role.cluster.arn
  depends_on  = [aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy]
}

output "node_group_role_arn" {
  description = "ARN of the EKS node group role"
  value       = aws_iam_role.node_group.arn
  depends_on  = [aws_iam_role_policy_attachment.node_group_AmazonEKSWorkerNodePolicy, aws_iam_role_policy_attachment.node_group_AmazonEKS_CNI_Policy, aws_iam_role_policy_attachment.node_group_AmazonEC2ContainerRegistryReadOnly]
}

output "cluster_security_group_id" {
  description = "ID of the cluster security group"
  value       = aws_security_group.cluster.id
}

output "node_group_security_group_id" {
  description = "ID of the node group security group"
  value       = aws_security_group.node_group.id
}

# Comment out or remove OIDC outputs since we moved OIDC to compute module
# output "oidc_provider_arn" {
#   description = "ARN of the OIDC Provider for IRSA"
#   value       = aws_iam_openid_connect_provider.cluster.arn
# }

# output "oidc_provider_url" {
#   description = "URL of the OIDC Provider"
#   value       = aws_iam_openid_connect_provider.cluster.url
# }

# Remove these outputs - they're now in the IRSA module
# output "ebs_csi_driver_role_arn" {
#   description = "ARN of the EBS CSI driver IAM role"
#   value       = aws_iam_role.ebs_csi_driver.arn
# }

# output "aws_load_balancer_controller_role_arn" {
#   description = "ARN of the AWS Load Balancer Controller IAM role"
#   value       = aws_iam_role.aws_load_balancer_controller.arn
# }