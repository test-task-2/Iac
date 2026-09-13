# BAD PRACTICE: local Terraform state.
#
# This is only for a short-lived KodeKloud playground account and throwaway
# test runs. Local state lives on one laptop, has no locking, and is easy
# to lose or overwrite. Do not copy this pattern to a real environment —
# use a remote backend (S3 with native lockfile, or Terraform Cloud) instead.
# DynamoDB locking is the old S3 backend pattern and is no longer needed.
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
