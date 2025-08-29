terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket         = "resume-kubernetes-bucket"
    key            = "development/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
  }
}

module "payment_platform" {
  source = "../.."

  # Environment Configuration
  environment  = "development"
  project_name = "payment-platform"
  owner        = "platform-team"
  aws_region   = "us-east-1"

  # VPC Configuration
  vpc_cidr           = "10.2.0.0/16"
  az_count           = 2
  enable_nat_gateway = false # Cost savings for dev
  enable_vpn_gateway = false

  # EKS Configuration
  cluster_version = "1.28"

  node_groups = {
    main = {
      instance_types = ["t3.small", "t3.medium"]
      scaling_config = {
        desired_size = 1
        max_size     = 3
        min_size     = 1
      }
      disk_size     = 30
      capacity_type = "SPOT" # Cost savings for dev
      labels = {
        role        = "main"
        environment = "development"
      }
      taints = []
    }
  }

  enable_irsa                         = true
  enable_cluster_autoscaler           = false # Not needed for dev
  enable_aws_load_balancer_controller = true

  # RDS Configuration - Minimal for development
  rds_engine                       = "postgres"
  rds_engine_version               = "15.4"
  rds_instance_class               = "db.t3.micro"
  rds_database_name                = "payments"
  rds_username                     = "payments_user"
  rds_allocated_storage            = 20
  rds_max_allocated_storage        = 50
  rds_storage_encrypted            = false # Cost savings for dev
  rds_backup_retention_period      = 1
  rds_backup_window                = "03:00-04:00"
  rds_maintenance_window           = "sun:04:00-sun:05:00"
  rds_multi_az                     = false
  rds_create_read_replica          = false
  rds_monitoring_interval          = 0
  rds_performance_insights_enabled = false

  # ElastiCache Configuration - Minimal for development
  redis_node_type                  = "cache.t3.micro"
  redis_num_cache_clusters         = 1
  redis_parameter_group_family     = "redis7"
  redis_at_rest_encryption_enabled = false # Cost savings for dev
  redis_transit_encryption_enabled = false
  redis_auth_token_enabled         = false
  redis_automatic_failover_enabled = false
  redis_multi_az_enabled           = false

  # ALB Configuration
  ssl_certificate_arn   = null        # disables HTTPS (no cert)
  ssl_policy            = null        # will fall back to default
  alb_access_logs_enabled = false     # disables ALB logging
  alb_access_logs_bucket  = ""        # no bucket since logs disabled

  # Monitoring config
  grafana_enabled       = false       # disables Grafana
  loki_enabled          = false       # disables Loki

  # (Prometheus is always on, but you can minimize resources if you don’t want it heavy)
  prometheus_storage_size   = "1Gi"
  prometheus_retention      = "1d"
  prometheus_retention_size = "1GB"
}
