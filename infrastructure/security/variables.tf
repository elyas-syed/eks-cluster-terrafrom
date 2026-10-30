variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
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

# Comment out or remove this variable since it's not needed for basic security resources
# variable "cluster_oidc_issuer_url" {
#   description = "OIDC issuer URL for the EKS cluster"
#   type        = string
# }
variable "vpc_cidr" {
  description = "VPC CIDR used to scope DNS egress"
  type        = string
}
