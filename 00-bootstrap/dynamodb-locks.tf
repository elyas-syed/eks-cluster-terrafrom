# ==============================================================================
# DYNAMODB TABLE FOR TERRAFORM STATE LOCKING (CONDITIONAL)
# ==============================================================================

resource "aws_dynamodb_table" "terraform_locks" {
  count        = var.enable_remote_state ? 1 : 0
  name         = "${var.project_name}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform State Locks"
    Environment = "bootstrap"
    ManagedBy   = "Terraform"
    Purpose     = "terraform-locking"
  }
}