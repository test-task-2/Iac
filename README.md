# Shared AWS platform — network + EKS

Terraform creates the tagged VPC and an EKS cluster. LBC, Karpenter, and Crossplane should discover subnets and security groups by tags, not hardcoded IDs.

## Layout

| Pool | Subnets | Route | Discovery tags |
|---|---|---|---|
| ALB | `*-alb-*` | public + IGW | `Tier=alb`, `kubernetes.io/role/elb=1`, `kubernetes.io/cluster/<name>=shared` |
| Control plane | `*-control-plane-*` | isolated (no NAT) | `Tier=control-plane`, `kubernetes.io/cluster/<name>=shared` |
| Nodes | `*-nodes-*` | private + NAT | `Tier=nodes`, `karpenter.sh/discovery=<name>`, `kubernetes.io/role/internal-elb=1` |
| Karpenter SG | `${name}-karpenter` | — | `Tier=karpenter`, `karpenter.sh/discovery=<name>`; RDS 5432 and Redis 6379 only from this SG |
| DB | `*-db-*` | isolated | `Tier=db`; subnet group `<name>-db` |
| Redis | `*-redis-*` | isolated | `Tier=redis`; subnet group `<name>-redis` |

EKS is `terraform-aws-modules/eks/aws` (~> 21). API is public (test convenience; restrict CIDRs or use private-only in production). Control plane ENIs sit in isolated subnets. The managed node group `system` (`role=system`) runs Argo CD, LBC, and Karpenter. App pods go on Karpenter Graviton nodes (`role=app`). Those nodes use IAM role `cool-karpenter-node` (ECR pull) and SG `cool-karpenter` (only path to RDS/Redis).

Defaults: Kubernetes **1.36**, **3** `c7i-flex.large` system nodes (min = desired = max), **on-demand**. Override `node_instance_type` / `node_count` when you want more headroom.

CI for [example-voting-app](https://github.com/test-task-2/example-voting-app): three ECR repos (`cool/vote`, `cool/result`, `cool/worker`), Graviton CodeBuild (`linux/arm64` for Karpenter app nodes), and a V2 pipeline from GitHub `main`. The Build stage runs **vote**, **result**, and **worker** in parallel. Push to `main` starts a run once the GitHub connection is Available.

```bash
cd terraform
terraform init
terraform apply
aws eks update-kubeconfig --region us-east-1 --name cool
```

ACM issues `*.test-task.drunk.guru` (and the apex `test-task.drunk.guru`). Terraform creates the DNS validation CNAMEs in Cloudflare zone `drunk.guru` (DNS only, not proxied) and waits until ACM is Issued. Export a token with **Zone.Zone Read** and **Zone.DNS Edit**.

```bash
export CLOUDFLARE_API_TOKEN=...
```

Terraform creates Secrets Manager `cool/cloudflare` with no value. Put JSON `{"api-token":"..."}` in it by hand. External Secrets syncs that into the cluster; ExternalDNS creates DNS-only CNAMEs for Gateway HTTPRoutes under `test-task.drunk.guru`. The token needs **Zone.DNS Edit** on `drunk.guru`.

RDS uses a generated password written once to Secrets Manager `cool/postgres-app`. Apps read that secret. There is no rotation Lambda.

ElastiCache Redis is a single-node Graviton `cache.t4g.micro` in subnet group `cool-redis`. Crossplane discovers SG `Tier=redis` and writes host/port to Secrets Manager `cool/redis`.
