
output "vpc" {
  description = "VPC information"
  value = {
    vpc_id              = module.vpc.vpc_id
    vpc_cidr_block      = module.vpc.vpc_cidr_block
    private_subnet_ids  = module.vpc.private_subnet_ids
    public_subnet_ids   = module.vpc.public_subnet_ids
    database_subnet_ids = module.vpc.database_subnet_ids
  }
}

output "eks" {
  description = "EKS cluster information"
  value = {
    cluster_id              = module.eks.cluster_id
    cluster_name            = module.eks.cluster_name
    cluster_endpoint        = module.eks.cluster_endpoint
    cluster_version         = module.eks.cluster_version
    cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
    oidc_provider_arn       = module.eks.oidc_provider_arn
    cluster_role_arn        = module.eks.cluster_role_arn
    node_group_role_arn     = module.eks.node_group_role_arn
  }
  sensitive = true
}

output "database" {
  description = "Database information"
  value = {
    db_instance_id       = module.rds.db_instance_id
    db_instance_endpoint = module.rds.db_instance_endpoint
    db_instance_port     = module.rds.db_instance_port
    db_instance_name     = module.rds.db_instance_name
    db_secret_arn        = module.rds.db_secret_arn
  }
  sensitive = true
}

output "cache" {
  description = "ElastiCache information"
  value = {
    primary_endpoint_address = module.elasticache.primary_endpoint_address
    reader_endpoint_address  = module.elasticache.reader_endpoint_address
    port                     = module.elasticache.port
    auth_token_secret_arn    = module.elasticache.auth_token_secret_arn
  }
  sensitive = true
}

output "load_balancer" {
  description = "Load balancer information"
  value       = module.alb
}

output "security_groups" {
  description = "Security group information"
  value = {
    eks_cluster_sg_id = module.security.eks_cluster_security_group_id
    eks_node_sg_id    = module.security.eks_node_security_group_id
    rds_sg_id         = module.security.rds_security_group_id
    elasticache_sg_id = module.security.elasticache_security_group_id
    alb_sg_id         = module.security.alb_security_group_id
  }
}

# Deployment information for applications
output "deployment_info" {
  description = "Information needed for application deployment"
  value = {
    cluster_name    = module.eks.cluster_name
    aws_region      = var.aws_region
    environment     = var.environment
    vpc_id          = module.vpc.vpc_id
    private_subnets = module.vpc.private_subnet_ids
    public_subnets  = module.vpc.public_subnet_ids
  }
}
