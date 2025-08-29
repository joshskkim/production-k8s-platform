#!/bin/bash
# EKS Node User Data Script

# Bootstrap the node with EKS cluster
/etc/eks/bootstrap.sh ${cluster_name} ${bootstrap_arguments} \
  --container-runtime ${container_runtime} \
  --apiserver-endpoint ${cluster_endpoint} \
  --b64-cluster-ca ${cluster_ca}

# Install additional packages if needed
yum update -y
yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Set up logging
echo "EKS node bootstrap completed for cluster: ${cluster_name}" >> /var/log/eks-bootstrap.log