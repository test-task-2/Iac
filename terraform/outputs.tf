output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_arn" {
  value = module.eks.cluster_arn
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "alb_subnet_ids" {
  description = "Public subnets for internet-facing ALBs."
  value       = module.vpc.public_subnets
}

output "app_subnet_ids" {
  description = "Private subnets for EKS nodes and application pods."
  value       = module.vpc.private_subnets
}

output "db_subnet_ids" {
  description = "Isolated subnets for RDS PostgreSQL."
  value       = module.vpc.database_subnets
}

output "redis_subnet_ids" {
  description = "Isolated subnets for ElastiCache Redis."
  value       = module.vpc.elasticache_subnets
}

output "db_subnet_group_name" {
  value = module.vpc.database_subnet_group_name
}

output "redis_subnet_group_name" {
  value = module.vpc.elasticache_subnet_group_name
}

output "configure_kubectl" {
  description = "Command to point kubectl at this cluster."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name} --profile ${var.aws_profile}"
}

output "argocd_port_forward" {
  description = "Port-forward the Argo CD UI (admin / password from argocd_admin_password)."
  value       = "kubectl -n argocd port-forward svc/argocd-server 8080:80"
}

output "argocd_admin_password" {
  description = "Command to print the initial Argo CD admin password."
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
}
