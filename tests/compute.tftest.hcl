mock_provider "aws" {
  mock_data "aws_caller_identity" { defaults = { arn = "arn:aws:sts::123456789012:assumed-role/Admin/session" } }
  mock_data "aws_iam_session_context" { defaults = { issuer_arn = "arn:aws:iam::123456789012:role/team/Admin" } }
  mock_data "aws_partition" { defaults = { partition = "aws" } }
}
mock_provider "tls" {}

variables {
  cluster_name                 = "test-cluster"
  cluster_version              = "1.37"
  cluster_service_role_arn     = "arn:aws:iam::123456789012:role/cluster"
  node_group_role_arn          = "arn:aws:iam::123456789012:role/nodes"
  vpc_id                       = "vpc-12345678"
  private_subnet_ids           = ["subnet-12345678", "subnet-23456789"]
  public_subnet_ids            = []
  cluster_security_group_id    = "sg-12345678"
  node_group_security_group_id = "sg-23456789"
  environment                  = "dev"
  node_groups = {
    general = {
      instance_types       = ["t3.medium"]
      min_size             = 1
      max_size             = 3
      desired_size         = 2
      labels               = { workload = "test" }
      taints               = [{ key = "dedicated", value = "test", effect = "NO_SCHEDULE" }]
      force_update_version = true
      update_config        = { max_unavailable_percentage = 50 }
    }
  }
}

run "node_configuration" {
  command = plan
  module { source = "./infrastructure/compute" }
  assert {
    condition     = aws_eks_node_group.main["general"].labels["workload"] == "test"
    error_message = "Custom node labels must reach the node group."
  }
  assert {
    condition     = one(aws_eks_node_group.main["general"].taint).effect == "NO_SCHEDULE"
    error_message = "Custom node taints must reach the node group."
  }
  assert {
    condition     = aws_eks_node_group.main["general"].update_config[0].max_unavailable_percentage == 50
    error_message = "Node update limits must be preserved."
  }
  assert {
    condition     = aws_eks_node_group.main["general"].ami_type == "AL2023_x86_64_STANDARD" && aws_eks_node_group.main["general"].version == "1.37"
    error_message = "Nodes must default to AL2023."
  }
}

run "addon_version_override" {
  command = plan
  module { source = "./infrastructure/compute" }
  variables {
    cluster_addons = { vpc-cni = { addon_version = "v1.99.0-eksbuild.1" } }
  }
  assert {
    condition     = aws_eks_addon.vpc_cni[0].addon_version == "v1.99.0-eksbuild.1" && length(data.aws_eks_addon_version.compatible) == 0
    error_message = "Explicit add-on versions must bypass automatic discovery."
  }
}

run "scoped_access" {
  command = plan
  module { source = "./infrastructure/compute" }
  variables {
    access_entries = {
      admin = { principal_arn = "CURRENT_USER", grant_cluster_admin = true }
      viewer = {
        principal_arn = "arn:aws:iam::123456789012:role/Viewer"
        access_policy = {
          policy_name  = "AmazonEKSViewPolicy"
          access_scope = { type = "namespace", namespaces = ["apps"] }
        }
      }
    }
  }
  assert {
    condition     = aws_eks_access_entry.main["admin"].principal_arn == "arn:aws:iam::123456789012:role/team/Admin"
    error_message = "CURRENT_USER must resolve STS sessions to the IAM role with its path."
  }
  assert {
    condition     = aws_eks_access_policy_association.scoped["viewer"].access_scope[0].type == "namespace" && contains(aws_eks_access_policy_association.scoped["viewer"].access_scope[0].namespaces, "apps")
    error_message = "Viewer access must be restricted to the requested namespace."
  }
}

run "existing_launch_template" {
  command = plan
  module { source = "./infrastructure/compute" }
  variables {
    node_groups = {
      custom = {
        instance_types             = ["t3.medium"]
        min_size                   = 1
        max_size                   = 2
        desired_size               = 1
        use_custom_launch_template = true
        launch_template_name       = "existing-template"
        launch_template_version    = "2"
      }
    }
  }
  assert {
    condition     = length(aws_launch_template.node_group) == 0 && aws_eks_node_group.main["custom"].launch_template[0].name == "existing-template"
    error_message = "Existing launch templates must be reused without creating another template."
  }
}

run "reject_invalid_scaling" {
  command = plan
  module { source = "./infrastructure/compute" }
  variables {
    node_groups = {
      invalid = { instance_types = ["t3.medium"], min_size = 3, desired_size = 1, max_size = 2 }
    }
  }
  expect_failures = [var.node_groups]
}

run "pod_identity_and_logging" {
  command = plan
  module { source = "./infrastructure/compute" }
  variables {
    cluster_addons = { eks-pod-identity-agent = { addon_version = "v1.3.9-eksbuild.1" } }
    pod_identity_associations = {
      app = { namespace = "apps", service_account = "app", role_arn = "arn:aws:iam::123456789012:role/App" }
    }
    cluster_enabled_log_types  = ["audit"]
    cluster_log_retention_days = 60
  }
  assert {
    condition     = aws_eks_pod_identity_association.workload["app"].service_account == "app" && aws_eks_addon.pod_identity[0].addon_version == "v1.3.9-eksbuild.1"
    error_message = "Pod identity must associate the requested service account and install its agent."
  }
  assert {
    condition     = aws_cloudwatch_log_group.cluster.retention_in_days == 60 && toset(aws_eks_cluster.main.enabled_cluster_log_types) == toset(["audit"])
    error_message = "Configured logging and retention must be preserved."
  }
}
run "reject_pod_identity_without_agent" {
  command = plan
  module { source = "./infrastructure/compute" }
  variables {
    pod_identity_associations = {
      app = { namespace = "apps", service_account = "app", role_arn = "arn:aws:iam::123456789012:role/App" }
    }
  }
  expect_failures = [var.pod_identity_associations]
}
