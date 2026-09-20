locals {
  cluster_tag = "kubernetes.io/cluster/${local.cluster}"
}

resource "aws_security_group" "alb" {
  name        = "${local.cluster}-alb"
  description = "Internet-facing and internal ALBs"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name                    = "${local.cluster}-alb"
    Tier                    = "alb"
    (local.cluster_tag)     = "owned"
    "elbv2.k8s.aws/cluster" = local.cluster
  }
}

resource "aws_security_group" "control_plane" {
  name        = "${local.cluster}-control-plane"
  description = "EKS additional control-plane ENIs"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name                = "${local.cluster}-control-plane"
    Tier                = "control-plane"
    (local.cluster_tag) = "owned"
  }
}

resource "aws_security_group" "nodes" {
  name        = "${local.cluster}-nodes"
  description = "EKS nodes and Karpenter"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name                = "${local.cluster}-nodes"
    Tier                = "system"
    (local.cluster_tag) = "owned"
  }
}

resource "aws_security_group" "karpenter" {
  name        = "${local.cluster}-karpenter"
  description = "Karpenter app nodes (RDS/Redis + ALB)"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name                     = "${local.cluster}-karpenter"
    Tier                     = "karpenter"
    "karpenter.sh/discovery" = local.cluster
    (local.cluster_tag)      = "owned"
  }
}

resource "aws_security_group" "db" {
  name        = "${local.cluster}-db"
  description = "RDS"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "${local.cluster}-db"
    Tier = "db"
  }
}

resource "aws_security_group" "redis" {
  name        = "${local.cluster}-redis"
  description = "ElastiCache Redis"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "${local.cluster}-redis"
    Tier = "redis"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow all egress"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "control_plane_from_nodes" {
  security_group_id            = aws_security_group.control_plane.id
  description                  = "System nodes to API"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.nodes.id
}

resource "aws_vpc_security_group_ingress_rule" "control_plane_from_karpenter" {
  security_group_id            = aws_security_group.control_plane.id
  description                  = "Karpenter nodes to API"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.karpenter.id
}

resource "aws_vpc_security_group_egress_rule" "control_plane" {
  security_group_id = aws_security_group.control_plane.id
  description       = "Allow all egress"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "nodes_from_alb" {
  security_group_id            = aws_security_group.nodes.id
  description                  = "ALB to pods"
  ip_protocol                  = "tcp"
  from_port                    = 1025
  to_port                      = 65535
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_ingress_rule" "nodes_api" {
  security_group_id            = aws_security_group.nodes.id
  description                  = "Control plane to nodes"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.control_plane.id
}

resource "aws_vpc_security_group_ingress_rule" "nodes_kubelet" {
  security_group_id            = aws_security_group.nodes.id
  description                  = "Control plane to kubelet"
  ip_protocol                  = "tcp"
  from_port                    = 10250
  to_port                      = 10250
  referenced_security_group_id = aws_security_group.control_plane.id
}

resource "aws_vpc_security_group_ingress_rule" "nodes_lbc_webhook" {
  security_group_id            = aws_security_group.nodes.id
  description                  = "Control plane to LBC webhook"
  ip_protocol                  = "tcp"
  from_port                    = 9443
  to_port                      = 9443
  referenced_security_group_id = aws_security_group.control_plane.id
}

resource "aws_vpc_security_group_ingress_rule" "nodes_coredns_tcp" {
  security_group_id            = aws_security_group.nodes.id
  description                  = "Node to node CoreDNS"
  ip_protocol                  = "tcp"
  from_port                    = 53
  to_port                      = 53
  referenced_security_group_id = aws_security_group.nodes.id
}

resource "aws_vpc_security_group_ingress_rule" "nodes_coredns_udp" {
  security_group_id            = aws_security_group.nodes.id
  description                  = "Node to node CoreDNS UDP"
  ip_protocol                  = "udp"
  from_port                    = 53
  to_port                      = 53
  referenced_security_group_id = aws_security_group.nodes.id
}

resource "aws_vpc_security_group_ingress_rule" "nodes_pods" {
  security_group_id            = aws_security_group.nodes.id
  description                  = "Node to node pods"
  ip_protocol                  = "tcp"
  from_port                    = 1025
  to_port                      = 65535
  referenced_security_group_id = aws_security_group.nodes.id
}

resource "aws_vpc_security_group_egress_rule" "nodes" {
  security_group_id = aws_security_group.nodes.id
  description       = "Allow all egress"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "nodes_from_karpenter_dns_tcp" {
  security_group_id            = aws_security_group.nodes.id
  description                  = "Karpenter to system CoreDNS"
  ip_protocol                  = "tcp"
  from_port                    = 53
  to_port                      = 53
  referenced_security_group_id = aws_security_group.karpenter.id
}

resource "aws_vpc_security_group_ingress_rule" "nodes_from_karpenter_dns_udp" {
  security_group_id            = aws_security_group.nodes.id
  description                  = "Karpenter to system CoreDNS UDP"
  ip_protocol                  = "udp"
  from_port                    = 53
  to_port                      = 53
  referenced_security_group_id = aws_security_group.karpenter.id
}

resource "aws_vpc_security_group_ingress_rule" "nodes_from_karpenter_pods" {
  security_group_id            = aws_security_group.nodes.id
  description                  = "Karpenter pods to system pods"
  ip_protocol                  = "tcp"
  from_port                    = 1025
  to_port                      = 65535
  referenced_security_group_id = aws_security_group.karpenter.id
}

resource "aws_vpc_security_group_ingress_rule" "karpenter_from_alb" {
  security_group_id            = aws_security_group.karpenter.id
  description                  = "ALB to app pods"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 65535
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_ingress_rule" "karpenter_api" {
  security_group_id            = aws_security_group.karpenter.id
  description                  = "Control plane to Karpenter nodes"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.control_plane.id
}

resource "aws_vpc_security_group_ingress_rule" "karpenter_kubelet" {
  security_group_id            = aws_security_group.karpenter.id
  description                  = "Control plane to Karpenter kubelet"
  ip_protocol                  = "tcp"
  from_port                    = 10250
  to_port                      = 10250
  referenced_security_group_id = aws_security_group.control_plane.id
}

resource "aws_vpc_security_group_ingress_rule" "karpenter_dns_tcp" {
  security_group_id            = aws_security_group.karpenter.id
  description                  = "Karpenter node CoreDNS"
  ip_protocol                  = "tcp"
  from_port                    = 53
  to_port                      = 53
  referenced_security_group_id = aws_security_group.karpenter.id
}

resource "aws_vpc_security_group_ingress_rule" "karpenter_dns_udp" {
  security_group_id            = aws_security_group.karpenter.id
  description                  = "Karpenter node CoreDNS UDP"
  ip_protocol                  = "udp"
  from_port                    = 53
  to_port                      = 53
  referenced_security_group_id = aws_security_group.karpenter.id
}

resource "aws_vpc_security_group_ingress_rule" "karpenter_pods" {
  security_group_id            = aws_security_group.karpenter.id
  description                  = "Karpenter node to node pods"
  ip_protocol                  = "tcp"
  from_port                    = 1025
  to_port                      = 65535
  referenced_security_group_id = aws_security_group.karpenter.id
}

resource "aws_vpc_security_group_ingress_rule" "karpenter_from_system_dns_tcp" {
  security_group_id            = aws_security_group.karpenter.id
  description                  = "System to Karpenter CoreDNS"
  ip_protocol                  = "tcp"
  from_port                    = 53
  to_port                      = 53
  referenced_security_group_id = aws_security_group.nodes.id
}

resource "aws_vpc_security_group_ingress_rule" "karpenter_from_system_dns_udp" {
  security_group_id            = aws_security_group.karpenter.id
  description                  = "System to Karpenter CoreDNS UDP"
  ip_protocol                  = "udp"
  from_port                    = 53
  to_port                      = 53
  referenced_security_group_id = aws_security_group.nodes.id
}

resource "aws_vpc_security_group_ingress_rule" "karpenter_from_system_pods" {
  security_group_id            = aws_security_group.karpenter.id
  description                  = "System pods to Karpenter pods"
  ip_protocol                  = "tcp"
  from_port                    = 1025
  to_port                      = 65535
  referenced_security_group_id = aws_security_group.nodes.id
}

resource "aws_vpc_security_group_egress_rule" "karpenter" {
  security_group_id = aws_security_group.karpenter.id
  description       = "Allow all egress"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "db_from_karpenter" {
  security_group_id            = aws_security_group.db.id
  description                  = "Postgres from Karpenter app nodes"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.karpenter.id
}

resource "aws_vpc_security_group_egress_rule" "db" {
  security_group_id = aws_security_group.db.id
  description       = "Allow all egress"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_karpenter" {
  security_group_id            = aws_security_group.redis.id
  description                  = "Redis from Karpenter app nodes"
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  referenced_security_group_id = aws_security_group.karpenter.id
}

resource "aws_vpc_security_group_egress_rule" "redis" {
  security_group_id = aws_security_group.redis.id
  description       = "Allow all egress"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
