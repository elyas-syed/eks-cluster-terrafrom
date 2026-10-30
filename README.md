# AWS EKS Cluster Terraform Module

A modular Terraform project for deploying an Amazon EKS (Elastic Kubernetes Service) cluster with VPC networking, managed node groups, IAM access, and essential add-ons. The current baseline targets Kubernetes **1.37**.

Use the repository root for new deployments. The `terraform/` directory is legacy reference code and must not be applied alongside the root. For existing clusters, read the [migration notes](docs/MIGRATION.md) before upgrading.

## Table of Contents

- [Features](#-features)
- [Architecture](#️-architecture)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Configuration](#️-configuration)
- [Deployment](#-deployment)
- [Access and Usage](#-access-and-usage)
- [Outputs](#-outputs)
- [Troubleshooting](#-troubleshooting)
- [Module Structure](#-module-structure)
- [Production Readiness](#-production-readiness)
- [Best Practices](#-best-practices)
- [Contributing](#-contributing)
- [License](#-license)
- [Resources](#-resources)
- [Support](#-support)

## ✨ Features

- **Modular Architecture**: Clean separation of concerns with dedicated modules for networking, security, and compute
- **EKS Access Entries**: Modern authentication using AWS EKS access entries with dynamic principal resolution
- **Workload Identity**: IRSA roles for EBS CSI and ingress, plus EKS Pod Identity support
- **Managed Node Groups**: Support for both on-demand and spot instances with launch templates
- **EKS Addons**: Compatible VPC CNI, CoreDNS, kube-proxy, EBS CSI, and Pod Identity Agent versions
- **Secure Defaults**: Private API access, private workers, encrypted node disks, and IMDSv2
- **CloudWatch Logging**: Control-plane logs and rejected-traffic VPC flow logs
- **Flexible Configuration**: Comprehensive variables for customization without code changes

## 🏗️ Architecture

The module is organized into the following components:

```
├── infrastructure/
│   ├── networking/          # VPC, subnets, NAT gateways, route tables
│   ├── security/           # Security groups, IAM roles, IRSA
│   └── compute/            # EKS cluster, node groups, addons, access entries
├── platform/               # Optional ingress and HPA metrics
├── 00-bootstrap/           # Terraform state backend setup
└── main.tf                 # Root module orchestrating all components
```

### Network Architecture

- **VPC**: Custom CIDR with public and private subnets across multiple availability zones
- **Public Subnets**: Internet-facing resources (NAT gateways, load balancers)
- **Private Subnets**: Worker nodes and NAT-backed outbound access
- **NAT Gateways**: High availability NAT for outbound internet access from private subnets

### Security Architecture

- **Security Groups**: Separate cluster and worker groups with scoped communication rules
- **IAM Roles**: Dedicated roles for cluster, node groups, and service accounts
- **Access Entries**: Modern EKS authentication replacing aws-auth ConfigMap
- **IRSA**: Secure integration between Kubernetes service accounts and AWS IAM

## 📋 Prerequisites

Before deploying, ensure you have:

1. **AWS credentials** with permissions to create EKS, EC2/VPC, IAM, and CloudWatch resources. Worker-node IAM policies alone are not sufficient deployment permissions. Check your account and regional quotas:
   ```bash
   aws sts get-caller-identity
   ```

2. **Terraform 1.10 or newer, below 2.0** (CI uses 1.12.2):
   ```bash
   terraform version
   ```

3. **AWS CLI v2** configured for your target account and region.

4. **kubectl** compatible with the cluster version (1.37.x for the current baseline):
   ```bash
   kubectl version --client
   ```

5. **Helm**, if you install the optional ingress and metrics stack.

6. **Network access to the cluster API** for kubectl and platform installation. The API is private by default. For laptop access, enable public access with your actual public IP followed by `/32`.

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/elyas-syed/eks-cluster-terrafrom.git
cd eks-cluster-terrafrom
```

### 2. Configure Variables

Create a `terraform.tfvars` file (this file is gitignored):

```hcl
cluster_name    = "my-eks-cluster"
cluster_version = "1.37"
aws_region      = "us-west-2"
environment     = "dev"

# Node groups configuration
node_groups = {
  general = {
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
    min_size       = 1
    max_size       = 5
    desired_size   = 2
  }
}

# Access entries - use "CURRENT_USER" for dynamic resolution
access_entries = {
  admin = {
    principal_arn       = "CURRENT_USER"
    grant_cluster_admin = true
    type                = "STANDARD"
  }
}
```

For access from your laptop, add these values to the same file and replace the example CIDR with your public IP:

```hcl
cluster_endpoint_public_access       = true
cluster_endpoint_public_access_cidrs = ["203.0.113.10/32"] # Replace before deployment
```

Alternatively, use private-only access and run tooling from a connected network. Availability zones are discovered in `aws_region` unless explicitly configured. A ready-to-edit example is available at [environments/dev.tfvars.example](environments/dev.tfvars.example).

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Review the Plan

```bash
terraform plan -var-file=terraform.tfvars -out=cluster.tfplan
```

### 5. Deploy

```bash
terraform apply cluster.tfplan
```

> **Note**: While Terraform automatically loads `terraform.tfvars` if present, explicitly specifying `-var-file` is recommended for clarity and when using multiple variable files.

Allow time for AWS to provision the control plane, nodes, and add-ons. This creates billable resources, including one NAT gateway per availability zone. Kubernetes versions are explicit; a new AWS release will not silently change the configured version.

### 6. Configure kubectl

After deployment completes, configure kubectl:

```bash
aws eks update-kubeconfig --region us-west-2 --name my-eks-cluster
```

Verify access:

```bash
kubectl get nodes
kubectl get pods -A
```

## ⚙️ Configuration

### Key Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `cluster_name` | Unique name for the EKS cluster | `"my-eks-cluster"` |
| `cluster_version` | Kubernetes minor version; current target is 1.37 | `"1.37"` |
| `aws_region` | AWS region for deployment | `"us-west-2"` |
| `access_entries` | Explicit IAM users or roles allowed to access the cluster | See below |
| `cluster_log_retention_days` | Control-plane log retention; default 30 days | `30` |
| `enable_flow_logs` | Capture rejected VPC traffic; default enabled | `true` |

### Node Groups Configuration

Node groups support both on-demand and spot instances:

```hcl
node_groups = {
  general = {
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
    min_size       = 1
    max_size       = 5
    desired_size   = 3
    disk_size      = 50
    labels = {
      "node-type" = "general"
      "workload"  = "general-purpose"
    }
  }

  spot = {
    instance_types = ["t3.medium", "t3.large"]
    capacity_type  = "SPOT"
    min_size       = 0
    max_size       = 10
    desired_size   = 2
    taints = [{
      key    = "spot-instance"
      value  = "true"
      effect = "NO_SCHEDULE"
    }]
  }
}
```

### EKS Addons

By default, AWS-recommended versions are selected for the configured Kubernetes version and region:

```hcl
cluster_addons = {
  vpc-cni                = {}
  coredns                = {}
  kube-proxy             = {}
  aws-ebs-csi-driver      = {}
  eks-pod-identity-agent = {}
}
```

Set `addon_version` explicitly when you need reproducible version pins. The full `cluster_addons` map replaces the defaults, so include every add-on you want installed.

### Access Entries

Configure cluster access using EKS access entries:

```hcl
access_entries = {
  admin = {
    principal_arn       = "CURRENT_USER"  # Dynamically resolves to current AWS caller
    grant_cluster_admin = true             # Grants cluster-admin permissions
    type                = "STANDARD"
  }

  developer = {
    principal_arn = "arn:aws:iam::123456789012:role/Developer"
    # Use access_policy for fine-grained permissions
    access_policy = {
      policy_name = "AmazonEKSViewPolicy"
      access_scope = {
        type = "namespace"
        namespaces = ["default", "development"]
      }
    }
  }
}
```

`CURRENT_USER` resolves an assumed-role session to its persistent IAM role ARN. Prefer explicit role ARNs for shared environments. New clusters disable implicit creator-admin access and use API authentication. Keep sensitive values and local variable files out of Git.

### Networking Configuration

Customize VPC and networking. Omit `availability_zones` to discover zones in the configured region; if supplied, its length must match both subnet lists:

```hcl
vpc_cidr = "10.0.0.0/16"
availability_zones = ["us-west-2a", "us-west-2b"]

public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]
```

### Cluster Endpoint Configuration

Control cluster API access:

```hcl
cluster_endpoint_private_access = true
cluster_endpoint_public_access  = true
cluster_endpoint_public_access_cidrs = ["203.0.113.10/32"] # Replace with your public IP
```

Public access is disabled by default; `0.0.0.0/0` is rejected. Private-only deployments require network connectivity from the machine running kubectl and the optional platform stack.

## 🚢 Deployment

### Standard Deployment

```bash
# Initialize
terraform init

# Plan (explicitly specify var file)
terraform plan -var-file=terraform.tfvars -out=cluster.tfplan

# Apply
terraform apply cluster.tfplan
```

### Environment-Specific Deployment

The repository includes example variable files and backend configurations. Local state is the default for a quick start:

```bash
cp environments/dev.tfvars.example environments/dev.tfvars
# Edit cluster name, region, and public CIDR before applying.
terraform init
terraform plan -var-file=environments/dev.tfvars -out=cluster.tfplan
terraform apply cluster.tfplan
```

For shared remote state, first provision the separate bootstrap stack, then enable the S3 backend:

```bash
terraform -chdir=00-bootstrap init
terraform -chdir=00-bootstrap apply -var='aws_region=us-west-2'
cp examples/backend.tf.example backend_override.tf
# Set bucket and region in environments/backend-dev.hcl from bootstrap outputs.
terraform init -migrate-state -backend-config=environments/backend-dev.hcl
```

Backend examples use native S3 locking (`use_lockfile = true`). Preserve bootstrap state securely and use a separate state key per environment. Existing DynamoDB users should follow [MIGRATION.md](docs/MIGRATION.md) before changing locking settings.

### Destroying Resources

If sample workloads were installed, delete them while the ingress controller and EBS CSI driver are still running:

```bash
kubectl delete namespace sample-app eks-smoke --ignore-not-found --wait=true
# If the optional platform stack was installed using the instructions below:
terraform -chdir=platform/ingress destroy -var-file=../../platform.tfvars
# Use the same root variables used for deployment:
terraform destroy -var-file=terraform.tfvars
```

Confirm that the sample ALB, target groups, and EBS volumes are gone before removing their controllers. The cluster root removes its own nodes, NAT gateways, elastic IPs, and VPC; the separate bootstrap state bucket is retained.

> **Warning**: Destruction removes cluster resources and data. Preserve anything you need before running it.

## 🔐 Access and Usage

### Configuring kubectl

After deployment, configure kubectl:

```bash
aws eks update-kubeconfig --region <region> --name <cluster-name>
```

The command is also available in Terraform outputs:

```bash
terraform output kubectl_config_command
```

### Verifying Access

```bash
# Check nodes
kubectl get nodes

# Check system pods
kubectl get pods -A

# Check storage classes (EBS CSI driver)
kubectl get storageclass
```

### Using IRSA

Service accounts can assume IAM roles using IRSA. Example:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app
  namespace: default
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/my-app-role
```

### Using EKS Pod Identity

The Pod Identity Agent is enabled by default. Map a Kubernetes service account to an existing IAM role:

```hcl
pod_identity_associations = {
  app = {
    namespace       = "apps"
    service_account = "my-app"
    role_arn        = "arn:aws:iam::123456789012:role/MyApp"
  }
}
```

The role must trust `pods.eks.amazonaws.com` for `sts:AssumeRole` and `sts:TagSession`. Create the service account separately; the association does not create it.

### Optional Ingress and HPA Metrics

After the infrastructure root completes, install the separate platform stack. It reuses the root's ingress IAM role and installs AWS Load Balancer Controller and Metrics Server. Set the region to match your cluster:

```bash
cat > platform.tfvars <<EOF
cluster_name        = "$(terraform output -raw cluster_name)"
aws_region          = "us-west-2"
vpc_id              = "$(terraform output -raw vpc_id)"
controller_role_arn = "$(terraform output -raw aws_load_balancer_controller_role_arn)"
EOF
terraform -chdir=platform/ingress init
terraform -chdir=platform/ingress apply -var-file=../../platform.tfvars
kubectl create namespace sample-app
NAMESPACE=sample-app bash examples/sample-app/deploy.sh
```

The samples demonstrate ingress, metrics-based HPA, and a separate EBS persistence workload. Internet-facing HTTP is for demonstration; TLS and workload-specific controls can be added later. Node autoscaling is not installed by this project.

### Running Checks

```bash
terraform fmt -check -recursive
terraform validate
terraform test
# With the optional platform stack installed and the intended kubeconfig selected:
bash scripts/smoke-test.sh
```

The 11 mocked tests run without AWS resources. The live smoke test creates an `eks-smoke` namespace and verifies DNS, HTTP, storage persistence, metrics, HPA readiness, and ALB access. It leaves resources for inspection; use the cleanup instructions above when done.

## 📤 Outputs

The module provides comprehensive outputs:

### Cluster Information

- `cluster_name`: Name of the EKS cluster
- `cluster_endpoint`: API server endpoint
- `cluster_version`: Kubernetes version
- `cluster_arn`: ARN of the cluster
- `cluster_certificate_authority_data`: Base64 encoded CA certificate

### Networking Information

- `vpc_id`: VPC ID
- `vpc_cidr_block`: VPC CIDR block
- `private_subnet_ids`: List of private subnet IDs
- `public_subnet_ids`: List of public subnet IDs

### Security Information

- `cluster_security_group_id`: Cluster security group ID
- `node_group_security_group_id`: Node group security group ID
- `oidc_provider_arn`: OIDC provider ARN for IRSA
- `aws_load_balancer_controller_role_arn`: IAM role consumed by the optional ingress stack

### Node Groups

- `node_groups`: Map of node group attributes (ARN, status, instance types)

### Commands

- `kubectl_config_command`: Command to configure kubectl

View all outputs:

```bash
terraform output
```

## 🔧 Troubleshooting

### Common Issues

#### Access Denied Errors

**Problem**: `kubectl get nodes` returns "Forbidden"

**Solution**: Ensure access entry is configured with proper permissions:

```bash
# Check access entries
aws eks list-access-entries --cluster-name <cluster-name>

# Verify access policy association
aws eks list-associated-access-policies --cluster-name <cluster-name> --principal-arn <principal-arn>
```

#### Node Group Not Joining

**Problem**: Nodes show as "NotReady" or don't appear

**Solution**:
1. Check node group status: `aws eks describe-nodegroup --cluster-name <name> --nodegroup-name <name>`
2. Check security group rules allow communication
3. Verify IAM roles have correct policies attached
4. Check CloudWatch logs: `/aws/eks/<cluster-name>/cluster`

#### API Connection or Public CIDR Errors

Check that your public IP matches the allowed CIDRs, or that you have private network connectivity. `0.0.0.0/0` is deliberately rejected.

#### Addon Installation Failures

**Problem**: EKS addons fail to install

**Solution**:
1. Verify addon version compatibility with cluster version
2. Check IAM role permissions for addon service accounts
3. Review addon health with `aws eks describe-addon` and pod logs with `kubectl logs`

### Getting Help

1. Check Terraform state: `terraform state list`
2. Review Terraform logs: `TF_LOG=DEBUG terraform apply`
3. Check AWS CloudWatch logs for EKS cluster
4. Review node group health and pod logs with AWS CLI and kubectl

## 📁 Module Structure

```
.
├── infrastructure/
│   ├── compute/
│   │   ├── cluster.tf              # EKS cluster definition
│   │   ├── node-groups.tf          # Managed node groups
│   │   ├── addons.tf               # EKS addons
│   │   ├── access-entries.tf        # EKS access entries
│   │   └── variables.tf            # Compute module variables
│   ├── networking/
│   │   ├── main.tf                 # VPC and networking resources
│   │   └── variables.tf            # Networking variables
│   └── security/
│       ├── security-groups.tf      # Security group definitions
│       ├── security-group-rules.tf # Security group rules
│       ├── iam-roles.tf           # IAM roles for cluster and nodes
│       └── irsa/                  # IRSA module
├── platform/
│   └── ingress/                   # AWS Load Balancer Controller
├── 00-bootstrap/                  # Terraform state backend
├── main.tf                       # Root module
├── variables.tf                   # Root variables
└── outputs.tf                    # Root outputs
```

## 🏭 Production Readiness

The current scope is a tested cluster deployment baseline: networking, managed nodes, IAM access, workload identity, essential add-ons, and optional ingress/metrics examples.

Backups, expanded monitoring, disaster recovery, Auto Mode, Karpenter, and other production integrations are deferred. They are not required to use the current baseline and are not being added in this release. Review [security decisions](docs/SECURITY.md) and [migration guidance](docs/MIGRATION.md) for current defaults and limitations.

## 💡 Best Practices

1. **State Management**: Use encrypted S3 state with native locking when sharing deployments.
2. **Secrets**: Keep credentials, local variable files, state, and saved plans out of Git.
3. **Access Control**: Prefer explicit IAM role principals and scoped access policies.
4. **Versioning**: Keep Kubernetes versions explicit and commit provider lock files. Pin add-on versions when repeatable upgrades are needed.
5. **Upgrades**: Upgrade existing clusters one minor version at a time and review plans for replacements.
6. **Testing**: Keep the existing CI checks and test changes on `dev` before merging to `main`.
7. **Cleanup**: Remove sample workloads before their controllers and verify no billable test resources remain.

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feat/amazing-feature`)
5. Open a Pull Request into `dev`; promote tested changes from `dev` into `main`

## 📄 License

See [LICENSE](LICENSE) file for details.

## 📚 Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)

## 💬 Support

For issues and questions:
- Open an issue on GitHub
- Review existing issues and discussions
- Check AWS EKS documentation

---

> **Note**: This module creates billable AWS resources. Monitor your AWS costs and clean up resources when not in use.
