# ==============================================================================
# OIDC IDENTITY PROVIDER (for IAM roles for service accounts)
# ==============================================================================

# Get the OIDC issuer URL from the cluster
data "tls_certificate" "cluster" {
  url = var.cluster_oidc_issuer_url
}

# Create OIDC identity provider
resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = var.cluster_oidc_issuer_url

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-oidc"
  })
}