#!/bin/bash

# AtlasK8s Platform Destruction Script
set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Configuration
ENVIRONMENT=${ENVIRONMENT:-dev}
AWS_REGION=${AWS_REGION:-us-west-2}
TERRAFORM_DIR="./terraform"

print_warning "🚨 This will destroy your entire AtlasK8s platform!"
print_warning "Environment: $ENVIRONMENT"
print_warning "Region: $AWS_REGION"
echo ""
read -p "Type 'destroy' to confirm: " confirmation

if [ "$confirmation" != "destroy" ]; then
    print_error "Destruction cancelled"
    exit 1
fi

print_status "Starting platform destruction..."

# Step 1: Clean up any remaining Kubernetes resources
print_status "Cleaning up Kubernetes resources..."
kubectl delete deployments --all --timeout=60s 2>/dev/null || true
kubectl delete services --all --timeout=60s 2>/dev/null || true
kubectl delete pods --all --timeout=60s 2>/dev/null || true

# Step 2: Wait for load balancers to be cleaned up
print_status "Waiting for AWS Load Balancers to be deleted..."
max_wait=300  # 5 minutes
wait_time=0

while [ $wait_time -lt $max_wait ]; do
    elb_count=$(aws elbv2 describe-load-balancers --region $AWS_REGION --query 'LoadBalancers[?VpcId!=`null`]' --output text 2>/dev/null | wc -l || echo "0")
    
    if [ "$elb_count" = "0" ]; then
        print_success "All load balancers cleaned up"
        break
    fi
    
    print_status "Waiting for load balancers... ($wait_time/${max_wait}s)"
    sleep 15
    wait_time=$((wait_time + 15))
done

# Step 3: Destroy Terraform infrastructure
print_status "Destroying Terraform infrastructure..."
cd $TERRAFORM_DIR

# Initialize Terraform
terraform init

# Destroy everything
terraform destroy -var="environment=$ENVIRONMENT" -var="aws_region=$AWS_REGION" -auto-approve

cd ..

print_success "✅ Platform destruction completed!"
print_status "Verifying cleanup..."

# Verify cleanup
remaining_vpcs=$(aws ec2 describe-vpcs --region $AWS_REGION --filters "Name=tag:Environment,Values=$ENVIRONMENT" --query 'Vpcs[].VpcId' --output text 2>/dev/null || echo "")

if [ -z "$remaining_vpcs" ]; then
    print_success "✅ All infrastructure successfully destroyed"
else
    print_warning "⚠️  Some resources may still exist. Check AWS console."
fi

print_status "Cleanup complete! 🎉"