# EKS Managed Node Groups
resource "aws_eks_node_group" "main" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.main.name
  version         = var.cluster_version
  node_group_name = each.key
  node_role_arn   = var.node_group_role_arn
  subnet_ids      = var.private_subnet_ids

  capacity_type = each.value.capacity_type
  ami_type      = each.value.ami_type
  # disk_size is specified in the launch template, not here
  instance_types = each.value.instance_types

  scaling_config {
    desired_size = each.value.desired_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }

  # Use basic labels only
  labels = merge({
    "node-group"  = each.key
    "environment" = var.environment
  }, each.value.labels)

  dynamic "taint" {
    for_each = each.value.taints
    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  force_update_version = each.value.force_update_version
  update_config {
    max_unavailable_percentage = each.value.update_config.max_unavailable_percentage
  }

  # Launch template for enhanced features (encryption, metadata options, etc.)
  launch_template {
    id      = each.value.use_custom_launch_template ? null : aws_launch_template.node_group[each.key].id
    name    = each.value.use_custom_launch_template ? each.value.launch_template_name : null
    version = each.value.use_custom_launch_template ? coalesce(each.value.launch_template_version, "$Default") : tostring(aws_launch_template.node_group[each.key].latest_version)
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  depends_on = [
    aws_eks_cluster.main,
    aws_launch_template.node_group,
    aws_eks_addon.vpc_cni,
  ]

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-${each.key}-node-group"
  })

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# Enhanced Launch Templates
resource "aws_launch_template" "node_group" {
  for_each = { for name, group in var.node_groups : name => group if !group.use_custom_launch_template }

  name_prefix = "${var.cluster_name}-${each.key}-"

  vpc_security_group_ids = [var.node_group_security_group_id]

  # EBS configuration
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = each.value.disk_size
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 125
      encrypted             = true
      delete_on_termination = true
    }
  }

  # Metadata options
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  # Monitoring
  monitoring {
    enabled = true
  }

  # Note: EKS managed node groups handle bootstrap automatically
  # User data is optional and should be minimal for managed node groups
  # Uncomment below if you need custom user data (must be in MIME multipart format)
  # user_data = base64encode(templatefile("${path.module}/user-data.sh", {
  #   cluster_name = var.cluster_name
  #   environment  = var.environment
  # }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name                                        = "${var.cluster_name}-${each.key}-node"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-${each.key}-launch-template"
  })
}