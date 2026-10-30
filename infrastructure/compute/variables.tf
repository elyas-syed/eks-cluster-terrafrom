variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "cluster_service_role_arn" {
  description = "ARN of the EKS cluster service role"
  type        = string
}

variable "node_group_role_arn" {
  description = "ARN of the EKS node group role"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "cluster_security_group_id" {
  description = "ID of the cluster security group"
  type        = string
}

variable "node_group_security_group_id" {
  description = "ID of the node group security group"
  type        = string
}

variable "cluster_endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "List of CIDR blocks that can access the public API server endpoint"
  type        = list(string)
  default     = []
}

variable "cluster_enabled_log_types" {
  description = "List of control plane logging to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

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
  validation {
    condition     = alltrue([for group in values(var.node_groups) : group.min_size >= 0 && group.min_size <= group.desired_size && group.desired_size <= group.max_size && group.max_size >= 1])
    error_message = "Node group sizes must satisfy 0 <= min_size <= desired_size <= max_size, with max_size >= 1."
  }
  validation {
    condition     = alltrue([for group in values(var.node_groups) : !group.use_custom_launch_template || group.launch_template_name != null])
    error_message = "An existing launch_template_name is required when use_custom_launch_template is true."
  }

}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "cluster_addons" {
  description = "Map of cluster addon configurations"
  type = map(object({
    addon_version               = optional(string)
    resolve_conflicts_on_create = optional(string, "OVERWRITE")
    resolve_conflicts_on_update = optional(string, "OVERWRITE")
    service_account_role_arn    = optional(string)
    configuration_values        = optional(string)
  }))
  default = {}
}

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
}

variable "authentication_mode" {
  description = "The authentication mode for the cluster"
  type        = string
  default     = "API"
}

variable "ebs_csi_driver_role_arn" {
  description = "ARN of the IAM role for EBS CSI driver"
  type        = string
  default     = null # Make it optional
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

variable "cluster_kms_key_arn" {
  description = "Optional customer-managed KMS key for API data; EKS 1.28+ encrypts with an AWS-owned key by default"
  type        = string
  default     = null
}
variable "cluster_log_kms_key_arn" {
  description = "Optional customer-managed KMS key authorized for CloudWatch Logs in the cluster region"
  type        = string
  default     = null
}
