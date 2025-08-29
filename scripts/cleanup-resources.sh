#!/bin/bash
# cleanup-aws-resources.sh - Comprehensive AWS resource cleanup

set -e

REGION="${1:-us-east-1}"
ENV="${2:-development}"
DRY_RUN="${3:-false}"

echo "🧹 Comprehensive AWS cleanup for $ENV environment in $REGION"
echo "Dry run: $DRY_RUN"

if [ "$DRY_RUN" = "true" ]; then
    EXECUTE=""
    echo "🔍 DRY RUN MODE - No resources will be deleted"
else
    EXECUTE="true"
    echo "⚠️  DESTRUCTIVE MODE - Resources will be deleted!"
    sleep 5
fi

# Function to safely execute commands
safe_execute() {
    local cmd="$1"
    local description="$2"
    
    echo "📋 $description"
    if [ "$DRY_RUN" = "true" ]; then
        echo "Would run: $cmd"
    else
        eval "$cmd" || echo "❌ Failed: $description"
    fi
}

# 1. Clean up Kubernetes resources first
echo "🚀 Step 1: Kubernetes cleanup"
CLUSTER_NAME="$ENV-payment-platform-cluster"

if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" &>/dev/null; then
    echo "Found cluster: $CLUSTER_NAME"
    aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME" || true
    
    # Remove monitoring stack
    safe_execute "helm uninstall promtail -n monitoring --ignore-not-found" "Remove Promtail"
    safe_execute "helm uninstall loki -n monitoring --ignore-not-found" "Remove Loki" 
    safe_execute "helm uninstall kube-prometheus-stack -n monitoring --ignore-not-found" "Remove Prometheus stack"
    safe_execute "kubectl delete namespace monitoring --ignore-not-found=true" "Delete monitoring namespace"
    
    # Clean up any other namespaces
    safe_execute "kubectl delete namespace default --ignore-not-found=true" "Clean default namespace"
    
    echo "⏳ Waiting for k8s resources to terminate..."
    [ "$DRY_RUN" = "false" ] && sleep 60
fi

# 2. EKS Node Groups first
echo "🚀 Step 2a: EKS node groups"
CLUSTERS=$(aws eks list-clusters --region "$REGION" --output text --query "clusters[?contains(@, '$ENV')]" 2>/dev/null || echo "")
for cluster in $CLUSTERS; do
    NODE_GROUPS=$(aws eks list-nodegroups --cluster-name "$cluster" --region "$REGION" --output text --query "nodegroups[]" 2>/dev/null || echo "")
    for ng in $NODE_GROUPS; do
        safe_execute "aws eks delete-nodegroup --cluster-name '$cluster' --nodegroup-name '$ng' --region '$REGION'" "Delete nodegroup: $ng"
    done
done

# Wait for node groups to delete
[ "$DRY_RUN" = "false" ] && echo "⏳ Waiting for node groups to delete..." && sleep 120

# 2b. EKS Clusters
echo "🚀 Step 2b: EKS clusters"
for cluster in $CLUSTERS; do
    safe_execute "aws eks delete-cluster --name '$cluster' --region '$REGION'" "Delete EKS cluster: $cluster"
done

# 3. Load Balancers
echo "🚀 Step 3: Load balancers"  
ALB_ARNS=$(aws elbv2 describe-load-balancers --region "$REGION" --query "LoadBalancers[?contains(LoadBalancerName, '$ENV-payment-platform')].LoadBalancerArn" --output text 2>/dev/null || echo "")
for alb_arn in $ALB_ARNS; do
    safe_execute "aws elbv2 delete-load-balancer --load-balancer-arn '$alb_arn' --region '$REGION'" "Delete ALB: $alb_arn"
done

# 4. Target Groups
echo "🚀 Step 4: Target groups"
TG_ARNS=$(aws elbv2 describe-target-groups --region "$REGION" --query "TargetGroups[?contains(TargetGroupName, '$ENV-payment-platform')].TargetGroupArn" --output text 2>/dev/null || echo "")
for tg_arn in $TG_ARNS; do
    safe_execute "aws elbv2 delete-target-group --target-group-arn '$tg_arn' --region '$REGION'" "Delete target group: $tg_arn"
done

# 5. RDS instances - disable protection first
echo "🚀 Step 5: RDS instances"
RDS_INSTANCES=$(aws rds describe-db-instances --region "$REGION" --query "DBInstances[?contains(DBInstanceIdentifier, '$ENV-payment-platform')].DBInstanceIdentifier" --output text 2>/dev/null || echo "")
for rds in $RDS_INSTANCES; do
    safe_execute "aws rds modify-db-instance --db-instance-identifier '$rds' --no-deletion-protection --apply-immediately --region '$REGION'" "Disable deletion protection: $rds"
    sleep 10
    safe_execute "aws rds delete-db-instance --db-instance-identifier '$rds' --skip-final-snapshot --region '$REGION'" "Delete RDS: $rds"
done

# 6. ElastiCache replication groups first, then clusters
echo "🚀 Step 6: ElastiCache"
REPL_GROUPS=$(aws elasticache describe-replication-groups --region "$REGION" --query "ReplicationGroups[?contains(ReplicationGroupId, '$ENV-payment-platform')].ReplicationGroupId" --output text 2>/dev/null || echo "")
for rg in $REPL_GROUPS; do
    safe_execute "aws elasticache delete-replication-group --replication-group-id '$rg' --region '$REGION'" "Delete replication group: $rg"
done

# 7. Auto Scaling Groups
echo "🚀 Step 7: Auto Scaling Groups"
ASG_NAMES=$(aws autoscaling describe-auto-scaling-groups --region "$REGION" --query "AutoScalingGroups[?contains(AutoScalingGroupName, '$ENV-payment-platform')].AutoScalingGroupName" --output text 2>/dev/null || echo "")
for asg in $ASG_NAMES; do
    safe_execute "aws autoscaling delete-auto-scaling-group --auto-scaling-group-name '$asg' --force-delete --region '$REGION'" "Delete ASG: $asg"
done

# 8. Launch Templates
echo "🚀 Step 8: Launch Templates"
LT_IDS=$(aws ec2 describe-launch-templates --region "$REGION" --query "LaunchTemplates[?contains(LaunchTemplateName, '$ENV-payment-platform')].LaunchTemplateId" --output text 2>/dev/null || echo "")
for lt in $LT_IDS; do
    safe_execute "aws ec2 delete-launch-template --launch-template-id '$lt' --region '$REGION'" "Delete launch template: $lt"
done

# 9. NAT Gateways
echo "🚀 Step 9: NAT Gateways"
NAT_IDS=$(aws ec2 describe-nat-gateways --region "$REGION" --filter "Name=tag:Name,Values=*$ENV-payment-platform*" --query "NatGateways[?State=='available'].NatGatewayId" --output text 2>/dev/null || echo "")
for nat in $NAT_IDS; do
    safe_execute "aws ec2 delete-nat-gateway --nat-gateway-id '$nat' --region '$REGION'" "Delete NAT gateway: $nat"
done

# 10. Internet Gateways
echo "🚀 Step 10: Internet Gateways"
VPC_IDS=$(aws ec2 describe-vpcs --region "$REGION" --filters "Name=tag:Name,Values=*$ENV-payment-platform*" --query "Vpcs[].VpcId" --output text 2>/dev/null || echo "")
for vpc_id in $VPC_IDS; do
    IGW_IDS=$(aws ec2 describe-internet-gateways --region "$REGION" --filters "Name=attachment.vpc-id,Values=$vpc_id" --query "InternetGateways[].InternetGatewayId" --output text 2>/dev/null || echo "")
    for igw in $IGW_IDS; do
        safe_execute "aws ec2 detach-internet-gateway --internet-gateway-id '$igw' --vpc-id '$vpc_id' --region '$REGION'" "Detach IGW: $igw"
        safe_execute "aws ec2 delete-internet-gateway --internet-gateway-id '$igw' --region '$REGION'" "Delete IGW: $igw"
    done
done

# 11. Network interfaces first  
echo "🚀 Step 11a: Network interfaces"
for vpc_id in $VPC_IDS; do
    ENI_IDS=$(aws ec2 describe-network-interfaces --region "$REGION" --filters "Name=vpc-id,Values=$vpc_id" "Name=status,Values=available" --query "NetworkInterfaces[].NetworkInterfaceId" --output text 2>/dev/null || echo "")
    for eni in $ENI_IDS; do
        safe_execute "aws ec2 delete-network-interface --network-interface-id '$eni' --region '$REGION'" "Delete ENI: $eni"
    done
done

# Wait for ENIs to cleanup
[ "$DRY_RUN" = "false" ] && sleep 60

# 11b. Security Groups (after everything else)
echo "🚀 Step 11b: Security Groups"
for vpc_id in $VPC_IDS; do
    # Try multiple times as dependencies clear
    for attempt in {1..3}; do
        SG_IDS=$(aws ec2 describe-security-groups --region "$REGION" --filters "Name=vpc-id,Values=$vpc_id" "Name=group-name,Values=*$ENV-payment-platform*" --query "SecurityGroups[?GroupName != 'default'].GroupId" --output text 2>/dev/null || echo "")
        for sg in $SG_IDS; do
            safe_execute "aws ec2 delete-security-group --group-id '$sg' --region '$REGION'" "Delete security group: $sg (attempt $attempt)"
        done
        [ "$DRY_RUN" = "false" ] && sleep 30
    done
done

# 12. Subnets
echo "🚀 Step 12: Subnets"
for vpc_id in $VPC_IDS; do
    SUBNET_IDS=$(aws ec2 describe-subnets --region "$REGION" --filters "Name=vpc-id,Values=$vpc_id" --query "Subnets[].SubnetId" --output text 2>/dev/null || echo "")
    for subnet in $SUBNET_IDS; do
        safe_execute "aws ec2 delete-subnet --subnet-id '$subnet' --region '$REGION'" "Delete subnet: $subnet"
    done
done

# 13. VPCs (last)
echo "🚀 Step 13: VPCs"
for vpc_id in $VPC_IDS; do
    safe_execute "aws ec2 delete-vpc --vpc-id '$vpc_id' --region '$REGION'" "Delete VPC: $vpc_id"
done

# 14. Elastic IPs
echo "🚀 Step 14: Elastic IPs"
EIP_IDS=$(aws ec2 describe-addresses --region "$REGION" --query "Addresses[?contains(to_string(Tags), '$ENV-payment-platform')].AllocationId" --output text 2>/dev/null || echo "")
for eip in $EIP_IDS; do
    safe_execute "aws ec2 release-address --allocation-id '$eip' --region '$REGION'" "Release EIP: $eip"
done

echo "✅ Cleanup completed for $ENV environment"
echo "🔍 Run with DRY_RUN=true first to preview changes"