# ==============================================================================
# ROOT MODULE - EKS CLUSTER INFRASTRUCTURE
# ==============================================================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
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

provider "kubernetes" {
  host                   = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks_cluster.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks_cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks_cluster.cluster_name, "--region", var.aws_region]
    }
  }
}

# ==============================================================================
# INFRASTRUCTURE MODULES
# ==============================================================================

# Networking Infrastructure
module "networking" {
  source = "./infrastructure/networking"

  cluster_name         = var.cluster_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  environment          = var.environment
  tags                 = var.tags
}

# Security Infrastructure (Basic IAM roles and security groups only)
module "security" {
  source = "./infrastructure/security"

  vpc_id       = module.networking.vpc_id
  cluster_name = var.cluster_name
  environment  = var.environment
  tags         = var.tags
  # Remove cluster_oidc_issuer_url - not needed for basic security resources

  depends_on = [module.networking]
}

# EKS Cluster
module "eks_cluster" {
  source = "./infrastructure/compute"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

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
  access_entries          = var.access_entries
  authentication_mode     = var.authentication_mode
  ebs_csi_driver_role_arn = null # Not used - EBS CSI addon created in root module

  environment = var.environment
  tags        = var.tags

  depends_on = [module.networking, module.security]
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
resource "aws_eks_addon" "ebs_csi" {
  count = contains(keys(var.cluster_addons), "aws-ebs-csi-driver") ? 1 : 0

  cluster_name                = module.eks_cluster.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = try(var.cluster_addons["aws-ebs-csi-driver"].addon_version, null)
  service_account_role_arn    = module.irsa.ebs_csi_driver_role_arn
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

# Data source to get current AWS caller identity
data "aws_caller_identity" "current" {}

# Grant cluster-admin permissions to access entry users via AWS EKS access policies
# This works with API or API_AND_CONFIG_MAP authentication mode
resource "aws_eks_access_policy_association" "cluster_admin" {
  for_each = {
    for k, v in var.access_entries : k => v
    if try(v.grant_cluster_admin, false) == true
  }

  cluster_name  = module.eks_cluster.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = each.value.principal_arn == "CURRENT_USER" ? data.aws_caller_identity.current.arn : each.value.principal_arn

  access_scope {
    type = "cluster"
  }

  depends_on = [
    module.eks_cluster,
  ]
}

# Platform Add-ons (Optional) - Commented out for initial deployment
# module "platform" {
#   source = "./platform/monitoring"
#   
#   cluster_name                = module.eks_cluster.cluster_name
#   cluster_endpoint           = module.eks_cluster.cluster_endpoint
#   cluster_certificate_authority_data = module.eks_cluster.cluster_certificate_authority_data
#   
#   environment = var.environment
#   tags       = var.tags
# }