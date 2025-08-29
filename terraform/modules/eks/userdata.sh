MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

#!/bin/bash
# EKS Node User Data Script

# Bootstrap the node with EKS cluster
/etc/eks/bootstrap.sh ${cluster_name}

# Install additional packages if needed
yum update -y
yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Set up logging
echo "EKS node bootstrap completed for cluster: ${cluster_name}" >> /var/log/eks-bootstrap.log

--==MYBOUNDARY==--