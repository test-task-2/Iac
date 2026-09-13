data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7.2"

  name = var.cluster_name
  cidr = var.vpc_cidr

  azs = local.azs

  # Internet-facing ALB + NAT
  public_subnets      = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, i)]
  public_subnet_names = [for az in local.azs : "${var.cluster_name}-alb-${az}"]

  # EKS nodes and in-cluster workloads (vote, result, worker)
  private_subnets      = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, i + 10)]
  private_subnet_names = [for az in local.azs : "${var.cluster_name}-app-${az}"]

  # RDS PostgreSQL
  database_subnets      = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, i + 20)]
  database_subnet_names = [for az in local.azs : "${var.cluster_name}-db-${az}"]

  # ElastiCache Redis
  elasticache_subnets      = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, i + 30)]
  elasticache_subnet_names = [for az in local.azs : "${var.cluster_name}-redis-${az}"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  create_database_subnet_group       = true
  create_database_subnet_route_table = true
  database_subnet_group_name         = "${var.cluster_name}-db"

  create_elasticache_subnet_group       = true
  create_elasticache_subnet_route_table = true
  elasticache_subnet_group_name         = "${var.cluster_name}-redis"

  public_subnet_tags = {
    Tier                                        = "alb"
    "kubernetes.io/role/elb"                    = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    Tier                                        = "app"
    "kubernetes.io/role/internal-elb"           = 1
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  database_subnet_tags = {
    Tier = "db"
  }

  elasticache_subnet_tags = {
    Tier = "redis"
  }
}
