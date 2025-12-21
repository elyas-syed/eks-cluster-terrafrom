# AWS EKS Cluster Terraform Module

A Terraform module for deploying a complete AWS EKS (Elastic Kubernetes Service) cluster with best practices for security, networking, and scalability. This module provides a solid foundation that can be configured for development, staging, or production environments.

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
- **IRSA Support**: IAM Roles for Service Accounts (IRSA) for secure pod-to-AWS-service communication
- **Managed Node Groups**: Support for both on-demand and spot instances with launch templates
- **EKS Addons**: Pre-configured essential addons (VPC CNI, CoreDNS, kube-proxy, EBS CSI driver)
- **Security Best Practices**: Properly configured security groups, IAM roles, and network isolation
- **CloudWatch Logging**: Cluster logging enabled for audit and troubleshooting
- **Flexible Configuration**: Comprehensive variables for customization without code changes

## 🏗️ Architecture

The module is organized into the following components:

```
├── infrastructure/
│   ├── networking/          # VPC, subnets, NAT gateways, route tables
│   ├── security/           # Security groups, IAM roles, IRSA
│   └── compute/            # EKS cluster, node groups, addons, access entries
├── platform/               # Optional platform components (ingress, monitoring)
├── 00-bootstrap/           # Terraform state backend setup
└── main.tf                 # Root module orchestrating all components
```

### Network Architecture

- **VPC**: Custom CIDR with public and private subnets across multiple availability zones
- **Public Subnets**: Internet-facing resources (NAT gateways, load balancers)
- **Private Subnets**: EKS control plane and worker nodes
- **NAT Gateways**: High availability NAT for outbound internet access from private subnets

### Security Architecture

- **Security Groups**: Separate security groups for cluster and node groups with least-privilege rules
- **IAM Roles**: Dedicated roles for cluster, node groups, and service accounts
- **Access Entries**: Modern EKS authentication replacing aws-auth ConfigMap
- **IRSA**: Secure integration between Kubernetes service accounts and AWS IAM

## 📋 Prerequisites

Before deploying this module, ensure you have:

1. **AWS Account** with appropriate permissions
   - Required IAM permissions for EKS, EC2, VPC, IAM, CloudWatch
   - Minimum permissions: `AmazonEKSClusterPolicy`, `AmazonEKSWorkerNodePolicy`, `AmazonEC2ContainerRegistryReadOnly`

2. **Terraform** (>= 1.0)
   ```bash
   terraform version
   ```

3. **AWS CLI** configured with credentials
   ```bash
   aws sts get-caller-identity
   ```

4. **kubectl** (for cluster interaction)
   ```bash
   kubectl version --client
   ```

5. **Helm** (optional, for platform components)
   ```bash
   helm version
   ```

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/your-org/dev-eks-cluster-terrafrom.git
cd dev-eks-cluster-terrafrom
```

### 2. Configure Variables

Create a `terraform.tfvars` file (this file is gitignored):

```hcl
cluster_name    = "my-eks-cluster"
cluster_version = "1.34"  # Latest version. See upgrade notes below.
aws_region      = "us-west-2"
environment     = "dev"

# Node groups configuration
node_groups = {
  general = {
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
    min_size       = 1
    max_size       = 5
    desired_size   = 3
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

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Review the Plan

```bash
terraform plan -var-file=terraform.tfvars
```

### 5. Deploy

```bash
terraform apply -var-file=terraform.tfvars
```

> **Note**: While Terraform automatically loads `terraform.tfvars` if present, explicitly specifying `-var-file` is recommended for clarity and when using multiple variable files.

The deployment typically takes 15-20 minutes. The EKS cluster, node groups, and addons will be created in sequence.

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

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `cluster_name` | Unique name for the EKS cluster | `"my-eks-cluster"` |
| `cluster_version` | Kubernetes version (latest: 1.34) | `"1.34"` |
| `aws_region` | AWS region for deployment | `"us-west-2"` |

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

Configure essential EKS addons:

```hcl
cluster_addons = {
  vpc-cni = {
    addon_version = "v1.21.1-eksbuild.1"  # Latest for 1.34
  }
  coredns = {
    addon_version = "v1.12.4-eksbuild.1"  # Latest for 1.34
  }
  kube-proxy = {
    addon_version = "v1.34.1-eksbuild.2"  # Latest for 1.34
  }
  aws-ebs-csi-driver = {
    addon_version = "v1.54.0-eksbuild.1"  # Latest for 1.34
  }
}
```

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
    principal_arn = "arn:aws:iam::123456789012:user/developer"
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

> **Security Note**: Never commit actual IAM ARNs to version control. Use `"CURRENT_USER"` for dynamic resolution or environment variables.

### Networking Configuration

Customize VPC and networking:

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
cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]  # Restrict in production
```

## 🚢 Deployment

### Standard Deployment

```bash
# Initialize
terraform init

# Plan (explicitly specify var file)
terraform plan -var-file=terraform.tfvars -out=tfplan

# Apply
terraform apply tfplan
```

### Environment-Specific Deployment

The repository includes environment-specific configurations:

```bash
# Use environment-specific backend
terraform init -backend-config=environments/backend-dev.hcl

# Use environment-specific variables
terraform apply -var-file=environments/dev.tfvars
```

### Destroying Resources

To destroy all resources:

```bash
terraform destroy
```

> **Warning**: This will delete the entire EKS cluster and all associated resources. Ensure you have backups of any important data.

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

#### Addon Installation Failures

**Problem**: EKS addons fail to install

**Solution**:
1. Verify addon version compatibility with cluster version
2. Check IAM role permissions for addon service accounts
3. Review addon logs in CloudWatch

### Getting Help

1. Check Terraform state: `terraform state list`
2. Review Terraform logs: `TF_LOG=DEBUG terraform apply`
3. Check AWS CloudWatch logs for EKS cluster
4. Review node group logs in CloudWatch

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

This module provides a solid foundation for EKS clusters, but additional configuration is required for production workloads:

### ✅ Included Production Features

- **High Availability**: Multi-AZ deployment with private subnets across availability zones
- **Security Groups**: Properly configured with least-privilege rules
- **IAM Roles**: Dedicated roles for cluster, nodes, and service accounts
- **IRSA**: Secure pod-to-AWS-service communication
- **CloudWatch Logging**: Cluster control plane logging enabled
- **EKS Addons**: Essential addons (VPC CNI, CoreDNS, kube-proxy, EBS CSI)
- **Access Entries**: Modern authentication mechanism
- **Network Isolation**: Private subnets for worker nodes

### ⚠️ Production Configuration Required

Before deploying to production, ensure:

1. **Restrict Public Access**:
   ```hcl
   cluster_endpoint_public_access_cidrs = ["YOUR_OFFICE_IP/32", "YOUR_VPN_IP/32"]
   # Or disable public access entirely:
   cluster_endpoint_public_access = false
   ```

2. **Enable Private Endpoint Only** (recommended for production):
   ```hcl
   cluster_endpoint_private_access = true
   cluster_endpoint_public_access  = false
   ```

3. **Increase Node Group Sizes**:
   ```hcl
   node_groups = {
     general = {
       min_size     = 3  # Minimum for HA
       max_size     = 10
       desired_size = 3
     }
   }
   ```

4. **Extend CloudWatch Log Retention**:
   - Default is 7 days; increase to 30+ days for production
   - Configure in `infrastructure/compute/cluster.tf`

5. **Enable Additional Security**:
   - Configure Pod Security Standards (PSS)
   - Implement Network Policies
   - Set up Resource Quotas and Limit Ranges
   - Enable AWS GuardDuty for threat detection
   - Configure AWS WAF if using ALB

6. **Backup Strategy**:
   - Regular backups of Terraform state
   - Velero for Kubernetes resource backups
   - EBS snapshot strategy for persistent volumes

7. **Monitoring and Alerting**:
   - CloudWatch Alarms for cluster health
   - Prometheus and Grafana for metrics
   - AlertManager for notifications

8. **Disaster Recovery**:
   - Multi-region deployment strategy
   - Documented runbooks
   - Regular disaster recovery drills

9. **Compliance**:
   - Enable AWS Config for compliance monitoring
   - Implement AWS Security Hub
   - Regular security audits

10. **Cost Optimization**:
    - Use Spot instances for non-critical workloads
    - Right-size node groups based on actual usage
    - Enable cluster autoscaler
    - Monitor and optimize EBS volumes

### Production Checklist

- [ ] Restrict public endpoint access (CIDR whitelist or private-only)
- [ ] Deploy across at least 3 availability zones
- [ ] Minimum 3 nodes per node group for HA
- [ ] Extended CloudWatch log retention (30+ days)
- [ ] Pod Security Standards configured
- [ ] Network Policies implemented
- [ ] Resource quotas and limits defined
- [ ] Backup strategy in place
- [ ] Monitoring and alerting configured
- [ ] Disaster recovery plan documented
- [ ] Security scanning tools enabled
- [ ] Cost monitoring and alerts configured

## 💡 Best Practices

1. **State Management**: Use remote state backend (S3 + DynamoDB) for team collaboration
2. **Secrets**: Never commit `terraform.tfvars` with sensitive data
3. **Access Control**: Use least-privilege access policies
4. **Versioning**: Pin Terraform and provider versions
5. **Tagging**: Use consistent tags for resource management
6. **Monitoring**: Enable CloudWatch logging and monitoring
7. **Backup**: Regular backups of Terraform state
8. **Testing**: Test in dev environment before production
9. **Documentation**: Document all custom configurations and procedures
10. **Review**: Regular security and cost reviews

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

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
