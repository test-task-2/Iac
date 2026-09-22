# Generated password is write-only-set on RDS and Secrets Manager so the
# value never lands in Terraform state. No rotation.
locals {
  postgres_id                  = "${local.cluster}-postgres"
  postgres_app_secret          = "${local.cluster}/postgres-app"
  postgres_username            = "appadmin"
  postgres_password_wo_version = 1
}

resource "aws_db_parameter_group" "postgres" {
  count  = var.use_terraform_stack ? 1 : 0
  name   = "${local.cluster}-postgres16"
  family = "postgres16"

  parameter {
    name  = "rds.force_ssl"
    value = "0"
  }
}

ephemeral "random_password" "postgres" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_instance" "postgres" {
  count = var.use_terraform_stack ? 1 : 0

  identifier                 = local.postgres_id
  engine                     = "postgres"
  engine_version             = "16.13"
  instance_class             = "db.t3.micro"
  allocated_storage          = 20
  storage_type               = "gp2"
  storage_encrypted          = true
  db_name                    = "app"
  username                   = local.postgres_username
  password_wo                = ephemeral.random_password.postgres.result
  password_wo_version        = local.postgres_password_wo_version
  parameter_group_name       = aws_db_parameter_group.postgres[0].name
  db_subnet_group_name       = module.vpc.database_subnet_group_name
  vpc_security_group_ids     = [aws_security_group.db.id]
  publicly_accessible        = false
  multi_az                   = false
  backup_retention_period    = 0
  skip_final_snapshot        = true
  deletion_protection        = false
  auto_minor_version_upgrade = true
  apply_immediately          = true

  tags = {
    Name = local.postgres_id
  }
}

resource "aws_secretsmanager_secret" "postgres_app" {
  name                    = local.postgres_app_secret
  description             = "RDS credentials for ${local.postgres_id}."
  recovery_window_in_days = 0

  tags = {
    Name = local.postgres_app_secret
  }
}

moved {
  from = aws_secretsmanager_secret.postgres_app[0]
  to   = aws_secretsmanager_secret.postgres_app
}

resource "aws_secretsmanager_secret_version" "postgres_app" {
  secret_id = aws_secretsmanager_secret.postgres_app.id

  secret_string_wo = jsonencode({
    engine          = "postgres"
    host            = try(aws_db_instance.postgres[0].address, "")
    port            = try(tostring(aws_db_instance.postgres[0].port), "5432")
    dbname          = try(aws_db_instance.postgres[0].db_name, "app")
    username        = local.postgres_username
    password        = ephemeral.random_password.postgres.result
    "root-password" = ephemeral.random_password.postgres.result
  })
  # Bump when the instance appears so the stored password matches RDS.
  secret_string_wo_version = local.postgres_password_wo_version + (var.use_terraform_stack ? 1 : 0)
}
