# Root module - orchestrates all infrastructure components

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# Local values
locals {
  name_prefix = "${var.environment}-${var.project_name}"

  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
    Owner       = var.owner
  }

  # Calculate subnet CIDRs
  vpc_cidr = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

# VPC Module
module "vpc" {
  source = "./modules/vpc"

  name_prefix = local.name_prefix
  vpc_cidr    = var.vpc_cidr
  azs         = local.azs

  enable_nat_gateway   = var.enable_nat_gateway
  enable_vpn_gateway   = var.enable_vpn_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.common_tags
}

# Security Module
module "security" {
  source = "./modules/security"

  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id

  tags = local.common_tags
}

# EKS Module
module "eks" {
  source = "./modules/eks"

  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id

  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  cluster_version = var.cluster_version

  # Node groups configuration
  node_groups = var.node_groups

  # Security groups
  cluster_security_group_id = module.security.eks_cluster_security_group_id
  node_security_group_id    = module.security.eks_node_security_group_id

  # Enable add-ons
  enable_irsa                         = var.enable_irsa
  enable_cluster_autoscaler           = var.enable_cluster_autoscaler
  enable_aws_load_balancer_controller = var.enable_aws_load_balancer_controller

  tags = local.common_tags

  depends_on = [module.vpc, module.security]
}

# RDS Module
module "rds" {
  source = "./modules/rds"

  name_prefix = local.name_prefix

  database_subnet_ids = module.vpc.database_subnet_ids
  security_group_ids  = [module.security.rds_security_group_id]

  # Database configuration
  engine         = var.rds_engine
  engine_version = var.rds_engine_version
  instance_class = var.rds_instance_class

  database_name = var.rds_database_name
  username      = var.rds_username

  # Storage configuration
  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  storage_encrypted     = var.rds_storage_encrypted

  # Backup configuration
  backup_retention_period = var.rds_backup_retention_period
  backup_window           = var.rds_backup_window
  maintenance_window      = var.rds_maintenance_window

  # High availability
  multi_az            = var.rds_multi_az
  create_read_replica = var.rds_create_read_replica

  # Monitoring
  monitoring_interval          = var.rds_monitoring_interval
  performance_insights_enabled = var.rds_performance_insights_enabled

  tags = local.common_tags

  depends_on = [module.vpc, module.security]
}

# ElastiCache Module
module "elasticache" {
  source = "./modules/elasticache"

  name_prefix = local.name_prefix

  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security.elasticache_security_group_id]

  # Redis configuration
  node_type              = var.redis_node_type
  num_cache_clusters     = var.redis_num_cache_clusters
  parameter_group_family = var.redis_parameter_group_family

  # Security
  at_rest_encryption_enabled = var.redis_at_rest_encryption_enabled
  transit_encryption_enabled = var.redis_transit_encryption_enabled
  auth_token_enabled         = var.redis_auth_token_enabled

  # High availability
  automatic_failover_enabled = var.redis_automatic_failover_enabled
  multi_az_enabled           = var.redis_multi_az_enabled

  tags = local.common_tags

  depends_on = [module.vpc, module.security]
}

# Application Load Balancer Module
module "alb" {
  source = "./modules/alb"

  name_prefix = local.name_prefix
  vpc_id      = module.vpc.vpc_id

  public_subnet_ids  = module.vpc.public_subnet_ids
  security_group_ids = [module.security.alb_security_group_id]

  # SSL/TLS configuration
  domain_name     = var.domain_name
  certificate_arn = var.certificate_arn
  ssl_policy      = var.alb_ssl_policy

  # Access logs
  enable_access_logs = var.alb_enable_access_logs

  tags = local.common_tags

  depends_on = [module.vpc, module.security]
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"

  name_prefix = local.name_prefix

  # CloudWatch configuration
  log_retention_days = var.cloudwatch_log_retention_days

  # EKS cluster information for logging
  cluster_name = module.eks.cluster_name

  tags = local.common_tags

  depends_on = [module.eks]
}