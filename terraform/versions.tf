terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.64.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile

  # Keep these tags. The playground cannot UntagRole / RemoveTagsFromResource,
  # so dropping default_tags after the first apply fails on existing resources.
  default_tags {
    tags = {
      Project   = var.cluster_name
      ManagedBy = "terraform"
    }
  }
}
