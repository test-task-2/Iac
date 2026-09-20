resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.9.1"
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  timeout          = 600
  atomic           = true

  values = [file("${path.module}/argocd-values.yaml")]

  depends_on = [
    aws_eks_node_group.default,
    aws_eks_addon.coredns,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy,
    aws_eks_access_policy_association.root,
  ]
}

resource "helm_release" "app_of_apps" {
  name       = "app-of-apps"
  chart      = "${path.module}/charts/app-of-apps"
  namespace  = "argocd"
  wait       = true
  timeout    = 180
  depends_on = [helm_release.argocd]
}