mock_provider "aws" {}
variables {
  cluster_name         = "test-cluster"
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
  environment          = "dev"
}
run "network_defaults" {
  command = plan
  module { source = "./infrastructure/networking" }
  assert {
    condition     = alltrue([for subnet in aws_subnet.public : !subnet.map_public_ip_on_launch])
    error_message = "Public subnets must not assign public IPs to instances by default."
  }
  assert {
    condition     = aws_flow_log.rejected[0].traffic_type == "REJECT" && length(aws_nat_gateway.main) == 2
    error_message = "The default network must log rejected traffic and have an AZ-local NAT gateway per AZ."
  }
}
