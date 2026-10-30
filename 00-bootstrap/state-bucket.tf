# ==============================================================================
# S3 BUCKET FOR TERRAFORM STATE STORAGE (CONDITIONAL)
# ==============================================================================

resource "aws_s3_bucket" "terraform_state" {
  count  = var.enable_remote_state ? 1 : 0
  bucket = "${var.project_name}-terraform-state-${random_id.bucket_suffix[0].hex}"

  tags = {
    Name        = "Terraform State Bucket"
    Environment = "bootstrap"
    ManagedBy   = "Terraform"
    Purpose     = "terraform-state"
  }
}

# Generate random suffix for bucket name uniqueness
resource "random_id" "bucket_suffix" {
  count       = var.enable_remote_state ? 1 : 0
  byte_length = 4
}

# Enable versioning for state file history
resource "aws_s3_bucket_versioning" "terraform_state" {
  count  = var.enable_remote_state ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  count  = var.enable_remote_state ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.state_kms_key_arn == null ? "AES256" : "aws:kms"
      kms_master_key_id = var.state_kms_key_arn
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  count  = var.enable_remote_state ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle configuration to manage old versions
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  count  = var.enable_remote_state ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  rule {
    filter {}
    id     = "state_file_lifecycle"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
resource "aws_s3_bucket_policy" "require_tls" {
  count  = var.enable_remote_state ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.terraform_state[0].arn, "${aws_s3_bucket.terraform_state[0].arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}
