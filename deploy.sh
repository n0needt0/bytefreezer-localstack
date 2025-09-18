#!/bin/bash
set -e

echo "🚀 Deploying LocalStack to K3s cluster with MetalLB..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if K3s cluster is accessible
if ! kubectl get nodes &> /dev/null; then
    echo "❌ Cannot access K3s cluster. Please check your kubeconfig."
    exit 1
fi

echo "✅ K3s cluster is accessible"

# Check if MetalLB is installed
if ! kubectl get namespace metallb-system &> /dev/null; then
    echo "⚠️  MetalLB not detected. Installing MetalLB..."
    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
    echo "⏳ Waiting for MetalLB to be ready..."
    kubectl wait --for=condition=ready pod -l app=metallb -n metallb-system --timeout=300s
    echo "✅ MetalLB installed"
else
    echo "✅ MetalLB is already installed"
fi

# Apply MetalLB configuration
echo "🌐 Configuring MetalLB IP pools..."

if [ ! -f "metallb-config.yaml" ]; then
    echo "📝 MetalLB configuration not found. Running network detection..."
    ./configure-network.sh
    echo ""
    read -p "Use the suggested configuration? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Please manually create metallb-config.yaml and re-run this script."
        exit 1
    else
        cp metallb-config-suggested.yaml metallb-config.yaml
        echo "✅ Using suggested MetalLB configuration"
    fi
else
    echo "📋 Using existing MetalLB configuration:"
    cat metallb-config.yaml
    echo ""
    read -p "Apply this configuration? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "⏸️  Skipping MetalLB configuration. You can apply it manually later."
    fi
fi

if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    kubectl apply -f metallb-config.yaml
    echo "✅ MetalLB configuration applied"
    echo "⏳ Waiting for MetalLB configuration to be ready..."
    sleep 5
fi

# Apply manifests in order
echo "📦 Creating namespace..."
kubectl apply -f namespace.yaml

echo "💾 Creating persistent volume claim..."
kubectl apply -f pvc.yaml

echo "⚙️  Creating configuration..."
kubectl apply -f configmap.yaml

echo "🚀 Deploying LocalStack..."
kubectl apply -f deployment.yaml

echo "🌐 Creating services with MetalLB..."
kubectl apply -f service.yaml

echo "⏳ Waiting for LocalStack to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/localstack -n localstack

echo "⏳ Waiting for LoadBalancer services to get external IPs..."
sleep 10

# Get LoadBalancer IPs
EXTERNAL_IP=$(kubectl get svc localstack-external -n localstack -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
DEV_IP=$(kubectl get svc localstack-dev -n localstack -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")

echo "🎉 LocalStack deployed successfully with MetalLB!"
echo ""
echo "📋 Access Information:"
echo "  • Internal URL: http://localstack-internal.localstack.svc.cluster.local:4566"
echo "  • External LoadBalancer: http://${EXTERNAL_IP}:4566 (Admin: :4510)"
echo "  • Development LoadBalancer: http://${DEV_IP}:4567 (Admin: :4511)"
echo ""
if [ "$EXTERNAL_IP" = "pending" ] || [ "$DEV_IP" = "pending" ]; then
    echo "⏳ LoadBalancer IPs are still pending. Check with:"
    echo "     kubectl get svc -n localstack -w"
    echo ""
fi
echo "🔧 Environment Variables for cluster services:"
echo "  AWS_ENDPOINT_URL=http://localstack-internal.localstack.svc.cluster.local:4566"
echo "  AWS_ACCESS_KEY_ID=test"
echo "  AWS_SECRET_ACCESS_KEY=test"
echo "  AWS_DEFAULT_REGION=us-east-1"
echo ""
echo "🔧 Environment Variables for external access:"
echo "  AWS_ENDPOINT_URL=http://${EXTERNAL_IP}:4566"
echo "  AWS_ACCESS_KEY_ID=test"
echo "  AWS_SECRET_ACCESS_KEY=test"
echo "  AWS_DEFAULT_REGION=us-east-1"
echo ""

# Update ConfigMap to use internal service for initialization
kubectl patch configmap localstack-config -n localstack --patch='
data:
  init-aws.sh: |
    #!/bin/bash
    set -e
    
    echo "Waiting for LocalStack to be ready..."
    while ! curl -s http://localstack-internal.localstack.svc.cluster.local:4566/_localstack/health > /dev/null; do
      sleep 2
    done
    echo "LocalStack is ready!"
    
    # Create example S3 buckets
    aws --endpoint-url=http://localstack-internal.localstack.svc.cluster.local:4566 s3 mb s3://app-data || true
    aws --endpoint-url=http://localstack-internal.localstack.svc.cluster.local:4566 s3 mb s3://app-config || true
    aws --endpoint-url=http://localstack-internal.localstack.svc.cluster.local:4566 s3 mb s3://app-logs || true
    aws --endpoint-url=http://localstack-internal.localstack.svc.cluster.local:4566 s3 mb s3://app-artifacts || true
    
    # Create example SQS queues
    aws --endpoint-url=http://localstack-internal.localstack.svc.cluster.local:4566 sqs create-queue --queue-name app-events || true
    aws --endpoint-url=http://localstack-internal.localstack.svc.cluster.local:4566 sqs create-queue --queue-name app-dlq || true
    aws --endpoint-url=http://localstack-internal.localstack.svc.cluster.local:4566 sqs create-queue --queue-name app-processing || true
    
    # Create example SNS topics
    aws --endpoint-url=http://localstack-internal.localstack.svc.cluster.local:4566 sns create-topic --name app-alerts || true
    aws --endpoint-url=http://localstack-internal.localstack.svc.cluster.local:4566 sns create-topic --name app-notifications || true
    
    echo "LocalStack initialization complete!"'

# Run initialization job
echo "🔄 Running initialization job..."
kubectl delete job localstack-init -n localstack --ignore-not-found=true
kubectl apply -f init-job.yaml

# Wait for job completion
echo "⏳ Waiting for initialization to complete..."
kubectl wait --for=condition=complete --timeout=120s job/localstack-init -n localstack

echo "✅ LocalStack initialization complete!"
echo ""
echo "🎯 Created AWS resources:"
echo "  • S3 Buckets: app-data, app-config, app-logs, app-artifacts"
echo "  • SQS Queues: app-events, app-dlq, app-processing"
echo "  • SNS Topics: app-alerts, app-notifications"
echo ""
echo "🧪 Test connection:"
echo "  kubectl run aws-cli --rm -i --tty --image=amazon/aws-cli:latest -- /bin/bash"
echo "  # Inside the pod:"
echo "  export AWS_ENDPOINT_URL=http://localstack-internal.localstack.svc.cluster.local:4566"
echo "  export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1"
echo "  aws s3 ls"