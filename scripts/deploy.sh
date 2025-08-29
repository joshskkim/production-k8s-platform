#!/bin/bash

# Enhanced deployment script for production Kubernetes payment platform
# Author: Production K8s Platform
# Version: 2.0

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENVIRONMENT=${ENVIRONMENT:-production}
AWS_REGION=${AWS_REGION:-us-east-1}
CLUSTER_NAME="${ENVIRONMENT}-payment-platform-cluster"
TERRAFORM_DIR="./terraform"
K8S_DIR="./kubernetes"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Utility functions
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check required tools
    local tools=("terraform" "kubectl" "aws" "helm" "docker")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "$tool is required but not installed"
            exit 1
        fi
        log_success "$tool is installed"
    done
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured"
        exit 1
    fi
    log_success "AWS credentials configured"
    
    # Check Docker daemon
    if ! docker info &> /dev/null; then
        log_error "Docker daemon not running"
        exit 1
    fi
    log_success "Docker daemon running"
}

validate_environment() {
    log_info "Validating environment configuration..."
    
    # Check if S3 bucket exists for Terraform state
    local bucket_name=$(grep -A 10 'backend "s3"' "$TERRAFORM_DIR/main.tf" | grep 'bucket' | cut -d'"' -f4)
    if [ -n "$bucket_name" ]; then
        if ! aws s3 ls "s3://$bucket_name" &> /dev/null; then
            log_warning "S3 bucket $bucket_name doesn't exist. Creating..."
            aws s3 mb "s3://$bucket_name" --region "$AWS_REGION"
            
            # Enable versioning
            aws s3api put-bucket-versioning \
                --bucket "$bucket_name" \
                --versioning-configuration Status=Enabled
            
            # Enable encryption
            aws s3api put-bucket-encryption \
                --bucket "$bucket_name" \
                --server-side-encryption-configuration \
                '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
            
            log_success "S3 bucket created and configured"
        else
            log_success "S3 bucket exists"
        fi
    fi
    
    # Create DynamoDB table for Terraform locking
    local table_name="terraform-locks"
    if ! aws dynamodb describe-table --table-name "$table_name" --region "$AWS_REGION" &> /dev/null; then
        log_warning "DynamoDB table $table_name doesn't exist. Creating..."
        aws dynamodb create-table \
            --table-name "$table_name" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
            --region "$AWS_REGION" &> /dev/null
        
        log_info "Waiting for DynamoDB table to be active..."
        aws dynamodb wait table-exists --table-name "$table_name" --region "$AWS_REGION"
        log_success "DynamoDB table created"
    else
        log_success "DynamoDB table exists"
    fi
}

deploy_infrastructure() {
    log_info "Deploying infrastructure with Terraform..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    log_info "Initializing Terraform..."
    terraform init -upgrade
    
    # Validate configuration
    log_info "Validating Terraform configuration..."
    terraform validate
    
    # Plan deployment
    log_info "Planning infrastructure deployment..."
    terraform plan -var="environment=$ENVIRONMENT" -var="aws_region=$AWS_REGION" -out=tfplan
    
    # Apply changes
    log_info "Applying infrastructure changes..."
    terraform apply tfplan
    
    # Get outputs
    log_info "Getting infrastructure outputs..."
    CLUSTER_ENDPOINT=$(terraform output -raw cluster_endpoint)
    VPC_ID=$(terraform output -raw vpc_id)
    RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
    REDIS_ENDPOINT=$(terraform output -raw redis_endpoint)
    ALB_DNS_NAME=$(terraform output -raw alb_dns_name)
    
    log_success "Infrastructure deployed successfully"
    cd - > /dev/null
}

configure_kubectl() {
    log_info "Configuring kubectl for EKS cluster..."
    
    # Update kubeconfig
    aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
    
    # Verify connection
    if kubectl cluster-info &> /dev/null; then
        log_success "kubectl configured successfully"
    else
        log_error "Failed to configure kubectl"
        exit 1
    fi
    
    # Show cluster information
    log_info "Cluster information:"
    kubectl get nodes -o wide
}

install_cluster_addons() {
    log_info "Installing cluster add-ons..."
    
    # Install AWS Load Balancer Controller
    log_info "Installing AWS Load Balancer Controller..."
    helm repo add eks https://aws.github.io/eks-charts
    helm repo update
    
    helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName="$CLUSTER_NAME" \
        --set serviceAccount.create=false \
        --set serviceAccount.name=aws-load-balancer-controller \
        --wait
    
    # Install Cluster Autoscaler
    log_info "Installing Cluster Autoscaler..."
    helm upgrade --install cluster-autoscaler eks/cluster-autoscaler \
        -n kube-system \
        --set autoDiscovery.clusterName="$CLUSTER_NAME" \
        --set awsRegion="$AWS_REGION" \
        --set serviceAccount.create=false \
        --set serviceAccount.name=cluster-autoscaler \
        --wait
    
    # Install Metrics Server
    log_info "Installing Metrics Server..."
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    
    log_success "Cluster add-ons installed"
}

install_monitoring_stack() {
    log_info "Installing monitoring stack..."
    
    # Create monitoring namespace
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    
    # Install Prometheus Stack
    log_info "Installing Prometheus Stack..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
        -n monitoring \
        -f "$K8S_DIR/monitoring/prometheus-values.yaml" \
        --wait
    
    # Install Loki Stack for logging
    log_info "Installing Loki Stack..."
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
    
    helm upgrade --install loki grafana/loki-stack \
        -n monitoring \
        --set grafana.enabled=false \
        --set prometheus.enabled=false \
        --set fluent-bit.enabled=true \
        --wait
    
    log_success "Monitoring stack installed"
}

deploy_applications() {
    log_info "Deploying payment platform applications..."
    
    # Create namespace
    kubectl apply -f "$K8S_DIR/apps/api-gateway/namespace.yaml"
    
    # Create secrets from Terraform outputs
    log_info "Creating application secrets..."
    
    # Get database credentials from AWS Secrets Manager
    DB_SECRET=$(aws secretsmanager get-secret-value \
        --secret-id "$ENVIRONMENT/rds/password" \
        --query SecretString --output text)
    
    # Create database secret
    kubectl create secret generic database-credentials \
        --from-literal=host="$RDS_ENDPOINT" \
        --from-literal=username=$(echo "$DB_SECRET" | jq -r '.username') \
        --from-literal=password=$(echo "$DB_SECRET" | jq -r '.password') \
        --from-literal=database=$(echo "$DB_SECRET" | jq -r '.dbname') \
        -n payment-platform \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Get Redis credentials
    REDIS_SECRET=$(aws secretsmanager get-secret-value \
        --secret-id "$ENVIRONMENT/redis/auth" \
        --query SecretString --output text)
    
    # Create Redis secret
    kubectl create secret generic redis-auth \
        --from-literal=auth_token=$(echo "$REDIS_SECRET" | jq -r '.auth_token') \
        --from-literal=endpoint=$(echo "$REDIS_SECRET" | jq -r '.endpoint') \
        -n payment-platform \
        --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy API Gateway
    log_info "Deploying API Gateway..."
    kubectl apply -f "$K8S_DIR/apps/api-gateway/"
    
    # Wait for API Gateway deployment
    kubectl rollout status deployment/api-gateway -n payment-platform --timeout=600s
    
    # Deploy Payment Service (assuming it exists)
    if [ -d "$K8S_DIR/apps/payment-service" ]; then
        log_info "Deploying Payment Service..."
        kubectl apply -f "$K8S_DIR/apps/payment-service/"
        kubectl rollout status deployment/payment-service -n payment-platform --timeout=600s
    fi
    
    log_success "Applications deployed successfully"
}

run_health_checks() {
    log_info "Running health checks..."
    
    # Check pod status
    log_info "Checking pod status..."
    kubectl get pods -n payment-platform -o wide
    
    # Check API Gateway health
    log_info "Checking API Gateway health..."
    local api_gateway_pod=$(kubectl get pods -n payment-platform -l app=api-gateway -o jsonpath='{.items[0].metadata.name}')
    
    if [ -n "$api_gateway_pod" ]; then
        kubectl port-forward -n payment-platform "$api_gateway_pod" 8080:8080 &
        local port_forward_pid=$!
        sleep 5
        
        if curl -f http://localhost:8080/health > /dev/null 2>&1; then
            log_success "API Gateway health check passed"
        else
            log_warning "API Gateway health check failed"
        fi
        
        kill $port_forward_pid 2>/dev/null || true
    fi
    
    # Check service endpoints
    log_info "Service endpoints:"
    kubectl get svc -n payment-platform
    
    # Show ingress information
    if kubectl get ingress -n payment-platform > /dev/null 2>&1; then
        log_info "Ingress information:"
        kubectl get ingress -n payment-platform
    fi
    
    # Show monitoring endpoints
    log_info "Monitoring endpoints:"
    echo "Grafana: kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
    echo "Prometheus: kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
    echo "AlertManager: kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093"
    
    log_success "Health checks completed"
}

cleanup() {
    log_info "Cleaning up temporary files..."
    rm -f "$TERRAFORM_DIR/tfplan" 2>/dev/null || true
}

show_deployment_info() {
    log_success "Deployment completed successfully!"
    echo
    echo "=== DEPLOYMENT INFORMATION ==="
    echo "Environment: $ENVIRONMENT"
    echo "AWS Region: $AWS_REGION"
    echo "Cluster Name: $CLUSTER_NAME"
    echo "Load Balancer: $ALB_DNS_NAME"
    echo
    echo "=== ACCESS INFORMATION ==="
    echo "kubectl context: $(kubectl config current-context)"
    echo
    echo "=== MONITORING DASHBOARDS ==="
    echo "Grafana: kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
    echo "  Username: admin"
    echo "  Password: kubectl get secret -n monitoring kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' | base64 --decode"
    echo
    echo "=== USEFUL COMMANDS ==="
    echo "View pods: kubectl get pods -n payment-platform"
    echo "View logs: kubectl logs -f deployment/api-gateway -n payment-platform"
    echo "Scale deployment: kubectl scale deployment/api-gateway --replicas=5 -n payment-platform"
    echo
}

# Main deployment function
main() {
    log_info "Starting deployment of Payment Platform on Kubernetes"
    log_info "Environment: $ENVIRONMENT"
    log_info "AWS Region: $AWS_REGION"
    
    # Set trap for cleanup
    trap cleanup EXIT
    
    # Run deployment steps
    check_prerequisites
    validate_environment
    deploy_infrastructure
    configure_kubectl
    install_cluster_addons
    install_monitoring_stack
    deploy_applications
    run_health_checks
    show_deployment_info
    
    log_success "Deployment completed successfully! 🎉"
}

# Handle script arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "destroy")
        log_warning "Destroying infrastructure..."
        read -p "Are you sure you want to destroy the infrastructure? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            cd "$TERRAFORM_DIR"
            terraform destroy -var="environment=$ENVIRONMENT" -var="aws_region=$AWS_REGION"
            log_success "Infrastructure destroyed"
        else
            log_info "Destruction cancelled"
        fi
        ;;
    "status")
        log_info "Checking deployment status..."
        kubectl get all -n payment-platform
        kubectl get all -n monitoring
        ;;
    "logs")
        log_info "Showing API Gateway logs..."
        kubectl logs -f deployment/api-gateway -n payment-platform
        ;;
    "help")
        echo "Usage: $0 [deploy|destroy|status|logs|help]"
        echo
        echo "Commands:"
        echo "  deploy   - Deploy the complete platform (default)"
        echo "  destroy  - Destroy the infrastructure"
        echo "  status   - Show deployment status"
        echo "  logs     - Show API Gateway logs"
        echo "  help     - Show this help message"
        ;;
    *)
        log_error "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac