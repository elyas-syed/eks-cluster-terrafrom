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
  description = "Kubernetes minor version for the EKS cluster. Upgrade existing clusters one minor version at a time."
  type        = string
  default     = "1.37"
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
  default     = []
  validation {
    condition     = length(var.availability_zones) == 0 || length(var.availability_zones) == length(var.private_subnet_cidrs)
    error_message = "Provide one availability zone per private subnet, or leave availability_zones empty for discovery."
  }
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
  validation {
    condition     = length(var.private_subnet_cidrs) >= 2 && length(var.private_subnet_cidrs) == length(var.public_subnet_cidrs)
    error_message = "Provide matching public/private subnet lists across at least two availability zones."
  }
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
  description = "Enable public API server endpoint (requires explicit allowed CIDRs)"
  type        = bool
  default     = false
  validation {
    condition     = var.cluster_endpoint_private_access || var.cluster_endpoint_public_access
    error_message = "Enable at least one cluster endpoint."
  }
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks that can access the public API server endpoint"
  type        = list(string)
  default     = []
  validation {
    condition     = !var.cluster_endpoint_public_access || (length(var.cluster_endpoint_public_access_cidrs) > 0 && alltrue([for cidr in var.cluster_endpoint_public_access_cidrs : can(cidrnetmask(cidr)) && cidr != "0.0.0.0/0"]))
    error_message = "Public API access requires explicit IPv4 CIDRs narrower than 0.0.0.0/0."
  }
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
    ami_type       = optional(string, "AL2023_x86_64_STANDARD") # AL2023 required for Kubernetes 1.33+
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
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      ami_type       = "AL2023_x86_64_STANDARD" # AL2023 required for Kubernetes 1.33+
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
  validation {
    condition     = alltrue([for group in values(var.node_groups) : group.min_size >= 0 && group.min_size <= group.desired_size && group.desired_size <= group.max_size && group.max_size >= 1])
    error_message = "Node group sizes must satisfy 0 <= min_size <= desired_size <= max_size, with max_size >= 1."
  }
  validation {
    condition     = alltrue([for group in values(var.node_groups) : !group.use_custom_launch_template || group.launch_template_name != null])
    error_message = "An existing launch_template_name is required when use_custom_launch_template is true."
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
    vpc-cni                = {}
    coredns                = {}
    kube-proxy             = {}
    aws-ebs-csi-driver     = {}
    eks-pod-identity-agent = {}
  }
  validation {
    condition     = alltrue([for name in keys(var.cluster_addons) : contains(["vpc-cni", "coredns", "kube-proxy", "aws-ebs-csi-driver", "eks-pod-identity-agent"], name)])
    error_message = "Supported add-ons: vpc-cni, coredns, kube-proxy, aws-ebs-csi-driver, eks-pod-identity-agent."
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
    access_policy = optional(object({
      policy_name = string
      access_scope = optional(object({
        type       = optional(string, "cluster")
        namespaces = optional(list(string))
      }))
    }))
  }))
  default = {}
  validation {
    condition     = var.bootstrap_cluster_creator_admin_permissions || length(var.access_entries) > 0
    error_message = "Configure access_entries explicitly, or enable bootstrap_cluster_creator_admin_permissions."
  }
  validation {
    condition     = length(var.access_entries) == 0 || var.authentication_mode != "CONFIG_MAP"
    error_message = "Access entries require API or API_AND_CONFIG_MAP authentication."
  }
}

# Authentication mode
variable "authentication_mode" {
  description = "The authentication mode for the cluster"
  type        = string
  default     = "API"

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
variable "cluster_log_retention_days" {
  description = "CloudWatch control-plane log retention in days"
  type        = number
  default     = 30
}

variable "bootstrap_cluster_creator_admin_permissions" {
  description = "Grant permanent bootstrap admin to the creator. Set true when upgrading clusters created with the previous default to avoid replacement."
  type        = bool
  default     = false
}

variable "pod_identity_associations" {
  description = "Workload service accounts mapped to existing IAM roles that trust pods.eks.amazonaws.com"
  type = map(object({
    namespace       = string
    service_account = string
    role_arn        = string
  }))
  default = {}
  validation {
    condition     = length(var.pod_identity_associations) == 0 || contains(keys(var.cluster_addons), "eks-pod-identity-agent")
    error_message = "Pod Identity associations require the eks-pod-identity-agent add-on."
  }
}
