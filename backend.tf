# ==============================================================================
# TERRAFORM BACKEND CONFIGURATION - DISABLED FOR LOCAL STATE
# ==============================================================================

# Commented out for local state deployment
# terraform {
#   backend "s3" {
#     # Configuration will be provided via:
#     # 1. Backend config file: terraform init -backend-config=backend.hcl
#     # 2. Or environment variables
#     # 3. Or command line arguments
#     
#     # Example backend.hcl file:
#     # bucket         = "your-terraform-state-bucket"
#     # key            = "eks-cluster/terraform.tfstate"
#     # region         = "us-west-2"
#     # dynamodb_table = "terraform-state-locks"
#     # encrypt        = true
#   }
# }