resource "aws_secretsmanager_secret" "cloudflare" {
  name                    = "${local.cluster}/cloudflare"
  description             = "Cloudflare API token for ExternalDNS. JSON {\"api-token\":\"...\"}, filled manually."
  recovery_window_in_days = 0
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    sid = "ReadSecrets"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecretVersionIds",
    ]
    resources = [
      aws_secretsmanager_secret.cloudflare.arn,
      "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${local.cluster}/*",
      "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:rds!*",
    ]
  }
}

resource "aws_iam_role" "external_secrets" {
  name               = "${local.cluster}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.lbc_assume.json
}

resource "aws_iam_role_policy" "external_secrets" {
  name   = "secretsmanager"
  role   = aws_iam_role.external_secrets.id
  policy = data.aws_iam_policy_document.external_secrets.json
}

resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  role_arn        = aws_iam_role.external_secrets.arn
}
