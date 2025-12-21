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

variable "node_groups" {
  description = "Map of EKS managed node group definitions"
  type = map(object({
    instance_types             = list(string)
    capacity_type              = optional(string)
    ami_type                   = optional(string)
    disk_size                  = optional(number)
    min_size                   = number
    max_size                   = number
    desired_size               = number
    use_custom_launch_template = optional(bool, false) # Add this line
  }))
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
    kubernetes_groups = optional(list(string))
    principal_arn     = string
    type              = optional(string, "STANDARD")
    user_name         = optional(string)
  }))
  default = {}
}

variable "authentication_mode" {
  description = "The authentication mode for the cluster"
  type        = string
  default     = "API_AND_CONFIG_MAP"
}

variable "ebs_csi_driver_role_arn" {
  description = "ARN of the IAM role for EBS CSI driver"
  type        = string
  default     = null # Make it optional
}