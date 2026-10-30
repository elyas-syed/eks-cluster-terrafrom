# ==============================================================================
# ROOT MODULE - EKS CLUSTER INFRASTRUCTURE
# ==============================================================================

terraform {
  required_version = ">= 1.10, < 2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# ==============================================================================
# PROVIDERS CONFIGURATION
# ==============================================================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

# ==============================================================================
# INFRASTRUCTURE MODULES
# ==============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

# Networking Infrastructure
module "networking" {
  source = "./infrastructure/networking"

  cluster_name         = var.cluster_name
  vpc_cidr             = var.vpc_cidr
  enable_flow_logs     = var.enable_flow_logs
  availability_zones   = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, length(var.private_subnet_cidrs))
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  environment          = var.environment
  tags                 = var.tags
}

# Security Infrastructure (Basic IAM roles and security groups only)
module "security" {
  source = "./infrastructure/security"

  vpc_id       = module.networking.vpc_id
  vpc_cidr     = var.vpc_cidr
  cluster_name = var.cluster_name
  environment  = var.environment
  tags         = var.tags

  depends_on = [module.networking]
}

# EKS Cluster
module "eks_cluster" {
  source = "./infrastructure/compute"

  cluster_name               = var.cluster_name
  cluster_version            = var.cluster_version
  cluster_enabled_log_types  = var.cluster_enabled_log_types
  cluster_log_retention_days = var.cluster_log_retention_days
  cluster_kms_key_arn        = var.cluster_kms_key_arn
  cluster_log_kms_key_arn    = var.cluster_log_kms_key_arn

  vpc_id                               = module.networking.vpc_id
  private_subnet_ids                   = module.networking.private_subnet_ids
  public_subnet_ids                    = module.networking.public_subnet_ids
  cluster_endpoint_private_access      = var.cluster_endpoint_private_access
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  cluster_service_role_arn     = module.security.cluster_service_role_arn
  node_group_role_arn          = module.security.node_group_role_arn
  cluster_security_group_id    = module.security.cluster_security_group_id
  node_group_security_group_id = module.security.node_group_security_group_id

  # Enhanced features
  node_groups = var.node_groups
  # Filter out EBS CSI driver - it's created separately in root module after IRSA
  cluster_addons = {
    for k, v in var.cluster_addons : k => v if k != "aws-ebs-csi-driver"
  }
  pod_identity_associations                   = var.pod_identity_associations
  access_entries                              = var.access_entries
  authentication_mode                         = var.authentication_mode
  bootstrap_cluster_creator_admin_permissions = var.bootstrap_cluster_creator_admin_permissions

  environment = var.environment
  tags        = var.tags
}

# IRSA (IAM Roles for Service Accounts) - Created after EKS cluster
module "irsa" {
  source = "./infrastructure/security/irsa"

  cluster_name            = var.cluster_name
  cluster_oidc_issuer_url = module.eks_cluster.cluster_oidc_issuer_url
  environment             = var.environment
  tags                    = var.tags

  depends_on = [module.eks_cluster]
}

# EBS CSI Addon - Created after IRSA to avoid circular dependency
# This addon needs the IAM role from IRSA module
data "aws_eks_addon_version" "ebs_csi" {
  count              = contains(keys(var.cluster_addons), "aws-ebs-csi-driver") && try(var.cluster_addons["aws-ebs-csi-driver"].addon_version, null) == null ? 1 : 0
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = var.cluster_version
  most_recent        = false
}

resource "aws_eks_addon" "ebs_csi" {
  count = contains(keys(var.cluster_addons), "aws-ebs-csi-driver") ? 1 : 0

  cluster_name                = module.eks_cluster.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = var.cluster_addons["aws-ebs-csi-driver"].addon_version != null ? var.cluster_addons["aws-ebs-csi-driver"].addon_version : data.aws_eks_addon_version.ebs_csi[0].version
  service_account_role_arn    = coalesce(var.cluster_addons["aws-ebs-csi-driver"].service_account_role_arn, module.irsa.ebs_csi_driver_role_arn)
  configuration_values        = var.cluster_addons["aws-ebs-csi-driver"].configuration_values
  resolve_conflicts_on_create = try(var.cluster_addons["aws-ebs-csi-driver"].resolve_conflicts_on_create, "OVERWRITE")
  resolve_conflicts_on_update = try(var.cluster_addons["aws-ebs-csi-driver"].resolve_conflicts_on_update, "OVERWRITE")

  depends_on = [
    module.eks_cluster,
    module.irsa,
  ]

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-ebs-csi-driver"
  })
}

# ==============================================================================
# EKS ACCESS POLICY ASSOCIATIONS FOR ACCESS ENTRIES
# ==============================================================================

# Preserve existing policy associations when ownership moves into compute.
moved {
  from = aws_eks_access_policy_association.cluster_admin
  to   = module.eks_cluster.aws_eks_access_policy_association.cluster_admin
}

# Kubernetes/Helm components are applied separately from platform/ingress.
