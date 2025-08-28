# Production Kubernetes Payment Platform

A comprehensive Infrastructure-as-Code solution for deploying scalable, secure, and observable payment processing platforms on AWS. This project demonstrates enterprise-grade practices for container orchestration, real-time fraud detection, risk management, and financial services infrastructure.

[![Build Applications](https://github.com/joshskkim/production-k8s-platform/actions/workflows/applications.yml/badge.svg)](https://github.com/joshskkim/production-k8s-platform/actions/workflows/applications.yml)
[![Security Scan](https://github.com/joshskkim/production-k8s-platform/actions/workflows/security-scan.yml/badge.svg)](https://github.com/joshskkim/production-k8s-platform/actions/workflows/security-scan.yml)
![License](https://img.shields.io/badge/license-MIT-blue.svg)

## 🏗️ Architecture Overview

This platform provides a complete production-ready payment processing environment with the following components:

### Infrastructure Layer
- **Multi-AZ VPC** with public/private subnets
- **Amazon EKS cluster** with managed node groups  
- **RDS PostgreSQL** for transactional data persistence
- **ElastiCache Redis** for real-time fraud detection and caching
- **Application Load Balancers** for traffic distribution

### Application Platform
- **Payment Processing Service** (Java Spring Boot)
  - Real-time transaction processing with sub-200ms response times
  - Advanced fraud detection with velocity checks and pattern analysis
  - Comprehensive risk management with position tracking and limit enforcement
  - STOMP WebSocket streaming for real-time monitoring
- **API Gateway Service** (Go)
  - Request routing and API orchestration
  - Authentication and rate limiting
- **Sample microservices** demonstrating best practices

### Observability Stack
- **Prometheus** for metrics collection
- **Grafana** for visualization and dashboards
- **Loki** for log aggregation
- **AlertManager** for notification management
- **Real-time WebSocket** streaming for live transaction monitoring

### Security Features
- **Encryption** at rest and in transit
- **IAM roles** with least privilege principles
- **Network segmentation** with security groups
- **Pod security contexts** and policies
- **Automated security scanning** with Trivy

## 🚀 Quick Start

### Prerequisites

Ensure you have the following tools installed:
- [AWS CLI](https://aws.amazon.com/cli/) v2.0+
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) v1.24+
- [Terraform](https://www.terraform.io/downloads.html) v1.5+
- [Docker](https://docs.docker.com/get-docker/) v20.0+
- [Helm](https://helm.sh/docs/intro/install/) v3.8+

### Installation

1. **Configure AWS credentials:**
   ```bash
   aws configure
   ```

2. **Create an S3 bucket for Terraform state:**
   ```bash
   aws s3 mb s3://your-terraform-state-bucket
   ```

3. **Update the backend configuration in `terraform/main.tf`**

4. **Clone the repository:**
   ```bash
   git clone https://github.com/joshskkim/production-k8s-platform.git
   cd production-k8s-platform
   ```

5. **Deploy the entire stack:**
   ```bash
   chmod +x scripts/deploy.sh
   ./scripts/deploy.sh
   ```

## 💳 Payment Platform Features

### Real-Time Payment Processing
- **High-throughput processing**: 10K+ transactions per day
- **Sub-200ms response times** with optimized database queries
- **Multi-currency support** with configurable exchange rates
- **Comprehensive transaction logging** and audit trails

### Advanced Fraud Detection
- **Real-time risk scoring** with configurable rules engine
- **Velocity checks** using Redis for sub-millisecond lookups
- **Pattern analysis** for suspicious transaction detection  
- **Machine learning-ready** data pipeline for model integration

### Risk Management & Position Tracking
- **Real-time position monitoring** across all merchants
- **Multi-level limits** (transaction, daily, monthly)
- **Automated risk alerts** with configurable thresholds
- **Portfolio-wide exposure** tracking and reporting

### WebSocket Streaming
- **STOMP protocol** for enterprise-grade messaging
- **Real-time transaction feeds** similar to market data streams
- **Live fraud alerts** and risk notifications
- **Interactive dashboards** with live updates

## 📊 Monitoring & Dashboards

### Access the Applications

1. **Get API Gateway URL:**
   ```bash
   kubectl get service api-gateway
   ```

2. **Port-forward for Grafana:**
   ```bash
   kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
   ```
   - Open [http://localhost:3000](http://localhost:3000)
   - Username: `admin`  
   - Password: `change-me-in-production`

3. **Payment Service Dashboard:**
   ```bash
   kubectl port-forward svc/payment-service 8080:80
   ```
   - Open [http://localhost:8080/dashboard](http://localhost:8080/dashboard)
   - Real-time transaction monitoring
   - Live fraud detection alerts
   - Risk management metrics

### Key Metrics Dashboards

- **Cluster Health**: Node status, pod resource usage
- **Application Performance**: Request latency, error rates  
- **Infrastructure**: CPU, memory, disk usage
- **Business Metrics**: Transaction volume, fraud rates, risk exposure
- **Payment Processing**: Success rates, fraud scores, merchant performance

## 🔧 Configuration

### Environment Variables

Modify variables in `terraform/main.tf`:

```hcl
variable "environment" {
  default = "production" # Change to prod, staging, etc.
}

variable "aws_region" {
  default = "us-east-1" # Change to your preferred region
}
```

### Adding New Payment Services

1. **Create application manifests** in `kubernetes/apps/`
2. **Build and push container images** using CI/CD pipeline
3. **Update deployment scripts** in `applications/`

### Scaling Configuration

Modify HPA settings in application manifests:

```yaml
spec:
  minReplicas: 5 # Increase for production
  maxReplicas: 50 # Scale based on requirements
```

## 🧪 Testing

### Running Tests Locally

```bash
# Payment service tests with database
cd applications/payment-service
docker-compose up -d postgres redis
mvn test

# Integration tests
mvn test -Dtest="*IntegrationTest"

# Load testing
./test-payments.sh
```

### CI/CD Pipeline

The platform includes comprehensive automated testing:

- **Unit tests** for all services
- **Integration tests** with PostgreSQL and Redis
- **Security scanning** with Trivy
- **Load testing** with K6
- **End-to-end smoke tests** in production

## 🔄 Backup and Recovery

### Database Backups
- **Automated RDS snapshots** (configured in Terraform)
- **Point-in-time recovery** available

### Configuration Backups
```bash
# Backup Kubernetes configurations
kubectl get all --all-namespaces -o yaml > cluster-backup.yaml
```

### Infrastructure Recovery
```bash
# Infrastructure Recovery
terraform apply # Recreates infrastructure from code

# Application Recovery  
kubectl apply -f kubernetes/ # Restores application state
```

## 🔄 Updates and Maintenance

### Node Updates
- **EKS managed node groups** automatically update
- **Configure maintenance windows** in AWS

### Application Updates
```bash
# Rolling update deployment
kubectl set image deployment/payment-service payment-service=new-image:tag
```

## ⚡ Performance Optimization

### Cost Optimization
- **Right-sizing**: Monitor resource usage and adjust requests/limits
- **Auto-scaling**: Configure HPA based on CPU/memory metrics  
- **Storage**: Use GP3 volumes for better performance
- **Networking**: Implement service mesh for advanced traffic management

### Advanced Features
- **Spot Instances**: Use for non-critical workloads
- **Reserved Instances**: Purchase for predictable workloads
- **Resource Monitoring**: Set up billing alerts
- **Cluster Autoscaler**: Automatically scale nodes based on demand

## 🔐 Security

This platform implements comprehensive security measures:

### Network Security
- **Private subnets** for workloads
- **Security groups** with minimal access
- **VPC flow logs** for monitoring

### Identity and Access
- **IAM roles** for service accounts (IRSA)
- **Pod security contexts** and policies
- **RBAC policies** for fine-grained access control

### Data Protection
- **Encryption at rest** (EBS, RDS)
- **Encryption in transit** (TLS)
- **Secrets management** with Kubernetes secrets
- **PCI-compliant** payment card tokenization

## 🐛 Troubleshooting

### Validation Commands
```bash
# Validate Terraform configuration
terraform validate
terraform plan

# Test Kubernetes connectivity  
kubectl cluster-info
kubectl get nodes

# Run health checks
curl http://<gateway-url>/health

# Payment service health
curl http://<payment-service-url>/api/v1/payments/health
```

### Common Issues

#### EKS Node Issues
```bash
# Check node status
kubectl get nodes
kubectl describe node <node-name>

# Check node logs  
kubectl logs -n kube-system <aws-node-pod>
```

#### Application Issues
```bash
# Check pod status
kubectl get pods
kubectl describe pod <pod-name>
kubectl logs <pod-name>

# Check service connectivity
kubectl get svc
kubectl port-forward svc/<service-name> 8080:80
```

#### Payment Service Issues
```bash
# Check database connectivity
kubectl exec -it deployment/payment-service -- curl localhost:8080/actuator/health

# Check Redis connectivity  
kubectl exec -it deployment/payment-service -- redis-cli -h redis ping

# Monitor transaction processing
kubectl logs -f deployment/payment-service | grep "Payment processed"
```

#### Terraform Issues
```bash
# Enable detailed logging
export TF_LOG=DEBUG
terraform apply

# Import existing resources
terraform import <resource-type>.<n> <resource-id>
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests and documentation  
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Submit a pull request

### Development Guidelines

- **Follow existing code patterns** and conventions
- **Add comprehensive tests** for new features
- **Update documentation** for any API changes
- **Ensure security best practices** are followed
- **Test locally** before submitting PRs

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [Spring Boot](https://spring.io/projects/spring-boot) for enterprise Java applications
- [Go](https://golang.org/) for high-performance microservices
- [Kubernetes](https://kubernetes.io/) for container orchestration
- [Terraform](https://www.terraform.io/) for infrastructure as code
- [AWS](https://aws.amazon.com/) for cloud infrastructure
- [Prometheus](https://prometheus.io/) and [Grafana](https://grafana.com/) for observability

## 🏆 Enterprise Features

This platform demonstrates:

✅ **Production-ready payment processing** with enterprise security  
✅ **Real-time fraud detection** and risk management  
✅ **Horizontal scaling** with Kubernetes HPA  
✅ **Comprehensive observability** with metrics, logs, and tracing  
✅ **Infrastructure as Code** with Terraform  
✅ **CI/CD automation** with GitHub Actions  
✅ **Security best practices** with least privilege access  
✅ **High availability** with multi-AZ deployment  
✅ **Disaster recovery** with automated backups  
✅ **Load testing** and performance optimization  

Perfect for demonstrating enterprise platform engineering skills in financial services, fintech, and payment processing domains.