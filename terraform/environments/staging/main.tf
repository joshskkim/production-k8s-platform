terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

module "payment_platform" {
  source = "../.."

  # Environment Configuration
  environment  = "staging"
  project_name = "payment-platform"
  owner        = "platform-team"
  aws_region   = "us-east-1"

  # VPC Configuration
  vpc_cidr           = "10.1.0.0/16"
  az_count           = 2
  enable_nat_gateway = true
  enable_vpn_gateway = false

  # EKS Configuration
  cluster_version = "1.28"

  node_groups = {
    main = {
      instance_types = ["t3.medium", "t3.large"]
      scaling_config = {
        desired_size = 2
        max_size     = 5
        min_size     = 1
      }
      disk_size     = 50
      capacity_type = "ON_DEMAND"
      labels = {
        role        = "main"
        environment = "staging"
      }
      taints = []
    }
  }

  enable_irsa                         = true
  enable_cluster_autoscaler           = true
  enable_aws_load_balancer_controller = true

  # RDS Configuration - Smaller for staging
  rds_engine                       = "postgres"
  rds_engine_version               = "15.4"
  rds_instance_class               = "db.t3.medium"
  rds_database_name                = "payments"
  rds_username                     = "payments_user"
  rds_allocated_storage            = 50
  rds_max_allocated_storage        = 200
  rds_storage_encrypted            = true
  rds_backup_retention_period      = 7
  rds_backup_window                = "03:00-04:00"
  rds_maintenance_window           = "sun:04:00-sun:05:00"
  rds_multi_az                     = false
  rds_create_read_replica          = false
  rds_monitoring_interval          = 0
  rds_performance_insights_enabled = false

  # ElastiCache Configuration - Smaller for staging
  redis_node_type                  = "cache.t3.micro"
  redis_num_cache_clusters         = 1
  redis_parameter_group_family     = "redis7"
  redis_at_rest_encryption_enabled = true
  redis_transit_encryption_enabled = true
  redis_auth_token_enabled         = true
  redis_automatic_failover_enabled = false
  redis_multi_az_enabled           = false

  # ALB Configuration
  domain_name            = "staging-api.your-domain.com"
  certificate_arn        = ""
  alb_ssl_policy         = "ELBSecurityPolicy-TLS-1-2-2017-01"
  alb_enable_access_logs = false

  # Monitoring Configuration
  cloudwatch_log_retention_days = 7
}
