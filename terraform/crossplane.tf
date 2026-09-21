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

resource "aws_eks_pod_identity_association" "crossplane" {
  cluster_name    = module.eks.cluster_name
  namespace       = "crossplane-system"
  service_account = "provider-aws"
  role_arn        = aws_iam_role.crossplane.arn
}
