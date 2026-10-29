mock_provider "aws" {
  mock_data "aws_eks_addon_version" { defaults = { version = "v1.37.0-eksbuild.1" } }
  mock_data "aws_caller_identity" {
    defaults = { arn = "arn:aws:iam::123456789012:user/test", account_id = "123456789012" }
  }
  mock_data "aws_availability_zones" {
    defaults = { names = ["us-east-1a", "us-east-1b", "us-east-1c"] }
  }
  mock_data "aws_partition" { defaults = { partition = "aws" } }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
  }
}
mock_provider "tls" {}
variables {
  aws_region                 = "us-east-1"
  access_entries             = { admin = { principal_arn = "CURRENT_USER", grant_cluster_admin = true } }
  cluster_enabled_log_types  = ["audit"]
  cluster_log_retention_days = 60
}
run "root_plan" {
  command = plan
  assert {
    condition     = output.cluster_version == "1.37"
    error_message = "The root deployment must target EKS 1.37."
  }
}
run "reject_public_world_access" {
  command = plan
  variables {
    cluster_endpoint_public_access       = true
    cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
  }
  expect_failures = [var.cluster_endpoint_public_access_cidrs]
}
run "reject_missing_access" {
  command = plan
  variables { access_entries = {} }
  expect_failures = [var.access_entries]
}
