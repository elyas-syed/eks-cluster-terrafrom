# ==============================================================================
# REQUIRED VARIABLES (users must provide these)
# ==============================================================================

variable "cluster_name" {
  description = "Name of the EKS cluster (must be unique in your AWS account)"
  type        = string
  default     = "dev-eks-cluster" # Add this line

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.cluster_name))
    error_message = "Cluster name must start with a letter and contain only letters, numbers, and hyphens."
  }
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.28"
}

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# ==============================================================================
# NETWORKING VARIABLES
# ==============================================================================

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

# ==============================================================================
# EKS CLUSTER VARIABLES
# ==============================================================================

variable "cluster_endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks that can access the public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_enabled_log_types" {
  description = "List of control plane logging to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

# ==============================================================================
# NODE GROUP VARIABLES
# ==============================================================================

# Enhanced node groups configuration
variable "node_groups" {
  description = "Map of EKS managed node group definitions"
  type = map(object({
    instance_types = list(string)
    capacity_type  = optional(string, "ON_DEMAND")
    ami_type       = optional(string, "AL2_x86_64")
    disk_size      = optional(number, 20)
    min_size       = number
    max_size       = number
    desired_size   = number

    # Advanced features from public module
    labels = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = optional(string)
      effect = string
    })), [])

    # Launch template configuration
    use_custom_launch_template = optional(bool, false)
    launch_template_name       = optional(string)
    launch_template_version    = optional(string)

    # Instance configuration
    force_update_version = optional(bool, false)
    update_config = optional(object({
      max_unavailable_percentage = optional(number, 25)
    }), {})
  }))

  default = {
    general = {
      instance_types = ["t3.micro"]
      capacity_type  = "ON_DEMAND"
      ami_type       = "AL2_x86_64"
      disk_size      = 20
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      labels = {
        "node-group"  = "general"
        "environment" = "dev"
      }
    }
  }
}

# EKS Addons configuration
variable "cluster_addons" {
  description = "Map of cluster addon configurations"
  type = map(object({
    addon_version               = optional(string)
    resolve_conflicts_on_create = optional(string, "OVERWRITE")
    resolve_conflicts_on_update = optional(string, "OVERWRITE")
    service_account_role_arn    = optional(string)
    configuration_values        = optional(string)
  }))

  default = {
    vpc-cni = {
      addon_version = "v1.15.1-eksbuild.1"
    }
    coredns = {
      addon_version = "v1.10.1-eksbuild.5"
    }
    kube-proxy = {
      addon_version = "v1.28.2-eksbuild.2"
    }
    aws-ebs-csi-driver = {
      addon_version = "v1.24.0-eksbuild.1"
    }
  }
}

# Access entries (new EKS feature)
variable "access_entries" {
  description = "Map of access entries to add to the cluster"
  type = map(object({
    kubernetes_groups   = optional(list(string))
    principal_arn       = string
    type                = optional(string, "STANDARD")
    user_name           = optional(string)
    grant_cluster_admin = optional(bool, false) # Grant cluster-admin ClusterRole via RBAC
    access_policy       = optional(object({
      policy_name = string
      access_scope = optional(object({
        type       = optional(string, "cluster")
        namespaces = optional(list(string))
      }))
    }))
  }))
  default = {}
}

# Authentication mode
variable "authentication_mode" {
  description = "The authentication mode for the cluster"
  type        = string
  default     = "API_AND_CONFIG_MAP"

  validation {
    condition     = contains(["CONFIG_MAP", "API", "API_AND_CONFIG_MAP"], var.authentication_mode)
    error_message = "Authentication mode must be CONFIG_MAP, API, or API_AND_CONFIG_MAP."
  }
}

# ==============================================================================
# TAGGING
# ==============================================================================

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default = {
    "ManagedBy" = "Terraform"
  }
}