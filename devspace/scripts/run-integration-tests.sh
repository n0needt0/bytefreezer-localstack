#!/bin/bash
set -e

echo "🧪 Running Integration Tests..."

# Set environment variables
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# Get LocalStack endpoint
LOCALSTACK_IP=$(kubectl get svc localstack-dev -n localstack -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
if [ -z "$LOCALSTACK_IP" ]; then
    export AWS_ENDPOINT_URL="http://localstack-internal.localstack.svc.cluster.local:4566"
else
    export AWS_ENDPOINT_URL="http://$LOCALSTACK_IP:4567"
fi

echo "Testing LocalStack connectivity..."

# Test S3 connectivity
kubectl run test-s3 --rm -i --restart=Never --image=amazon/aws-cli:latest --namespace=localstack -- \
    aws s3 ls --endpoint-url=$AWS_ENDPOINT_URL || (echo "❌ S3 test failed" && exit 1)

echo "✅ S3 connectivity test passed"

# Test SQS connectivity  
kubectl run test-sqs --rm -i --restart=Never --image=amazon/aws-cli:latest --namespace=localstack -- \
    aws sqs list-queues --endpoint-url=$AWS_ENDPOINT_URL || (echo "❌ SQS test failed" && exit 1)

echo "✅ SQS connectivity test passed"

# Test SNS connectivity
kubectl run test-sns --rm -i --restart=Never --image=amazon/aws-cli:latest --namespace=localstack -- \
    aws sns list-topics --endpoint-url=$AWS_ENDPOINT_URL || (echo "❌ SNS test failed" && exit 1)

echo "✅ SNS connectivity test passed"

# Test service endpoints if they exist
SERVICES=("bytefreezer-proxy" "bytefreezer-receiver" "bytefreezer-piper")
for service in "${SERVICES[@]}"; do
    if kubectl get svc $service -n bytefreezer-dev &> /dev/null; then
        SERVICE_IP=$(kubectl get svc $service -n bytefreezer-dev -o jsonpath='{.spec.clusterIP}')
        if curl -s --connect-timeout 5 http://$SERVICE_IP/health &> /dev/null; then
            echo "✅ $service health check passed"
        else
            echo "⚠️  $service health check failed (service may not be fully ready)"
        fi
    else
        echo "ℹ️  $service not deployed"
    fi
done

echo "🎉 Integration tests completed!"