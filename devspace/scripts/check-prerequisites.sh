#!/bin/bash
set -e

echo "🔍 Checking DevSpace Prerequisites..."

# Check if kubectl works
if ! kubectl get nodes &> /dev/null; then
    echo "❌ kubectl not working. Please check your kubeconfig."
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    echo "❌ Helm not found. Please install Helm."
    exit 1
fi

# Check if MetalLB is ready
if ! kubectl get pods -n metallb-system &> /dev/null; then
    echo "⚠️  MetalLB not found. It will be installed with LocalStack."
fi

# Check if LocalStack chart exists
if [ ! -f "../helm-chart/localstack/Chart.yaml" ]; then
    echo "❌ LocalStack Helm chart not found."
    exit 1
fi

# Check available resources
echo "📊 Cluster Resource Status:"
kubectl top nodes --no-headers 2>/dev/null || echo "  Metrics not available"

# Check if namespaces exist
if kubectl get namespace bytefreezer-dev &> /dev/null; then
    echo "✅ Development namespace exists"
else
    echo "📦 Will create development namespace"
fi

echo "✅ Prerequisites check completed!"