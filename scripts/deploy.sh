#!/bin/bash

# Production-Ready Kubernetes Platform Deployment Script
# This script orchestrates the complete deployment of infrastructure and applications

set -euo pipefail

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
ENVIRONMENT=${ENVIRONMENT:-dev}
AWS_REGION=${AWS_REGION:-us-west-2}
TERRAFORM_DIR="./terraform"
KUBERNETES_DIR="./kubernetes"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if required tools are installed
    for tool in terraform kubectl helm aws; do
        if ! command -v $tool &> /dev/null; then
            print_error "$tool is not installed or not in PATH"
            exit 1
        fi
    done
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured properly"
        exit 1
    fi
    
    print_success "All prerequisites are met"
}

# Function to deploy infrastructure with Terraform
deploy_infrastructure() {
    print_status "Deploying infrastructure with Terraform..."
    
    cd $TERRAFORM_DIR
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Plan the deployment
    print_status "Planning Terraform deployment..."
    terraform plan -var="environment=$ENVIRONMENT" -var="aws_region=$AWS_REGION" -out=tfplan
    
    # Apply the plan
    print_status "Applying Terraform configuration..."
    terraform apply tfplan
    
    # Store outputs for later use
    terraform output -json > ../terraform-outputs.json
    
    cd ..
    print_success "Infrastructure deployment completed"
}

# Function to configure kubectl
configure_kubectl() {
    print_status "Configuring kubectl..."
    
    # Get cluster name from Terraform outputs
    CLUSTER_NAME=$(jq -r '.cluster_name.value' terraform-outputs.json)
    
    # Update kubeconfig
    aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
    
    # Verify connection
    if kubectl get nodes &> /dev/null; then
        print_success "kubectl configured successfully"
    else
        print_error "Failed to connect to Kubernetes cluster"
        exit 1
    fi
}

# Function to deploy monitoring stack
deploy_monitoring() {
    print_status "Deploying monitoring stack..."
    
    # Add Prometheus Helm repository
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    
    # Install kube-prometheus-stack
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --values $KUBERNETES_DIR/monitoring/prometheus/values.yaml \
        --wait \
        --timeout 10m
    
    print_success "Monitoring stack deployed"
}

# Function to deploy applications
deploy_applications() {
    print_status "Deploying applications..."
    
    # Apply Kubernetes manifests
    kubectl apply -f $KUBERNETES_DIR/apps/
    
    # Wait for deployments to be ready
    print_status "Waiting for deployments to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/api-gateway
    
    print_success "Applications deployed successfully"
}

# Function to run health checks
run_health_checks() {
    print_status "Running health checks..."
    
    # Check if all pods are running
    if kubectl get pods --all-namespaces | grep -E "(Error|CrashLoopBackOff|ImagePullBackOff)"; then
        print_warning "Some pods are not in running state"
    fi
    
    # Check if services are accessible
    GATEWAY_URL=$(kubectl get service api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    if [[ -n "$GATEWAY_URL" ]]; then
        print_status "API Gateway URL: http://$GATEWAY_URL"
        
        # Wait for load balancer to be ready
        sleep 60
        
        # Test health endpoint
        if curl -f "http://$GATEWAY_URL/health" &> /dev/null; then
            print_success "API Gateway health check passed"
        else
            print_warning "API Gateway health check failed (may take a few minutes to be ready)"
        fi
    fi
    
    print_success "Health checks completed"
}

# Function to display deployment summary
show_deployment_summary() {
    print_status "Deployment Summary"
    echo "===================="
    echo "Environment: $ENVIRONMENT"
    echo "AWS Region: $AWS_REGION"
    echo "Cluster Name: $(jq -r '.cluster_name.value' terraform-outputs.json)"
    echo "VPC ID: $(jq -r '.vpc_id.value' terraform-outputs.json)"
    echo ""
    print_status "Access Information:"
    echo "- Kubectl: kubectl get pods --all-namespaces"
    echo "- Grafana: kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
    echo "- Prometheus: kubectl port-forward -n monitoring svc/prometheus-server 9090:80"
    echo ""
    print_success "Deployment completed successfully!"
}

# Main deployment function
main() {
    print_status "Starting deployment of Production-Ready Kubernetes Platform"
    print_status "Environment: $ENVIRONMENT"
    print_status "AWS Region: $AWS_REGION"
    
    check_prerequisites
    deploy_infrastructure
    configure_kubectl
    deploy_monitoring
    deploy_applications
    run_health_checks
    show_deployment_summary
}

# Handle script interruption
trap 'print_error "Deployment interrupted"; exit 1' INT TERM

# Run main function
main "$@"