# Pod Identity equivalent of IRSA for ECR token refresh (tokens expire in 12h).
resource "aws_iam_role" "image_updater" {
  name               = "${local.cluster}-image-updater"
  assume_role_policy = data.aws_iam_policy_document.lbc_assume.json
}

resource "aws_iam_role_policy_attachment" "image_updater_ecr" {
  role       = aws_iam_role.image_updater.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_eks_pod_identity_association" "image_updater" {
  cluster_name    = module.eks.cluster_name
  namespace       = "argocd"
  service_account = "argocd-image-updater"
  role_arn        = aws_iam_role.image_updater.arn
}
