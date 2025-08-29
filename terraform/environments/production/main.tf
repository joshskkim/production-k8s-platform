terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "production/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

module "payment_platform" {
  source = "../.."

  # Environment Configuration
  environment  = "production"
  project_name = "payment-platform"
  owner        = "platform-team"
  aws_region   = "us-east-1"

  # VPC Configuration
  vpc_cidr           = "10.0.0.0/16"
  az_count           = 3
  enable_nat_gateway = true
  enable_vpn_gateway = false

  # EKS Configuration
  cluster_version = "1.28"

  node_groups = {
    main = {
      instance_types = ["m5.large", "m5.xlarge"]
      scaling_config = {
        desired_size = 5
        max_size     = 20
        min_size     = 3
      }
      disk_size     = 100
      capacity_type = "ON_DEMAND"
      labels = {
        role        = "main"
        environment = "production"
      }
      taints = []
    }
    spot = {
      instance_types = ["m5.large", "m5.xlarge", "m4.large"]
      scaling_config = {
        desired_size = 2
        max_size     = 10
        min_size     = 0
      }
      disk_size     = 100
      capacity_type = "SPOT"
      labels = {
        role        = "spot"
        environment = "production"
      }
      taints = [
        {
          key    = "spot"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]
    }
  }

  enable_irsa                         = true
  enable_cluster_autoscaler           = true
  enable_aws_load_balancer_controller = true

  # RDS Configuration
  rds_engine                       = "postgres"
  rds_engine_version               = "15.4"
  rds_instance_class               = "db.r5.large"
  rds_database_name                = "payments"
  rds_username                     = "payments_user"
  rds_allocated_storage            = 200
  rds_max_allocated_storage        = 2000
  rds_storage_encrypted            = true
  rds_backup_retention_period      = 14
  rds_backup_window                = "03:00-04:00"
  rds_maintenance_window           = "sun:04:00-sun:05:00"
  rds_multi_az                     = true
  rds_create_read_replica          = true
  rds_monitoring_interval          = 60
  rds_performance_insights_enabled = true

  # ElastiCache Configuration
  redis_node_type                  = "cache.r6g.large"
  redis_num_cache_clusters         = 3
  redis_parameter_group_family     = "redis7"
  redis_at_rest_encryption_enabled = true
  redis_transit_encryption_enabled = true
  redis_auth_token_enabled         = true
  redis_automatic_failover_enabled = true
  redis_multi_az_enabled           = true

  # ALB Configuration
  domain_name            = "api.your-domain.com"
  certificate_arn        = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
  alb_ssl_policy         = "ELBSecurityPolicy-TLS-1-2-2017-01"
  alb_enable_access_logs = true

  # Monitoring Configuration
  cloudwatch_log_retention_days = 14
}
