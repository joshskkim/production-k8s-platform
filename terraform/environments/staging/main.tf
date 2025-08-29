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
  ssl_certificate_arn     = null # Add your certificate ARN here if you have one
  ssl_policy              = "ELBSecurityPolicy-TLS-1-2-2017-01"
  alb_access_logs_enabled = false
  alb_access_logs_bucket  = ""

  # Monitoring Configuration - Script-based deployment
  grafana_enabled = true
  loki_enabled    = true

  # Prometheus configuration for staging
  prometheus_storage_size   = "20Gi"
  prometheus_retention      = "15d"
  prometheus_retention_size = "18GB"
  prometheus_cpu_request    = "200m"
  prometheus_memory_request = "2Gi"
  prometheus_cpu_limit      = "1000m"
  prometheus_memory_limit   = "4Gi"

  # Grafana configuration for staging
  grafana_admin_password      = "staging-secure-password-change-me"
  grafana_persistence_enabled = true
  grafana_storage_size        = "5Gi"
  grafana_cpu_request         = "100m"
  grafana_memory_request      = "128Mi"
  grafana_cpu_limit           = "500m"
  grafana_memory_limit        = "512Mi"

  # AlertManager configuration for staging
  smtp_smarthost    = "localhost:587"
  smtp_from         = "alerts-staging@your-domain.com"
  slack_webhook_url = "" # Add your Slack webhook URL here
  slack_channel     = "#staging-alerts"
}

# Output the monitoring deployment information
output "monitoring_deployment_info" {
  description = "Information about monitoring deployment"
  value = {
    cluster_name      = module.payment_platform.deployment_info.cluster_name
    aws_region        = module.payment_platform.deployment_info.aws_region
    environment       = module.payment_platform.deployment_info.environment
    deployment_script = "Run './deploy-monitoring.sh' after terraform apply completes"
    grafana_enabled   = true
    loki_enabled      = true
    full_stack        = "Complete monitoring stack for staging environment"
  }
}

output "next_steps" {
  description = "Next steps after terraform apply"
  value = [
    "1. Run: aws eks update-kubeconfig --region us-east-1 --name staging-payment-platform-cluster",
    "2. Run: ./deploy-monitoring.sh",
    "3. Access Grafana: kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80",
    "4. Access Prometheus: kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090",
    "5. Access Loki: kubectl port-forward -n monitoring svc/loki 3100:3100",
    "6. View cluster: kubectl get nodes",
    "7. View monitoring pods: kubectl get pods -n monitoring"
  ]
}

output "monitoring_credentials" {
  description = "Monitoring access credentials"
  value = {
    grafana_username         = "admin"
    grafana_password_command = "kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath=\"{.data.admin-password}\" | base64 --decode"
  }
  sensitive = true
}