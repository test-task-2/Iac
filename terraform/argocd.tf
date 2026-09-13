# In-cluster Argo CD. The EKS ARGOCD capability needs IAM Identity Center,
# which this playground SCP denies (sso:ListInstances).

data "aws_eks_cluster" "this" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.8.3"
  namespace        = "argocd"
  create_namespace = true
  timeout          = 600
  wait             = true

  # Single replica, ClusterIP — 2× t3.medium has no room for HA or an extra ELB.
  values = [
    yamlencode({
      global = {
        domain = "argocd.local"
      }
      configs = {
        params = {
          "server.insecure" = true
        }
      }
      server = {
        service = {
          type = "ClusterIP"
        }
      }
    })
  ]

  depends_on = [aws_eks_addon.coredns]
}
