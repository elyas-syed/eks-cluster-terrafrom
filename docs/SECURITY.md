# Security decisions and configuration scanning

The baseline uses a private cluster API, explicit EKS API access entries, private
worker nodes, encrypted node disks, IMDSv2, scoped controller IRSA roles, a Pod
Identity Agent, control-plane logs, and rejected-traffic VPC flow logs. Public
subnets do not assign public IPs automatically. Sample workloads use a pinned
upstream image, non-root execution, dropped capabilities, a read-only root
filesystem, and no mounted service-account token.

Trivy reports configuration findings in CI. Its job is advisory: a successful job
means the scan ran, not that every reported policy is satisfied. Findings require
review of the effective root values and the environment. The legacy `terraform/`
directory is excluded because it is not a supported deployment path.

## Findings requiring context

- **API data encryption:** EKS 1.28+ provides default envelope encryption for all
  Kubernetes API data using an AWS-owned KMS key. Absence of a Terraform
  `encryption_config` block does not mean data is unencrypted. Supply
  `cluster_kms_key_arn` when a customer-managed key is required. Keep the key
  enabled and authorize EKS before use.
- **Outbound internet:** workers require HTTPS egress through NAT for image pulls
  and AWS APIs. Egress is limited to TCP 443 for internet destinations; DNS is
  limited to the VPC CIDR, and inter-node traffic to the worker security group.
  The control plane's custom security group can send traffic only to workers.
  Production environments needing destination restrictions should use private
  endpoints, controlled registries, network policies, and an egress proxy or
  firewall. Those are environment-specific extensions.
- **Key ownership and audit:** S3 state and CloudWatch logs are encrypted with
  service-managed keys by default. Customer-managed keys are optional inputs.
  State-bucket access logging and organization-level CloudTrail need a separate
  audit destination and are not provisioned by this project.
- **Image source and UID:** the sample uses a digest-pinned official NGINX
  unprivileged image in GHCR, running as its upstream UID/GID 101. Scanners may
  prefer a different registry allowlist or UID above 10000. Adapting that image
  and registry to an organization's policy remains its responsibility.
- **Namespace:** sample manifests intentionally inherit the namespace selected by
  kubectl. Use `NAMESPACE=eks-smoke` with the helper script; do not run real
  application workloads in the default namespace.
- **Node credentials:** the baseline retains the VPC CNI policy on the worker role
  for compatibility. Workloads should use Pod Identity or IRSA. Additional
  restriction of pod access to IMDS and moving CNI permissions to a dedicated
  workload identity are recommended production hardening.

## Further production controls

Evaluate Pod Security admission, Kubernetes network policies, TLS/ACM for ingress,
backup and restore tests, logging alerts, Secrets Manager integration, GuardDuty,
image scanning, and vulnerability/dependency update policies. Do not infer that
all of these controls are installed by this baseline.

References:
- https://docs.aws.amazon.com/eks/latest/userguide/envelope-encryption.html
- https://docs.aws.amazon.com/eks/latest/best-practices/identity-and-access-management.html
