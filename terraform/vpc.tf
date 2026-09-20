data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  azs     = slice(data.aws_availability_zones.available.names, 0, 2)
  cluster = var.cluster_name
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7.2"

  name = local.cluster
  cidr = var.vpc_cidr
  azs  = local.azs

  public_subnets      = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, i)]
  public_subnet_names = [for az in local.azs : "${local.cluster}-alb-${az}"]

  intra_subnets      = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, i + 40)]
  intra_subnet_names = [for az in local.azs : "${local.cluster}-control-plane-${az}"]

  private_subnets      = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, i + 10)]
  private_subnet_names = [for az in local.azs : "${local.cluster}-nodes-${az}"]

  database_subnets      = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, i + 20)]
  database_subnet_names = [for az in local.azs : "${local.cluster}-db-${az}"]

  elasticache_subnets      = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, i + 30)]
  elasticache_subnet_names = [for az in local.azs : "${local.cluster}-redis-${az}"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  create_database_subnet_group       = true
  create_database_subnet_route_table = true
  database_subnet_group_name         = "${local.cluster}-db"

  create_elasticache_subnet_group       = true
  create_elasticache_subnet_route_table = true
  elasticache_subnet_group_name         = "${local.cluster}-redis"

  public_subnet_tags = {
    Tier                                     = "alb"
    "kubernetes.io/role/elb"                 = 1
    "kubernetes.io/cluster/${local.cluster}" = "shared"
  }

  intra_subnet_tags = {
    Tier                                     = "control-plane"
    "kubernetes.io/cluster/${local.cluster}" = "shared"
  }

  private_subnet_tags = {
    Tier                                     = "nodes"
    "karpenter.sh/discovery"                 = local.cluster
    "kubernetes.io/role/internal-elb"        = 1
    "kubernetes.io/cluster/${local.cluster}" = "shared"
  }

  database_subnet_tags = {
    Tier = "db"
  }

  elasticache_subnet_tags = {
    Tier = "redis"
  }
}
