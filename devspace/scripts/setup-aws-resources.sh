#!/bin/bash
set -e

echo "🔧 Setting up additional AWS resources for development..."

# Wait for LocalStack to be ready
echo "⏳ Waiting for LocalStack..."
kubectl wait --for=condition=available --timeout=300s deployment/localstack -n localstack

# Get LocalStack endpoint
LOCALSTACK_IP=$(kubectl get svc localstack-dev -n localstack -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
if [ -z "$LOCALSTACK_IP" ]; then
    ENDPOINT="http://localstack-internal.localstack.svc.cluster.local:4566"
    echo "Using internal endpoint: $ENDPOINT"
else
    ENDPOINT="http://$LOCALSTACK_IP:4567"
    echo "Using external endpoint: $ENDPOINT"
fi

# Set AWS CLI environment
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL=$ENDPOINT

# Create additional development resources
echo "📦 Creating additional S3 buckets..."
kubectl run aws-setup --rm -i --restart=Never --image=amazon/aws-cli:latest --namespace=localstack -- \
    /bin/bash -c "
    export AWS_ENDPOINT_URL=$ENDPOINT
    export AWS_ACCESS_KEY_ID=test
    export AWS_SECRET_ACCESS_KEY=test
    export AWS_DEFAULT_REGION=us-east-1
    
    # Additional buckets for specific services
    aws s3 mb s3://bytefreezer-proxy-spool || true
    aws s3 mb s3://bytefreezer-receiver-data || true
    aws s3 mb s3://bytefreezer-piper-output || true
    aws s3 mb s3://bytefreezer-integration-tests || true
    
    # Create IAM policies for development
    aws iam create-policy --policy-name ByteFreezerDevPolicy --policy-document '{
        \"Version\": \"2012-10-17\",
        \"Statement\": [
            {
                \"Effect\": \"Allow\",
                \"Action\": \"s3:*\",
                \"Resource\": \"*\"
            },
            {
                \"Effect\": \"Allow\", 
                \"Action\": \"sqs:*\",
                \"Resource\": \"*\"
            },
            {
                \"Effect\": \"Allow\",
                \"Action\": \"sns:*\", 
                \"Resource\": \"*\"
            }
        ]
    }' || true
    
    # Create SQS queues with DLQ configuration
    aws sqs create-queue --queue-name bytefreezer-proxy-dlq || true
    aws sqs create-queue --queue-name bytefreezer-receiver-dlq || true
    
    # Create SNS topics for service communication
    aws sns create-topic --name bytefreezer-proxy-events || true
    aws sns create-topic --name bytefreezer-receiver-events || true
    aws sns create-topic --name bytefreezer-piper-events || true
    
    echo 'AWS resources setup completed!'
    "

echo "✅ AWS resources setup completed!"