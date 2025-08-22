# Production-Ready Kubernetes Platform

A comprehensive Infrastructure-as-Code solution for deploying scalable, secure, and observable Kubernetes platforms on AWS. This project demonstrates enterprise-grade practices for container orchestration, monitoring, and application deployment.

## 🏗️ Architecture Overview

This platform provides a complete production-ready environment with the following components:

**Infrastructure Layer:**
- Multi-AZ VPC with public/private subnets
- Amazon EKS cluster with managed node groups
- RDS PostgreSQL for persistent data
- ElastiCache Redis for caching
- Application Load Balancers for traffic distribution

**Observability Stack:**
- Prometheus for metrics collection
- Grafana for visualization
- Loki for log aggregation
- AlertManager for notification management

**Application Platform:**
- Sample microservices demonstrating best practices
- Comprehensive health checks and monitoring
- Horizontal Pod Autoscaling (HPA)
- Network policies for security

**Security Features:**
- Encryption at rest and in transit
- IAM roles with least privilege principles
- Network segmentation with security groups
- Pod security contexts and policies

## 🚀 Quick Start

### Prerequisites

Ensure you have the following tools installed:
- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/) >= 1.28
- [Helm](https://helm.sh/docs/intro/install/) >= 3.0
- [AWS CLI](https://aws.amazon.com/cli/) >= 2.0

### AWS Configuration

1. Configure AWS credentials:
```bash
aws configure
```

2. Create an S3 bucket for Terraform state:
```bash
aws s3 mb s3://your-terraform-state-bucket
```

3. Update the backend configuration in `terraform/main.tf`

### Deployment

1. Clone the repository:
```bash
git clone <repository-url>
cd production-k8s-platform
```

2. Deploy the entire stack:
```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

3. Access the applications:
```bash
# Get API Gateway URL
kubectl get service api-gateway

# Port-forward for Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

## 📊 Monitoring and Observability

### Accessing Grafana Dashboards

1. Port-forward to Grafana:
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

2. Open http://localhost:3000
   - Username: admin
   - Password: change-me-in-production

### Key Metrics to Monitor

- **Cluster Health**: Node status, pod resource usage
- **Application Performance**: Request latency, error rates
- **Infrastructure**: CPU, memory, disk usage
- **Business Metrics**: Request volume, user activity

## 🔧 Customization

### Environment Configuration

Modify variables in `terraform/main.tf`:
```hcl
variable "environment" {
  default = "production"  # Change to prod, staging, etc.
}

variable "aws_region" {
  default = "us-east-1"   # Change to your preferred region
}
```

### Adding New Applications

1. Create application manifests in `kubernetes/apps/`
2. Build and push container images
3. Update deployment scripts

### Scaling Configuration

Modify HPA settings in application manifests:
```yaml
spec:
  minReplicas: 5      # Increase for production
  maxReplicas: 50     # Scale based on requirements
```

## 🛠️ Operations

### Backup and Recovery

**Database Backups:**
- Automated RDS snapshots (configured in Terraform)
- Point-in-time recovery available

**Configuration Backups:**
```bash
# Backup Kubernetes configurations
kubectl get all --all-namespaces -o yaml > cluster-backup.yaml
```

### Disaster Recovery

1. **Infrastructure Recovery:**
```bash
terraform apply  # Recreates infrastructure from code
```

2. **Application Recovery:**
```bash
kubectl apply -f kubernetes/  # Restores application state
```

### Security Updates

**Node Updates:**
- EKS managed node groups automatically update
- Configure maintenance windows in AWS

**Application Updates:**
```bash
# Rolling update deployment
kubectl set image deployment/api-gateway api-gateway=new-image:tag
```

## 📈 Performance Tuning

### Resource Optimization

1. **Right-sizing**: Monitor resource usage and adjust requests/limits
2. **Auto-scaling**: Configure HPA based on CPU/memory metrics
3. **Storage**: Use GP3 volumes for better performance
4. **Networking**: Implement service mesh for advanced traffic management

### Cost Optimization

1. **Spot Instances**: Use for non-critical workloads
2. **Reserved Instances**: Purchase for predictable workloads
3. **Resource Monitoring**: Set up billing alerts
4. **Cluster Autoscaler**: Automatically scale nodes based on demand

## 🔒 Security Best Practices

This platform implements comprehensive security measures:

**Network Security:**
- Private subnets for workloads
- Security groups with minimal access
- VPC flow logs for monitoring

**Identity and Access:**
- IAM roles for service accounts (IRSA)
- Pod security contexts
- RBAC policies

**Data Protection:**
- Encryption at rest (EBS, RDS)
- Encryption in transit (TLS)
- Secrets management with Kubernetes secrets

## 🧪 Testing

### Infrastructure Testing
```bash
# Validate Terraform configuration
terraform validate
terraform plan

# Test Kubernetes connectivity
kubectl cluster-info
kubectl get nodes
```

### Application Testing
```bash
# Run health checks
curl http://<gateway-url>/health

# Load testing
kubectl run -it --rm load-test --image=busybox --restart=Never -- /bin/sh
```

## 🐛 Troubleshooting

### Common Issues

**EKS Node Issues:**
```bash
# Check node status
kubectl get nodes
kubectl describe node <node-name>

# Check node logs
kubectl logs -n kube-system <aws-node-pod>
```

**Application Issues:**
```bash
# Check pod status
kubectl get pods
kubectl describe pod <pod-name>
kubectl logs <pod-name>

# Check service connectivity
kubectl get svc
kubectl port-forward svc/<service-name> 8080:80
```

**Terraform Issues:**
```bash
# Enable detailed logging
export TF_LOG=DEBUG
terraform apply

# Import existing resources
terraform import <resource-type>.<name> <resource-id>
```

## 📚 Additional Resources

- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Prometheus Monitoring](https://prometheus.io/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests and documentation
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.