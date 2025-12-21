# ==============================================================================
# CLUSTER INFORMATION
# ==============================================================================

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks_cluster.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane (where kubectl connects)"
  value       = module.eks_cluster.cluster_endpoint
}

output "cluster_version" {
  description = "The Kubernetes version of the cluster"
  value       = module.eks_cluster.cluster_version
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks_cluster.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks_cluster.cluster_oidc_issuer_url
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = module.eks_cluster.cluster_arn
}

# ==============================================================================
# NETWORKING INFORMATION
# ==============================================================================

output "vpc_id" {
  description = "ID of the VPC where the cluster is deployed"
  value       = module.networking.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.networking.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets (where worker nodes live)"
  value       = module.networking.private_subnet_ids
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets (for load balancers)"
  value       = module.networking.public_subnet_ids
}

# ==============================================================================
# SECURITY INFORMATION
# ==============================================================================

output "cluster_security_group_id" {
  description = "ID of the cluster security group"
  value       = module.security.cluster_security_group_id
}

output "node_group_security_group_id" {
  description = "ID of the node group security group"
  value       = module.security.node_group_security_group_id
}

# ==============================================================================
# NODE GROUP INFORMATION
# ==============================================================================

output "node_groups" {
  description = "Map of node group attributes"
  value       = module.eks_cluster.node_groups
}

# ==============================================================================
# KUBECTL CONFIGURATION COMMAND
# ==============================================================================

output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks_cluster.cluster_name}"
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for IRSA"
  value       = module.eks_cluster.oidc_provider_arn
}

# Comment out until platform_ingress module is properly configured
# output "aws_load_balancer_controller_role_arn" {
#   description = "ARN of the AWS Load Balancer Controller IAM role"
#   value       = module.platform_ingress.aws_load_balancer_controller_role_arn
# }