# ==============================================================================
# BOOTSTRAP OUTPUTS (CONDITIONAL)
# ==============================================================================

output "terraform_state_bucket" {
  description = "Name of the S3 bucket for Terraform state"
  value       = var.enable_remote_state ? aws_s3_bucket.terraform_state[0].bucket : null
}

output "terraform_state_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  value       = var.enable_remote_state ? aws_s3_bucket.terraform_state[0].arn : null
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = try(aws_dynamodb_table.terraform_locks[0].name, null)
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table for state locking"
  value       = try(aws_dynamodb_table.terraform_locks[0].arn, null)
}

# Backend configuration for other modules
output "backend_config" {
  description = "Backend configuration for other Terraform modules"
  value = var.enable_remote_state ? {
    bucket       = aws_s3_bucket.terraform_state[0].bucket
    region       = var.aws_region
    use_lockfile = true
    encrypt      = true
  } : null
}

output "use_remote_state" {
  description = "Whether remote state is enabled"
  value       = var.enable_remote_state
}