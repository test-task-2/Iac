# Shared AWS platform — network + EKS

Terraform creates the tagged VPC and an EKS cluster. LBC, Karpenter, and Crossplane should discover subnets and security groups by tags, not hardcoded IDs.

## Layout

| Pool | Subnets | Route | Discovery tags |
|---|---|---|---|
| ALB | `*-alb-*` | public + IGW | `Tier=alb`, `kubernetes.io/role/elb=1`, `kubernetes.io/cluster/<name>=shared` |
| Control plane | `*-control-plane-*` | isolated (no NAT) | `Tier=control-plane`, `kubernetes.io/cluster/<name>=shared` |
| Nodes | `*-nodes-*` | private + NAT | `Tier=nodes`, `karpenter.sh/discovery=<name>`, `kubernetes.io/role/internal-elb=1` |
| Karpenter SG | `${name}-karpenter` | — | `Tier=karpenter`, `karpenter.sh/discovery=<name>`; RDS 5432 and Redis 6379 only from this SG |
| RDS rotation Lambda SG | `${name}-rds-rotate` | private nodes + NAT | `Tier=rds-rotate`; RDS 5432 also from this SG |
| DB | `*-db-*` | isolated | `Tier=db`; subnet group `<name>-db` |
| Redis | `*-redis-*` | isolated | `Tier=redis`; subnet group `<name>-redis` |

EKS API is public (test convenience; restrict CIDRs or use private-only in production). Control plane ENIs sit in isolated subnets. The managed node group `system` (`role=system`) runs Argo CD, LBC, and Karpenter. App pods go on Karpenter Graviton nodes (`role=app`, Free Tier `t4g.small` / `t4g.micro`). Those nodes use IAM role `cool-karpenter-node` (ECR pull) and SG `cool-karpenter` (only path to RDS/Redis).

Defaults: Kubernetes **1.36**, **2** Free Tier `c7i-flex.large` nodes (min = desired = max, no autoscaling), **on-demand**. This account only allows Free Tier instance types: `m7i-flex.large` (largest, 8 GiB, x86), `c7i-flex.large` (4 GiB, x86), `t4g.small` / `t3.small` (2 GiB), `t4g.micro` / `t3.micro` (1 GiB).

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

RDS master password is created by RDS (`manageMasterUserPassword`) and stored in Secrets Manager (`rds!db-…`). Crossplane deploys Lambda `cool-postgres-app-rotate` (CloudFormation). That function logs in as the RDS master, creates application user `app` if needed, and rotates its password into `cool/postgres-app`. Apps should use `cool/postgres-app`, not the master secret.

ElastiCache Redis is a single-node Graviton `cache.t4g.micro` in subnet group `cool-redis`. Crossplane discovers SG `Tier=redis` and writes host/port to Secrets Manager `cool/redis`.
