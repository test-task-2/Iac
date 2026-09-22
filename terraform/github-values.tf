resource "github_repository_file" "terraform_values" {
  repository = var.github_gitops_repo
  branch     = var.github_branch
  file       = "terraform-values.yaml"

  content = yamlencode({
    region = var.region
    vpcId  = module.vpc.vpc_id
    databaseSubnets = [
      for i, id in module.vpc.database_subnets : {
        name             = "${local.cluster}-db-${local.azs[i]}"
        availabilityZone = local.azs[i]
        id               = id
      }
    ]
    databaseSecurityGroupId = aws_security_group.db.id
    elasticacheSubnets = [
      for i, id in module.vpc.elasticache_subnets : {
        name             = "${local.cluster}-redis-${local.azs[i]}"
        availabilityZone = local.azs[i]
        id               = id
      }
    ]
    elasticacheSecurityGroupId = aws_security_group.redis.id
  })

  commit_message      = "Update terraform-values.yaml from Terraform."
  overwrite_on_create = true
}
