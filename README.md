# Shared AWS platform

Terraform creates a shared VPC and EKS cluster. Crossplane v2 runs on that cluster and provisions app-specific resources (RDS, Redis, ECR, and so on).

## 1. Deploy EKS

```bash
cd terraform
terraform init
terraform apply
# Defaults live in variables.tf (profile kk, us-east-1). State is local (see backend.tf).
aws eks update-kubeconfig --region us-east-1 --name cool --profile kk
```

## Terraform resources

| Layer | Resource |
|---|---|
| Network | VPC (`10.42.0.0/16`) |
| ALB | 2 public subnets (`*-alb-*`), tagged `kubernetes.io/role/elb` |
| App | 2 private subnets (`*-app-*`) for EKS nodes and pods |
| DB | 2 isolated subnets + RDS subnet group `cool-db` |
| Redis | 2 isolated subnets + ElastiCache subnet group `cool-redis` |
| Network | Internet Gateway, NAT Gateway (app egress only), route tables |
| EKS | Cluster (`1.36`) |
| EKS | Self-managed nodes (2× `t3.medium`, AL2023, standard CPU credits) |
| EKS | Add-ons: `vpc-cni`, `coredns`, `kube-proxy`, `eks-pod-identity-agent` |
| IAM | `eksClusterRole`, `AmazonEKSNodeRole` |

Nodes run in app subnets. DB and Redis subnets have no NAT. The API endpoint is public so you can reach it from a laptop.

## KodeKloud playground limits

IAM is time-boxed and tightly scoped. This stack works around that:

- `us-east-1` only
- Cluster role must be `eksClusterRole`, node role must be `AmazonEKSNodeRole` (`iam:PassRole`)
- No managed node groups (`eks:CreateNodegroup` denied) — self-managed EC2 + ASG instead
- No `eks:AssociateAccessPolicy` — cannot attach `AmazonEKSClusterAdminPolicy`. Access entry exists without a policy; `kubectl` as `kk` has no admin RBAC
- EC2: `t2`/`t3` nano–medium only, CPU credits `standard` (unlimited is blocked)
- EKS 1.36 has no AL2 optimized AMI — nodes use Amazon Linux 2023
- No extra IAM policies (no KMS cluster encryption — `iam:TagPolicy` denied)
- Do not remove `default_tags` after the first apply (`iam:UntagRole` / `rds:RemoveTagsFromResource` denied)
- Local Terraform state only (see `backend.tf`)

## Next

Install Crossplane v2 on this cluster, then compose RDS, ElastiCache, and ECR for the [example-voting-app](https://github.com/dockersamples/example-voting-app).
