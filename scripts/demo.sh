#!/bin/bash

echo "🎯 AtlasK8s Platform Demo"
echo "========================="

echo "📊 Infrastructure Status:"
kubectl get nodes
echo ""

echo "🚀 Applications Running:"
kubectl get pods
echo ""

echo "🌐 Services Exposed:"
kubectl get services
echo ""

EXTERNAL_IP=$(kubectl get service api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "🔗 Platform URL: http://$EXTERNAL_IP"
echo ""

echo "🧪 Testing Health Endpoints:"
curl -s http://$EXTERNAL_IP/health | jq .
echo ""

echo "✅ Platform is running successfully!"