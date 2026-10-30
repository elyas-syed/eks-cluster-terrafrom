variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "controller_role_arn" {
  description = "Existing controller IAM role ARN from the cluster root output"
  type        = string
}

variable "chart_version" {
  description = "Controller chart version; keep aligned with the vendored IAM policy"
  type        = string
  default     = "3.6.2"
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
variable "enable_metrics_server" {
  description = "Install Metrics Server for kubectl top and HPA metrics"
  type        = bool
  default     = true
}
