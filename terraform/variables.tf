variable "aws_profile" {
  description = "AWS CLI profile used to deploy. KodeKloud playground profile is kk."
  type        = string
  default     = "kk"
}

variable "region" {
  description = "AWS region. KodeKloud playground SCP allows us-east-1 only."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Shared EKS cluster and VPC name. Not app-specific."
  type        = string
  default     = "cool"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.36"
}

variable "vpc_cidr" {
  description = "VPC CIDR block."
  type        = string
  default     = "10.42.0.0/16"
}

variable "node_instance_type" {
  description = "Self-managed node instance type. KodeKloud allows t2/t3 nano–medium only."
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired node count. Crossplane AWS providers need headroom."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum node count."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum node count."
  type        = number
  default     = 4
}
