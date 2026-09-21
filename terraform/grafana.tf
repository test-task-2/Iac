locals {
  grafana_admin_secret         = "${local.cluster}/grafana-admin"
  grafana_admin_user           = "admin"
  grafana_admin_secret_version = 1
}

ephemeral "random_password" "grafana_admin" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}"
}

resource "aws_secretsmanager_secret" "grafana_admin" {
  name                    = local.grafana_admin_secret
  description             = "Grafana admin credentials for kube-prometheus-stack"
  recovery_window_in_days = 0

  tags = {
    Name = local.grafana_admin_secret
  }
}

resource "aws_secretsmanager_secret_version" "grafana_admin" {
  secret_id = aws_secretsmanager_secret.grafana_admin.id

  secret_string_wo = jsonencode({
    admin-user     = local.grafana_admin_user
    admin-password = ephemeral.random_password.grafana_admin.result
  })
  secret_string_wo_version = local.grafana_admin_secret_version
}

data "aws_iam_policy_document" "grafana" {
  statement {
    sid = "CloudWatchRead"
    actions = [
      "cloudwatch:DescribeAlarms",
      "cloudwatch:DescribeAlarmsForMetric",
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ResourceDiscovery"
    actions = [
      "tag:GetResources",
      "ec2:DescribeTags",
      "ec2:DescribeRegions",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeTargetGroups",
      "rds:DescribeDBInstances",
      "elasticache:DescribeCacheClusters",
      "elasticache:DescribeReplicationGroups",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "grafana" {
  name               = "${local.cluster}-grafana"
  assume_role_policy = data.aws_iam_policy_document.lbc_assume.json
}

resource "aws_iam_role_policy" "grafana" {
  name   = "cloudwatch"
  role   = aws_iam_role.grafana.id
  policy = data.aws_iam_policy_document.grafana.json
}

resource "aws_eks_pod_identity_association" "grafana" {
  cluster_name    = module.eks.cluster_name
  namespace       = "monitoring"
  service_account = "grafana"
  role_arn        = aws_iam_role.grafana.arn
}
