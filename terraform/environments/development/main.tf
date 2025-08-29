# terraform/environments/development/main.tf - SIMPLIFIED VERSION

terraform {
  required_version = ">= 1.0"

  # Optional: Remove S3 backend for dev to avoid state conflicts
  # backend "s3" {
  #   bucket = "resume-kubernetes-bucket"
  #   key    = "development/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

module "payment_platform" {
  source = "../.."

  # Basic config
  environment  = "development"
  project_name = "payment-platform"
  owner        = "dev-team"
  aws_region   = "us-east-1"

  # Minimal VPC - single AZ, public subnets only
  vpc_cidr           = "10.2.0.0/16"
  az_count           = 1 # Single AZ
  enable_nat_gateway = false
  enable_vpn_gateway = false

  # EKS - public endpoint, minimal resources
  cluster_version         = "1.28"
  endpoint_private_access = false # Keep it simple
  endpoint_public_access  = true  # Easy access

  node_groups = {
    main = {
      instance_types = ["t3.small"]
      scaling_config = {
        desired_size = 1
        max_size     = 2
        min_size     = 1
      }
      disk_size     = 20 # Minimal
      capacity_type = "SPOT"
      labels = {
        role        = "main"
        environment = "development"
      }
      taints = []
    }
  }

  # Disable everything expensive/complex
  enable_cluster_autoscaler           = false
  enable_aws_load_balancer_controller = false
  enable_irsa                         = false

  # Skip RDS and Redis entirely for dev
  create_rds         = false
  create_elasticache = false

  # Skip ALB 
  create_alb = false

  # Minimal monitoring - Prometheus only
  grafana_enabled         = false
  loki_enabled            = false
  prometheus_storage_size = "1Gi"
  prometheus_retention    = "1d"
}

# Simple outputs
output "cluster_name" {
  value = module.payment_platform.cluster_name
}

output "connect_command" {
  value = "aws eks update-kubeconfig --region us-east-1 --name ${module.payment_platform.cluster_name}"
}