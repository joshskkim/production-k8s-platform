echo "=== Checking Infrastructure ==="
kubectl get nodes
kubectl get pods --all-namespaces

echo "=== Checking Applications ==="
kubectl get pods
kubectl get services
kubectl get deployments

echo "=== Checking Application Health ==="
kubectl get pods -o wide