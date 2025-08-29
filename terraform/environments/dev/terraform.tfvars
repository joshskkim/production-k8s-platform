# terraform/environments/development/terraform.tfvars

# General Configuration
environment  = "development"
project_name = "payment-platform"
owner        = "platform-team"
aws_region   = "us-east-1"

# Network Configuration - Different CIDR to avoid conflicts
vpc_cidr           = "10.2.0.0/16"
az_count           = 2
enable_nat_gateway = false # Cost savings for dev
enable_vpn_gateway = false

# EKS Configuration
cluster_version = "1.28"

# Database Configuration - Minimal for development
rds_instance_class               = "db.t3.micro"
rds_allocated_storage            = 20
rds_max_allocated_storage        = 50
rds_backup_retention_period      = 1
rds_multi_az                     = false
rds_create_read_replica          = false
rds_monitoring_interval          = 0
rds_performance_insights_enabled = false
rds_storage_encrypted            = false # Cost savings

# Redis Configuration - Minimal for development
redis_node_type                  = "cache.t3.micro"
redis_num_cache_clusters         = 1
redis_at_rest_encryption_enabled = false # Cost savings
redis_transit_encryption_enabled = false
redis_auth_token_enabled         = false
redis_automatic_failover_enabled = false
redis_multi_az_enabled           = false

# Domain and SSL - No custom domain for dev
domain_name     = ""
certificate_arn = ""

# Maximum cost optimizations for development
alb_enable_access_logs        = false
cloudwatch_log_retention_days = 3