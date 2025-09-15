#!/bin/bash
set -e

echo "🗑️  Removing LocalStack from K3s cluster..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

echo "🔄 Deleting LocalStack resources..."

# Delete in reverse order
kubectl delete job localstack-init -n localstack --ignore-not-found=true
kubectl delete -f service.yaml --ignore-not-found=true
kubectl delete -f deployment.yaml --ignore-not-found=true
kubectl delete -f configmap.yaml --ignore-not-found=true
kubectl delete -f pvc.yaml --ignore-not-found=true

# Wait for cleanup
echo "⏳ Waiting for resources to be cleaned up..."
sleep 10

# Delete namespace (this will force delete any remaining resources)
kubectl delete -f namespace.yaml --ignore-not-found=true

echo "✅ LocalStack successfully removed from K3s cluster!"
echo "💡 Note: Persistent data has been deleted. Run deploy.sh to reinstall."