# 🏗️ Infrastructure Guide

## 📋 Overview

This document details the complete infrastructure architecture, including all AWS resources, Terraform modules, and environment configurations.

## 🏢 Infrastructure Architecture

### **Network Layer (VPC Module)**
```
VPC (10.0.0.0/16)
├── Public Subnets (10.0.1-3.0/24)     # ALB, NAT Gateways
├── Private Subnets (10.0.11-13.0/24)  # EKS Nodes, Applications  
└── Database Subnets (10.0.21-23.0/24) # RDS, ElastiCache
```

**Features:**
- **Multi-AZ deployment** across 3 availability zones
- **NAT Gateways** for private subnet internet access
- **VPC Flow Logs** for network monitoring
- **Route tables** with proper internet/NAT routing

### **Compute Layer (EKS Module)**
```
EKS Cluster
├── Managed Node Groups
│   ├── Main Nodes (m5.large, on-demand)
│   └── Spot Nodes (m5.large, spot instances)
├── Auto Scaling (3-20 nodes)
├── IRSA (IAM Roles for Service Accounts)
└── Add-ons (ALB Controller, Cluster Autoscaler)
```

**Features:**
- **Kubernetes 1.28** with managed control plane
- **Auto-scaling node groups** with mixed instance types
- **Pod-level IAM roles** via IRSA
- **Add-ons**: AWS Load Balancer Controller, Cluster Autoscaler
- **Security**: Private API endpoint, encrypted secrets

### **Data Layer**
```
Database Infrastructure
├── RDS PostgreSQL
│   ├── Primary (db.r5.large)
│   ├── Read Replica (Multi-AZ)
│   ├── Automated Backups (14 days)
│   └── Performance Insights
└── ElastiCache Redis
    ├── Cluster Mode (cache.r6g.large)
    ├── Multi-AZ Failover
    ├── Encryption (at rest + transit)
    └── Auth Tokens
```

**Features:**
- **PostgreSQL 15.4** with automatic minor version updates
- **Read replicas** for read scaling
- **Point-in-time recovery** and automated backups
- **Redis cluster mode** for high availability
- **Encryption everywhere** with customer-managed KMS keys

### **Security Layer (Security Module)**
```
Security Groups
├── EKS Cluster SG    # Control plane access
├── EKS Nodes SG      # Worker node communication  
├── RDS SG           # Database access from nodes
├── ElastiCache SG   # Cache access from nodes
├── ALB SG           # Internet-facing load balancer
└── Optional SGs     # Bastion, Lambda, Monitoring
```

**Features:**
- **Zero-trust networking** with minimal required access
- **Least privilege principles** throughout
- **Dynamic security group rules** based on resource relationships
- **Optional components** (bastion, VPC endpoints, monitoring)

## 📊 Environment Configurations

### **Production Environment**
```hcl
# High availability, performance optimized
rds_instance_class = "db.r5.large"
redis_node_type   = "cache.r6g.large"
node_groups = {
  main = {
    instance_types = ["m5.large", "m5.xlarge"]
    desired_size   = 5
    max_size      = 20
  }
}
rds_multi_az              = true
redis_multi_az_enabled    = true
backup_retention_period   = 14
```

### **Staging Environment** 
```hcl
# Balanced cost and functionality
rds_instance_class = "db.t3.medium"
redis_node_type   = "cache.t3.micro"
node_groups = {
  main = {
    instance_types = ["t3.medium", "t3.large"]
    desired_size   = 2
    max_size      = 5
  }
}
rds_multi_az              = false
redis_multi_az_enabled    = false
backup_retention_period   = 7
```

### **Development Environment**
```hcl
# Cost optimized for development
rds_instance_class = "db.t3.micro"
redis_node_type   = "cache.t3.micro"
enable_nat_gateway = false  # Cost savings
node_groups = {
  main = {
    instance_types = ["t3.small"]
    desired_size   = 1
    capacity_type  = "SPOT"  # Maximum savings
  }
}
storage_encrypted         = false  # Cost savings
backup_retention_period   = 1
```

## 🔧 Terraform Module Structure

### **Root Module (terraform/main.tf)**
- Orchestrates all infrastructure modules
- Defines common tags and naming conventions
- Manages inter-module dependencies

### **VPC Module (terraform/modules/vpc/)**
- Creates VPC with public/private/database subnets
- Sets up NAT Gateways and Internet Gateway
- Configures route tables and VPC Flow Logs
- **Outputs**: Subnet IDs, VPC ID, NAT Gateway IPs

### **EKS Module (terraform/modules/eks/)**
- Creates EKS cluster with managed node groups
- Sets up IRSA (IAM Roles for Service Accounts)
- Installs essential add-ons (ALB Controller, Cluster Autoscaler)
- **Outputs**: Cluster endpoint, OIDC issuer, node group ARNs

### **Security Module (terraform/modules/security/)**
- Creates all security groups with proper rules
- Implements least privilege access principles
- Supports optional components (bastion, monitoring)
- **Outputs**: All security group IDs for reference

### **RDS Module (terraform/modules/rds/)**
- Creates PostgreSQL instance with read replica
- Sets up automated backups and maintenance windows
- Configures Performance Insights and enhanced monitoring
- **Outputs**: Endpoints, secret ARNs, parameter group IDs

### **ElastiCache Module (terraform/modules/elasticache/)**
- Creates Redis cluster with Multi-AZ failover
- Configures encryption and authentication
- Sets up CloudWatch logging and monitoring
- **Outputs**: Endpoints, auth token secrets

## 💾 State Management

### **Backend Configuration**
```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "production/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

### **State File Organization**
- **Production**: `production/terraform.tfstate`
- **Staging**: `staging/terraform.tfstate`  
- **Development**: `development/terraform.tfstate`

## 🔐 Security & Compliance

### **Data Encryption**
- **EKS secrets**: Encrypted with customer-managed KMS keys
- **RDS storage**: Encrypted at rest with KMS
- **ElastiCache**: At-rest and in-transit encryption
- **S3 buckets**: Server-side encryption enabled

### **Network Security**
- **Private subnets** for all compute resources
- **Security groups** with minimal required access
- **VPC Flow Logs** for network monitoring
- **NAT Gateways** for controlled internet access

### **IAM Security**
- **IRSA** for pod-level AWS permissions
- **Least privilege** IAM policies
- **Service-linked roles** for AWS services
- **Cross-account access** support

## 📊 Monitoring & Observability

### **Infrastructure Monitoring**
- **CloudWatch metrics** for all AWS resources
- **VPC Flow Logs** for network analysis
- **EKS control plane logging** enabled
- **RDS Performance Insights** for database optimization

### **Cost Monitoring**
- **Resource tagging** for cost allocation
- **Environment-specific** resource sizing
- **Auto-scaling** to optimize costs
- **Spot instances** for non-critical workloads

## 🚀 Deployment Workflow

### **Infrastructure Deployment**
```bash
# 1. Choose environment
cd terraform/environments/production

# 2. Plan changes
terraform plan -var-file=terraform.tfvars

# 3. Apply changes
terraform apply -var-file=terraform.tfvars

# 4. Verify deployment
terraform output
```

### **Multi-Environment Strategy**
1. **Development first** - Test all changes
2. **Staging promotion** - Validate in production-like environment
3. **Production deployment** - Roll out tested changes

## 💡 Best Practices

### **Resource Naming**
- **Consistent prefixes**: `{environment}-{project-name}-{resource}`
- **Descriptive tags**: Environment, Project, Owner, ManagedBy

### **State Management**
- **Remote state** in S3 with encryption
- **State locking** with DynamoDB
- **Environment isolation** with separate state files

### **Security**
- **Least privilege** throughout
- **Encryption everywhere** 
- **Regular security updates** via managed services
- **Network segmentation** with security groups

This infrastructure is designed for **enterprise production workloads** and follows AWS Well-Architected Framework principles.