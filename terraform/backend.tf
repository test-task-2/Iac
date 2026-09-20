# Prefer a remote backend later (S3 lockfile or Terraform Cloud).
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
