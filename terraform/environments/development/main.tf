terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket       = "resume-kubernetes-bucket"
    key          = "development/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
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
  rds_engine_version               = "15.7"
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
  # rds_create_read_replica          = false
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
  ssl_certificate_arn     = null  # disables HTTPS (no cert)
  ssl_policy              = null  # will fall back to default
  alb_access_logs_enabled = false # disables ALB logging
  alb_access_logs_bucket  = ""    # no bucket since logs disabled

  # Monitoring config - Script-based deployment
  grafana_enabled = false # disables Grafana for cost savings
  loki_enabled    = false # disables Loki for cost savings

  # Prometheus is always on, but minimal resources for dev
  prometheus_storage_size   = "5Gi" # Reduced from 1Gi to 5Gi (minimum for dev)
  prometheus_retention      = "3d"  # Reduced from 1d to 3d
  prometheus_retention_size = "4GB" # Reduced from 1GB to 4GB

  # Minimal Prometheus resources for development
  prometheus_cpu_request    = "100m" # Reduced CPU request
  prometheus_memory_request = "1Gi"  # Reduced memory request
  prometheus_cpu_limit      = "500m" # Reduced CPU limit
  prometheus_memory_limit   = "2Gi"  # Reduced memory limit

  # Grafana disabled, but keeping variables for consistency
  grafana_admin_password      = "dev-password"
  grafana_persistence_enabled = false
  grafana_storage_size        = "1Gi"
  grafana_cpu_request         = "50m"
  grafana_memory_request      = "64Mi"
  grafana_cpu_limit           = "200m"
  grafana_memory_limit        = "256Mi"

  # AlertManager configuration for development
  smtp_smarthost    = "localhost:587"
  smtp_from         = "alerts-dev@example.org"
  slack_webhook_url = "" # No Slack for dev
  slack_channel     = "#dev-alerts"
}

# Output the monitoring deployment information
output "monitoring_deployment_info" {
  description = "Information about monitoring deployment"
  value = {
    cluster_name      = module.payment_platform.deployment_info.cluster_name
    aws_region        = module.payment_platform.deployment_info.aws_region
    environment       = module.payment_platform.deployment_info.environment
    deployment_script = "Run './deploy-monitoring.sh' after terraform apply completes"
    grafana_enabled   = false
    loki_enabled      = false
    prometheus_only   = "Minimal Prometheus deployment for development"
  }
}

output "next_steps" {
  description = "Next steps after terraform apply"
  value = [
    "1. Run: aws eks update-kubeconfig --region us-east-1 --name development-payment-platform-cluster",
    "2. Run: ./deploy-monitoring.sh",
    "3. Access Prometheus: kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090",
    "4. View cluster: kubectl get nodes",
    "5. View monitoring pods: kubectl get pods -n monitoring"
  ]
}