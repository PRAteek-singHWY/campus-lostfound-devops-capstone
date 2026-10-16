# Launch template for the managed node group: IMDSv2 with hop limit 2 so pods (one extra network hop)
# can reach instance-role credentials. Without this the EBS CSI controller crash-loops on
# "Failed health check (verify network connection and IAM credentials)".
resource "aws_launch_template" "eks_nodes" {
  count       = var.enable_eks ? 1 : 0
  name_prefix = "${local.name}-eks-node-"

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    http_endpoint               = "enabled"
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${local.name}-eks-node" })
  }

  lifecycle {
    create_before_destroy = true
  }
}
