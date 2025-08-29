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

  # RDS Configuration - Full production setup
  rds_engine                       = "postgres"
  rds_engine_version               = "15.7"
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

  # ElastiCache Configuration - Full production setup
  redis_node_type                  = "cache.r6g.large"
  redis_num_cache_clusters         = 3
  redis_parameter_group_family     = "redis7"
  redis_at_rest_encryption_enabled = true
  redis_transit_encryption_enabled = true
  redis_auth_token_enabled         = true
  redis_automatic_failover_enabled = true
  redis_multi_az_enabled           = true

  # ALB Configuration - Production with SSL
  ssl_certificate_arn     = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012" # Update with your certificate ARN
  ssl_policy              = "ELBSecurityPolicy-TLS-1-2-2017-01"
  alb_access_logs_enabled = true
  alb_access_logs_bucket  = "your-alb-access-logs-bucket" # Update with your S3 bucket

  # Monitoring Configuration - Full production stack
  grafana_enabled = true
  loki_enabled    = true

  # Prometheus configuration for production
  prometheus_storage_size   = "100Gi"
  prometheus_retention      = "90d" # 3 months retention
  prometheus_retention_size = "80GB"
  prometheus_cpu_request    = "500m"
  prometheus_memory_request = "4Gi"
  prometheus_cpu_limit      = "2000m"
  prometheus_memory_limit   = "8Gi"

  # Grafana configuration for production
  grafana_admin_password      = "production-secure-password-change-immediately"
  grafana_persistence_enabled = true
  grafana_storage_size        = "20Gi"
  grafana_cpu_request         = "200m"
  grafana_memory_request      = "256Mi"
  grafana_cpu_limit           = "1000m"
  grafana_memory_limit        = "1Gi"

  # AlertManager configuration for production
  smtp_smarthost    = "smtp.your-domain.com:587"                            # Update with your SMTP server
  smtp_from         = "alerts-production@your-domain.com"                   # Update with your email
  slack_webhook_url = "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK" # Update with your Slack webhook
  slack_channel     = "#production-alerts"
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
    full_stack        = "Complete production monitoring stack with high availability"
  }
}

output "next_steps" {
  description = "Next steps after terraform apply"
  value = [
    "1. Run: aws eks update-kubeconfig --region us-east-1 --name production-payment-platform-cluster",
    "2. Run: ./deploy-monitoring.sh",
    "3. Set up external access to Grafana (LoadBalancer or Ingress)",
    "4. Configure monitoring dashboards and alerts",
    "5. Set up log retention policies",
    "6. Configure backup strategies for monitoring data",
    "7. Test all alerting channels (Slack, email, etc.)"
  ]
}

output "production_monitoring_urls" {
  description = "Production monitoring access URLs (via port-forward)"
  value = {
    grafana_local      = "kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
    prometheus_local   = "kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
    alertmanager_local = "kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093"
    loki_local         = "kubectl port-forward -n monitoring svc/loki 3100:3100"
  }
}

output "production_security_notes" {
  description = "Important security considerations for production"
  value = [
    "1. Change the Grafana admin password immediately after deployment",
    "2. Set up proper RBAC for monitoring namespace access",
    "3. Configure network policies to restrict monitoring access",
    "4. Set up proper SSL certificates for external access",
    "5. Enable audit logging for all monitoring components",
    "6. Regularly rotate authentication tokens and passwords",
    "7. Configure proper backup and disaster recovery procedures"
  ]
}