variable "aws_profile" {
  description = "Optional AWS CLI profile. Null uses the default credential chain."
  type        = string
  default     = null
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Platform name used in subnet/SG names and discovery tags."
  type        = string
  default     = "cool"
}

variable "use_terraform_stack" {
  description = "When true, RDS Postgres and ElastiCache Redis are created by Terraform. When false, leave them to Crossplane GitOps."
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
  default     = "10.42.0.0/16"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.36"
}

variable "node_instance_type" {
  description = "Managed node instance type. Must be Free Tier eligible on this account."
  type        = string
  default     = "c7i-flex.large"
}

variable "node_ami_type" {
  description = "EKS AMI for the node group. Use AL2023_x86_64_STANDARD with c7i-flex/m7i-flex; AL2023_ARM_64_STANDARD with t4g."
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "node_capacity_type" {
  description = "ON_DEMAND is required for Free Tier eligible types on this plan. SPOT is not free-plan eligible."
  type        = string
  default     = "ON_DEMAND"
}

variable "node_count" {
  description = "Fixed managed node count (min = desired = max; no autoscaling)."
  type        = number
  default     = 2
}

variable "github_owner" {
  description = "GitHub org or user that owns the voting-app repo."
  type        = string
  default     = "test-task-2"
}

variable "github_repo" {
  description = "Voting-app GitHub repository name."
  type        = string
  default     = "example-voting-app"
}

variable "github_branch" {
  description = "Branch CodePipeline tracks."
  type        = string
  default     = "main"
}

variable "acm_domain_name" {
  description = "ACM wildcard domain. DNS validation CNAMEs are created in Cloudflare."
  type        = string
  default     = "*.test-task.drunk.guru"
}

variable "cloudflare_zone_name" {
  description = "Cloudflare zone that hosts ACM DNS validation records."
  type        = string
  default     = "drunk.guru"
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for drunk.guru."
  type        = string
  default     = "e7a92c9cefa2fec6d0bbd02610d1de15"
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with Zone.Zone Read and Zone.DNS Edit. Null uses CLOUDFLARE_API_TOKEN."
  type        = string
  sensitive   = true
  default     = null
}
