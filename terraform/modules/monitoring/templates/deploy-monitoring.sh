#!/bin/bash
# terraform/modules/monitoring/templates/deploy-monitoring.sh

set -e

CLUSTER_NAME="${cluster_name}"
AWS_REGION="${aws_region}"
NAMESPACE="${namespace}"

echo "🚀 Deploying monitoring stack to EKS cluster: $CLUSTER_NAME"

# Update kubeconfig
echo "📝 Updating kubeconfig..."
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Wait for cluster to be ready
echo "⏳ Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Create monitoring namespace
echo "📦 Creating monitoring namespace..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Add Helm repositories
echo "📚 Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus Operator CRDs
echo "🔧 Installing Prometheus Operator CRDs..."
helm upgrade --install prometheus-operator-crds prometheus-community/prometheus-operator-crds \
    --namespace $NAMESPACE \
    --create-namespace

# Wait for CRDs to be ready
echo "⏳ Waiting for CRDs to be established..."
sleep 30

# Install kube-prometheus-stack
echo "📊 Installing kube-prometheus-stack..."
if [ -f "prometheus-values.yaml" ]; then
    helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
        --namespace $NAMESPACE \
        --values prometheus-values.yaml \
        --timeout 10m \
        --wait
else
    echo "⚠️  Warning: prometheus-values.yaml not found, using default values"
    helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
        --namespace $NAMESPACE \
        --timeout 10m \
        --wait
fi

# Install Loki if enabled
if [ -f "loki-values.yaml" ]; then
    echo "📄 Installing Loki..."
    helm upgrade --install loki grafana/loki \
        --namespace $NAMESPACE \
        --values loki-values.yaml \
        --timeout 5m \
        --wait
        
    echo "📤 Installing Promtail..."
    if [ -f "promtail-values.yaml" ]; then
        helm upgrade --install promtail grafana/promtail \
            --namespace $NAMESPACE \
            --values promtail-values.yaml \
            --timeout 5m \
            --wait
    else
        helm upgrade --install promtail grafana/promtail \
            --namespace $NAMESPACE \
            --set config.lokiAddress=http://loki:3100/loki/api/v1/push \
            --timeout 5m \
            --wait
    fi
fi

# Wait for all pods to be ready
echo "⏳ Waiting for all pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n $NAMESPACE --timeout=600s

# Display status
echo "✅ Monitoring stack deployment complete!"
echo ""
echo "📊 Prometheus: kubectl port-forward -n $NAMESPACE svc/kube-prometheus-stack-prometheus 9090:9090"
echo "📈 Grafana: kubectl port-forward -n $NAMESPACE svc/kube-prometheus-stack-grafana 3000:80"
echo "🔔 AlertManager: kubectl port-forward -n $NAMESPACE svc/kube-prometheus-stack-alertmanager 9093:9093"

if [ -f "loki-values.yaml" ]; then
    echo "📄 Loki: kubectl port-forward -n $NAMESPACE svc/loki 3100:3100"
fi

echo ""
echo "🔑 Default Grafana credentials:"
echo "   Username: admin"
echo "   Password: Run 'kubectl get secret -n $NAMESPACE kube-prometheus-stack-grafana -o jsonpath=\"{.data.admin-password}\" | base64 --decode'"
echo ""
echo "🌐 To access Grafana externally, run:"
echo "   kubectl port-forward -n $NAMESPACE svc/kube-prometheus-stack-grafana 3000:80"
echo "   Then visit: http://localhost:3000"