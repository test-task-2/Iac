resource "aws_iam_role" "crossplane" {
  name               = "${local.cluster}-crossplane"
  assume_role_policy = data.aws_iam_policy_document.lbc_assume.json
}

resource "aws_iam_role_policy_attachment" "crossplane_rds" {
  role       = aws_iam_role.crossplane.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
}

resource "aws_iam_role_policy_attachment" "crossplane_elasticache" {
  role       = aws_iam_role.crossplane.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonElastiCacheFullAccess"
}

resource "aws_iam_role_policy_attachment" "crossplane_ec2" {
  role       = aws_iam_role.crossplane.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role_policy_attachment" "crossplane_sm" {
  role       = aws_iam_role.crossplane.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

resource "aws_iam_role_policy_attachment" "crossplane_lambda" {
  role       = aws_iam_role.crossplane.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
}

resource "aws_iam_role_policy_attachment" "crossplane_iam" {
  role       = aws_iam_role.crossplane.name
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
}

resource "aws_iam_role_policy_attachment" "crossplane_cfn" {
  role       = aws_iam_role.crossplane.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCloudFormationFullAccess"
}

data "aws_iam_policy_document" "crossplane_sar" {
  statement {
    sid = "ServerlessRepoForRotationLambda"
    actions = [
      "serverlessrepo:CreateCloudFormationChangeSet",
      "serverlessrepo:CreateCloudFormationTemplate",
      "serverlessrepo:GetApplication",
      "serverlessrepo:GetApplicationPolicy",
      "serverlessrepo:GetCloudFormationTemplate",
    ]
    resources = ["arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSPostgreSQLRotationSingleUser"]
  }
}

resource "aws_iam_role_policy" "crossplane_sar" {
  name   = "serverlessrepo-rds-rotation"
  role   = aws_iam_role.crossplane.id
  policy = data.aws_iam_policy_document.crossplane_sar.json
}

resource "aws_eks_pod_identity_association" "crossplane" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "crossplane-system"
  service_account = "provider-aws"
  role_arn        = aws_iam_role.crossplane.arn
}
