mock_provider "aws" {}
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
    condition     = aws_eks_node_group.main["general"].ami_type == "AL2023_x86_64_STANDARD"
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
