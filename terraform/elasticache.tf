locals {
  redis_id     = "${local.cluster}-redis"
  redis_secret = "${local.cluster}/redis"
}

resource "aws_elasticache_replication_group" "redis" {
  count = var.use_terraform_stack ? 1 : 0

  replication_group_id       = local.redis_id
  description                = local.redis_id
  engine                     = "redis"
  engine_version             = "7.1"
  node_type                  = "cache.t4g.micro"
  num_cache_clusters         = 1
  port                       = 6379
  parameter_group_name       = "default.redis7"
  subnet_group_name          = module.vpc.elasticache_subnet_group_name
  security_group_ids         = [aws_security_group.redis.id]
  at_rest_encryption_enabled = true
  transit_encryption_enabled = false
  automatic_failover_enabled = false
  multi_az_enabled           = false
  snapshot_retention_limit   = 0
  apply_immediately          = true
  auto_minor_version_upgrade = true

  tags = {
    Name = local.redis_id
  }
}

resource "aws_secretsmanager_secret" "redis" {
  count                   = var.use_terraform_stack ? 1 : 0
  name                    = local.redis_secret
  description             = "ElastiCache Redis endpoint for ${local.redis_id}"
  recovery_window_in_days = 0

  tags = {
    Name = local.redis_secret
  }
}

resource "aws_secretsmanager_secret_version" "redis" {
  count     = var.use_terraform_stack ? 1 : 0
  secret_id = aws_secretsmanager_secret.redis[0].id
  secret_string = jsonencode({
    engine = "redis"
    host   = aws_elasticache_replication_group.redis[0].primary_endpoint_address
    port   = tostring(aws_elasticache_replication_group.redis[0].port)
  })
}
