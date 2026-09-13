# CoreDNS stays out of the EKS module so it does not start until nodes exist.
# The addon waits until pods are healthy, which needs Ready nodes.

resource "null_resource" "wait_for_nodes" {
  depends_on = [module.eks]

  triggers = {
    asg_name = module.eks.self_managed_node_groups["default"].autoscaling_group_name
    desired  = var.node_desired_size
  }

  provisioner "local-exec" {
    environment = {
      AWS_PROFILE = var.aws_profile
      AWS_REGION  = var.region
      ASG_NAME    = module.eks.self_managed_node_groups["default"].autoscaling_group_name
      DESIRED     = var.node_desired_size
    }

    command = <<-EOT
      set -euo pipefail
      echo "Waiting for $DESIRED InService instance(s) in $ASG_NAME"
      for i in $(seq 1 80); do
        IDS=$(aws autoscaling describe-auto-scaling-groups \
          --auto-scaling-group-names "$ASG_NAME" \
          --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`].InstanceId' \
          --output text)
        COUNT=$(echo "$IDS" | wc -w | tr -d ' ')
        echo "  attempt $i: $COUNT InService"
        if [ "$COUNT" -ge "$DESIRED" ]; then
          aws ec2 wait instance-status-ok --instance-ids $IDS
          echo "EC2 status-ok; waiting 2m for kubelets to register"
          sleep 120
          exit 0
        fi
        sleep 15
      done
      echo "Timed out waiting for ASG instances" >&2
      exit 1
    EOT
  }
}

data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = var.kubernetes_version
  most_recent        = true
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "coredns"
  addon_version               = data.aws_eks_addon_version.coredns.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  timeouts {
    create = "20m"
  }

  depends_on = [null_resource.wait_for_nodes]
}
