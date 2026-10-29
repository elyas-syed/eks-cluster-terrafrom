# Amazon EKS with Terraform

Deploy an EKS cluster with managed AL2023 node groups, private worker subnets,
IAM access entries, IRSA, Pod Identity support, and managed EKS add-ons.
The supported deployment starts at this repository's root. The `terraform/`
directory is legacy reference code and must not be applied alongside the root.

The default Kubernetes target is **1.37**, verified against the AWS EKS API in
`us-east-1` on October 29, 2026. Kubernetes versions remain explicit: new AWS
releases do not silently upgrade your cluster. Add-ons without an explicit
`addon_version` use AWS's recommended compatible version for the selected
Kubernetes version and region. Pin add-on versions in release configurations
when repeatable upgrades are required.

## Requirements

- Terraform 1.10 or newer, below 2.0 (CI uses 1.12.2).
- AWS CLI v2, with credentials for the target account and permissions to create
  EKS, EC2/VPC, IAM, and CloudWatch resources. Worker-node policies alone are
  **not** sufficient deployment permissions.
- Sufficient VPC, elastic IP, EC2, and EKS quotas in the selected region.
- kubectl compatible with the selected Kubernetes version; Helm for optional
  platform components.
- Network access to the cluster API from the machine running platform tooling.
  The API is private by default. Public access requires explicit allowed CIDRs;
  `0.0.0.0/0` is rejected.

## Deploy a development cluster

```bash
git clone https://github.com/elyas-syed/eks-cluster-terrafrom.git
cd eks-cluster-terrafrom
aws sts get-caller-identity
cp environments/dev.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`: choose a unique cluster name and region and replace the
example public CIDR with your public IP followed by `/32`. Alternatively, retain
a private API and run tooling from a connected network. When availability zones
are omitted, the module discovers zones in the chosen region; public and private
subnet CIDR lists must have the same length, with at least two subnets each.

```bash
terraform init
terraform validate
terraform plan -out=cluster.tfplan
terraform apply cluster.tfplan
aws eks update-kubeconfig --region us-east-1 --name my-dev-eks
kubectl get nodes
kubectl get pods -A
```

This creates billable resources, including one NAT gateway per availability
zone, the EKS control plane, EC2 nodes, EBS volumes, and CloudWatch logs.
The development example uses two `t3.medium` nodes. Change sizing deliberately;
autoscaling group limits alone do not install a node autoscaler.

## Access and workload identity

New clusters use API authentication and explicit access entries. Bootstrap creator
admin is disabled to avoid permanent implicit access. `CURRENT_USER` resolves an
IAM user directly or an STS assumed-role session to its persistent IAM role ARN.
For shared environments, prefer explicit role ARNs so deployment identity changes
do not unexpectedly change cluster access.

```hcl
access_entries = {
  admin = {
    principal_arn       = "arn:aws:iam::123456789012:role/PlatformAdmin"
    grant_cluster_admin = true
  }
  viewer = {
    principal_arn = "arn:aws:iam::123456789012:role/AppViewer"
    access_policy = {
      policy_name  = "AmazonEKSViewPolicy"
      access_scope = { type = "namespace", namespaces = ["apps"] }
    }
  }
}
```

EBS CSI and the optional Load Balancer Controller use dedicated IRSA roles. The
Pod Identity Agent is enabled by default; optional `pod_identity_associations`
map a namespace and service account to an existing IAM role. That role must trust
`pods.eks.amazonaws.com` for `sts:AssumeRole` and `sts:TagSession`. Create the
Kubernetes service account separately. Association does not create it.

The baseline retains the VPC CNI policy on the node role for compatibility.
Production deployments should assess isolating that permission to the CNI
service account and limiting pod access to instance credentials.

## Optional ingress and HPA metrics

Apply `platform/ingress` separately **after** the infrastructure root finishes.
It installs AWS Load Balancer Controller 3.6.2 and Metrics Server chart 3.14.0.
The controller reuses the root's IRSA role; it does not create duplicate IAM roles.
The vendored controller IAM policy comes from upstream controller release 3.6.2.
Upgrade the chart and policy together and follow upstream CRD migration notes.

```bash
terraform -chdir=platform/ingress init
terraform -chdir=platform/ingress apply \
  -var='cluster_name=my-dev-eks' \
  -var='aws_region=us-east-1' \
  -var="vpc_id=$(terraform output -raw vpc_id)" \
  -var="controller_role_arn=$(terraform output -raw aws_load_balancer_controller_role_arn)"
bash examples/sample-app/deploy.sh
```

The sample app uses a digest-pinned non-root NGINX image, probes, resource limits,
an ALB ingress, an HPA, and a separate single-replica EBS persistence example.
Internet-facing HTTP ingress is for demonstration; configure ACM/TLS and access
controls before serving real workloads. Metrics Server is needed for the HPA.

## State and environments

Local state is the default for a quick start. Do not share it through Git.
For teams, first apply `00-bootstrap` to create an encrypted, versioned, private
S3 state bucket. The stack uses local state initially; preserve that bootstrap
state securely and separately from the cluster state.

```bash
terraform -chdir=00-bootstrap init
terraform -chdir=00-bootstrap apply -var='aws_region=us-east-1'
cp examples/backend.tf.example backend_override.tf
# Edit bucket and region in environments/backend-dev.hcl using bootstrap outputs.
terraform init -migrate-state -backend-config=environments/backend-dev.hcl
```

Environment backend examples use native S3 locking (`use_lockfile = true`).
DynamoDB locking is retained as an opt-in bootstrap setting for existing users;
see [migration notes](docs/MIGRATION.md) before changing existing backends.
Use distinct state keys and configuration for development and production.
`environments/prod.tfvars.example` illustrates private API access, three AZs,
explicit roles, and longer log retention. It is a starting point, not a complete
production security or disaster recovery configuration.

## Verification and cleanup

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
terraform test
# After the optional platform stack is installed, using the intended kubeconfig:
bash scripts/smoke-test.sh
```

Tests mock AWS and do not establish live AWS compatibility by themselves. CI
validates the root, bootstrap, and platform stacks. A live test must also check
nodes/add-ons, DNS, ingress, storage persistence, metrics, scoped access, and an
unchanged second plan. `scripts/smoke-test.sh` creates workloads in `eks-smoke`
and leaves them available for inspection; it does not destroy infrastructure.

Clean up workloads first so the controller can remove ALBs and target groups:

```bash
kubectl delete namespace eks-smoke --wait=true
# If samples were deployed in default, delete their ingress and workload manifests.
# Supply the same variables used for the platform apply:
terraform -chdir=platform/ingress destroy -var-file=your-platform.tfvars
terraform destroy
```

Keep the platform controller running until its load balancers are deleted.
Confirm there are no leftover test ALBs, target groups, EBS volumes, NAT gateways,
or elastic IPs. The bootstrap state bucket is intentionally separate and is not
deleted by the cluster root. Preserve production data before any destruction.

## Upgrades and production work

Read [MIGRATION.md](docs/MIGRATION.md) before applying this version to existing
state. Upgrade Kubernetes one minor version at a time, review EKS upgrade
insights and deprecated APIs, update node versions and add-ons, and inspect every
plan for replacements. Managed nodes are explicitly tied to the cluster's
configured Kubernetes version.

Production extensions should be selected by need: workload network policies,
Pod Security admission, backup/restore, monitoring and alarms, Secrets Manager,
GuardDuty, and node autoscaling. Auto Mode and Karpenter are follow-up deployment
options; neither is installed by this baseline.

## References

- [EKS versions](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html)
- [EKS best practices](https://docs.aws.amazon.com/eks/latest/best-practices/introduction.html)
- [S3 backend and locking](https://developer.hashicorp.com/terraform/language/backend/s3)
- [Controller IAM policy source](https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/v3.6.2/docs/install/iam_policy.json)

Licensed under GPL-3.0; see [LICENSE](LICENSE).
