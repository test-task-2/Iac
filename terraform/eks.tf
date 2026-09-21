module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.21"

  name               = local.cluster
  kubernetes_version = var.kubernetes_version

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  endpoint_public_access  = true
  endpoint_private_access = true
  authentication_mode     = "API_AND_CONFIG_MAP"

  enable_cluster_creator_admin_permissions = true
  enabled_log_types                        = []
  create_cloudwatch_log_group              = false

  additional_security_group_ids = [aws_security_group.control_plane.id]

  cluster_tags = {
    "karpenter.sh/discovery" = local.cluster
  }

  access_entries = {
    root = {
      principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    karpenter_node = {
      principal_arn = aws_iam_role.karpenter_node.arn
      type          = "EC2_LINUX"
    }
  }

  addons = {
    eks-pod-identity-agent = {
      before_compute              = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    vpc-cni = {
      before_compute              = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    kube-proxy = {
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    coredns = {
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
      configuration_values = jsonencode({
        replicaCount = 2
        nodeSelector = {
          role = "system"
        }
      })
    }
  }

  eks_managed_node_groups = {
    system = {
      name           = "system"
      instance_types = [var.node_instance_type]
      ami_type       = var.node_ami_type
      capacity_type  = var.node_capacity_type
      min_size       = var.node_count
      max_size       = var.node_count
      desired_size   = var.node_count
      subnet_ids     = module.vpc.private_subnets

      labels = {
        role = "system"
      }

      vpc_security_group_ids               = [aws_security_group.nodes.id]
      attach_cluster_primary_security_group = true

      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
      }

      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      launch_template_tags = {
        Name = "${local.cluster}-node-system"
      }
    }
  }
}
