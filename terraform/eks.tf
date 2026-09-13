# KodeKloud playground limitations (kk profile, time-boxed IAM):
# - Region is us-east-1 only (org SCP denies other regions).
# - iam:PassRole is allowed only for eksClusterRole and AmazonEKSNodeRole.
# - iam:TagPolicy is denied — no extra IAM policies (skip KMS encryption).
# - iam:UntagRole / rds:RemoveTagsFromResource denied — keep default_tags.
# - eks:CreateNodegroup is denied — use self-managed nodes (EC2 + ASG).
# - system:masters is invalid on access entries (cannot start with system:).
# - eks:AssociateAccessPolicy is denied — cannot attach
#   AmazonEKSClusterAdminPolicy. Access entry is created without a policy.
# - EC2: t2/t3 nano–medium only. CPU credits must be standard (unlimited
#   suspends the session). EKS 1.36 has no Amazon Linux 2 optimized AMI —
#   only AL2023 — so nodes use AL2023_x86_64_STANDARD.
# - IAM allows are DateGreaterThan/DateLessThan (playground session window).

data "aws_caller_identity" "current" {}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.25.0"

  name               = var.cluster_name
  kubernetes_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets # app subnets only; ALB/DB/Redis stay out of the node ENI set

  endpoint_public_access                   = true
  # Bootstrap (patched module) already creates the lab-user access entry + admin
  # policy. Do not create another entry or AssociateAccessPolicy (409 / 403).
  enable_cluster_creator_admin_permissions = false

  create_kms_key              = false
  encryption_config           = null
  create_cloudwatch_log_group = false

  iam_role_name            = "eksClusterRole"
  iam_role_use_name_prefix = false

  addons = {
    # CoreDNS is created in addons.tf after nodes are InService.
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
  }

  self_managed_node_groups = {
    default = {
      instance_type = var.node_instance_type
      ami_type      = "AL2023_x86_64_STANDARD"

      credit_specification = {
        cpu_credits = "standard"
      }

      iam_role_name            = "AmazonEKSNodeRole"
      iam_role_use_name_prefix = false

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size
    }
  }
}
