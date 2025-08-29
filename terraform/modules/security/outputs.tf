# terraform/modules/security/outputs.tf

# Core Security Groups
output "eks_cluster_security_group_id" {
  description = "Security group ID for EKS cluster"
  value       = aws_security_group.eks_cluster.id
}

output "eks_node_security_group_id" {
  description = "Security group ID for EKS nodes"
  value       = aws_security_group.eks_nodes.id
}

output "rds_security_group_id" {
  description = "Security group ID for RDS"
  value       = aws_security_group.rds.id
}

output "elasticache_security_group_id" {
  description = "Security group ID for ElastiCache"
  value       = aws_security_group.elasticache.id
}

output "alb_security_group_id" {
  description = "Security group ID for ALB"
  value       = aws_security_group.alb.id
}

# Optional Security Groups
output "bastion_security_group_id" {
  description = "Security group ID for bastion host"
  value       = var.enable_bastion_sg ? aws_security_group.bastion[0].id : null
}

output "vpc_endpoints_security_group_id" {
  description = "Security group ID for VPC endpoints"
  value       = var.enable_vpc_endpoints_sg ? aws_security_group.vpc_endpoints[0].id : null
}

output "lambda_security_group_id" {
  description = "Security group ID for Lambda functions"
  value       = var.enable_lambda_sg ? aws_security_group.lambda[0].id : null
}

output "efs_security_group_id" {
  description = "Security group ID for EFS"
  value       = var.enable_efs_sg ? aws_security_group.efs[0].id : null
}

output "monitoring_security_group_id" {
  description = "Security group ID for monitoring services"
  value       = var.enable_monitoring_sg ? aws_security_group.monitoring[0].id : null
}

# Summary outputs
output "security_groups_summary" {
  description = "Summary of all created security groups"
  value = {
    eks_cluster   = aws_security_group.eks_cluster.id
    eks_nodes     = aws_security_group.eks_nodes.id
    rds           = aws_security_group.rds.id
    elasticache   = aws_security_group.elasticache.id
    alb           = aws_security_group.alb.id
    bastion       = var.enable_bastion_sg ? aws_security_group.bastion[0].id : null
    vpc_endpoints = var.enable_vpc_endpoints_sg ? aws_security_group.vpc_endpoints[0].id : null
    lambda        = var.enable_lambda_sg ? aws_security_group.lambda[0].id : null
    efs           = var.enable_efs_sg ? aws_security_group.efs[0].id : null
    monitoring    = var.enable_monitoring_sg ? aws_security_group.monitoring[0].id : null
  }
}

output "all_security_group_ids" {
  description = "List of all security group IDs"
  value = compact([
    aws_security_group.eks_cluster.id,
    aws_security_group.eks_nodes.id,
    aws_security_group.rds.id,
    aws_security_group.elasticache.id,
    aws_security_group.alb.id,
    var.enable_bastion_sg ? aws_security_group.bastion[0].id : "",
    var.enable_vpc_endpoints_sg ? aws_security_group.vpc_endpoints[0].id : "",
    var.enable_lambda_sg ? aws_security_group.lambda[0].id : "",
    var.enable_efs_sg ? aws_security_group.efs[0].id : "",
    var.enable_monitoring_sg ? aws_security_group.monitoring[0].id : "",
  ])
}
