#!/bin/bash
# terraform/modules/monitoring/templates/cleanup-monitoring.sh

set -e

NAMESPACE="${namespace}"

echo "🧹 Cleaning up monitoring stack from namespace: $NAMESPACE"

# Uninstall Helm releases
echo "📦 Removing Helm releases..."

helm uninstall promtail -n $NAMESPACE 2>/dev/null || echo "Promtail not found"
helm uninstall loki -n $NAMESPACE 2>/dev/null || echo "Loki not found"
helm uninstall kube-prometheus-stack -n $NAMESPACE 2>/dev/null || echo "kube-prometheus-stack not found"
helm uninstall prometheus-operator-crds -n $NAMESPACE 2>/dev/null || echo "prometheus-operator-crds not found"

# Delete CRDs (optional - be careful as this affects cluster-wide resources)
echo "⚠️  To remove Prometheus Operator CRDs (affects entire cluster), run:"
echo "kubectl delete crd alertmanagerconfigs.monitoring.coreos.com"
echo "kubectl delete crd alertmanagers.monitoring.coreos.com"
echo "kubectl delete crd podmonitors.monitoring.coreos.com"
echo "kubectl delete crd probes.monitoring.coreos.com"
echo "kubectl delete crd prometheuses.monitoring.coreos.com"
echo "kubectl delete crd prometheusrules.monitoring.coreos.com"
echo "kubectl delete crd servicemonitors.monitoring.coreos.com"
echo "kubectl delete crd thanosrulers.monitoring.coreos.com"

# Delete namespace
echo "🗑️  Deleting namespace..."
kubectl delete namespace $NAMESPACE --ignore-not-found=true

echo "✅ Monitoring stack cleanup complete!"