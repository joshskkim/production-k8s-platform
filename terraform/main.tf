# Data sources
data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}
data "aws_eks_cluster_auth" "main" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
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
  multi_az = var.rds_multi_az
  # create_read_replica = var.rds_create_read_replica

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

  # SSL certificate ARN (optional)
  ssl_certificate_arn = var.ssl_certificate_arn
  ssl_policy          = var.ssl_policy

  # Access logs configuration
  access_logs_enabled = var.alb_access_logs_enabled
  access_logs_bucket  = var.alb_access_logs_bucket
  access_logs_prefix  = "${local.name_prefix}/alb"

  # Target groups for different services
  target_groups = {
    api-gateway = {
      port         = 8080
      protocol     = "HTTP"
      priority     = 100
      path_pattern = "/api/*"
      health_check = {
        enabled             = true
        healthy_threshold   = 2
        interval            = 30
        matcher             = "200"
        path                = "/api/health"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }
    }

    frontend = {
      port         = 80
      protocol     = "HTTP"
      priority     = 200
      path_pattern = "/*"
      health_check = {
        enabled             = true
        healthy_threshold   = 2
        interval            = 30
        matcher             = "200"
        path                = "/health"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }
    }

    monitoring = {
      port     = 3000
      protocol = "HTTP"
      priority = 300
      health_check = {
        enabled             = true
        healthy_threshold   = 2
        interval            = 30
        matcher             = "200"
        path                = "/api/health"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }
    }
  }

  tags = local.common_tags

  depends_on = [module.vpc]
}

# Monitoring Module - Script-based deployment (no Kubernetes resources in Terraform)
module "monitoring" {
  source = "./modules/monitoring"

  cluster_name = module.eks.cluster_name
  namespace    = "monitoring"
  aws_region   = var.aws_region

  # Storage configuration
  storage_class_name = "gp2"

  # Prometheus settings
  prometheus_storage_size   = var.prometheus_storage_size
  prometheus_retention      = var.prometheus_retention
  prometheus_retention_size = var.prometheus_retention_size
  prometheus_cpu_request    = var.prometheus_cpu_request
  prometheus_memory_request = var.prometheus_memory_request
  prometheus_cpu_limit      = var.prometheus_cpu_limit
  prometheus_memory_limit   = var.prometheus_memory_limit

  # Grafana settings
  grafana_enabled             = var.grafana_enabled
  grafana_admin_password      = var.grafana_admin_password
  grafana_persistence_enabled = var.grafana_persistence_enabled
  grafana_storage_size        = var.grafana_storage_size
  grafana_cpu_request         = var.grafana_cpu_request
  grafana_memory_request      = var.grafana_memory_request
  grafana_cpu_limit           = var.grafana_cpu_limit
  grafana_memory_limit        = var.grafana_memory_limit

  # Loki settings
  loki_enabled = var.loki_enabled

  # AlertManager configuration
  alertmanager_config = {
    global = {
      smtp_smarthost = var.smtp_smarthost
      smtp_from      = var.smtp_from
    }
    route = {
      group_by        = ["alertname", "cluster", "service"]
      group_wait      = "10s"
      group_interval  = "10s"
      repeat_interval = "12h"
      receiver        = "default"
    }
    receivers = [
      {
        name = "default"
        slack_configs = var.slack_webhook_url != "" ? [
          {
            api_url       = var.slack_webhook_url
            channel       = var.slack_channel
            username      = "AlertManager"
            color         = "danger"
            title         = "{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}"
            text          = "{{ range .Alerts }}{{ .Annotations.description }}{{ end }}"
            send_resolved = true
          }
        ] : []
        webhook_configs = var.slack_webhook_url == "" ? [
          {
            url = "http://127.0.0.1:5001/"
          }
        ] : []
      }
    ]
  }
}