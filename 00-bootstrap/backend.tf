# ==============================================================================
# TERRAFORM BACKEND CONFIGURATION
# ==============================================================================

terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }

  # Note: Bootstrap uses local state initially
  # After deployment, other modules will use the S3 backend created here
}

# ==============================================================================
# AWS PROVIDER CONFIGURATION
# ==============================================================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Environment = "bootstrap"
    }
  }
}