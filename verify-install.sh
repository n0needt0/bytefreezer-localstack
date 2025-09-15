#!/bin/bash

# LocalStack K3s Installation Verification Script
# This script tests the LocalStack deployment and MetalLB configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="localstack"
EXTERNAL_IP="192.168.86.105"
DEV_IP="192.168.86.104"
EDGE_PORT="4566"
DEV_PORT="4567"
ADMIN_PORT="4510"

echo -e "${BLUE}🔍 LocalStack K3s Installation Verification${NC}"
echo "=============================================="

# Function to check and report status
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1${NC}"
    else
        echo -e "${RED}❌ $1${NC}"
        return 1
    fi
}

# Function to test HTTP endpoint
test_endpoint() {
    local url="$1"
    local description="$2"
    local expected_status="${3:-200}"

    echo -n "Testing $description... "
    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "$expected_status"; then
        echo -e "${GREEN}✅${NC}"
        return 0
    else
        echo -e "${RED}❌${NC}"
        return 1
    fi
}

echo -e "\n${BLUE}1. Checking Kubernetes Resources${NC}"
echo "--------------------------------"

# Check namespace
echo -n "LocalStack namespace exists... "
kubectl get namespace $NAMESPACE >/dev/null 2>&1
check_status "Namespace '$NAMESPACE' exists"

# Check pods
echo -n "LocalStack pod is running... "
kubectl get pods -n $NAMESPACE -l app=localstack --no-headers | grep -q "Running"
check_status "LocalStack pod is running"

POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=localstack -o jsonpath='{.items[0].metadata.name}')
echo "Pod: $POD_NAME"

# Check pod readiness
echo -n "LocalStack pod is ready... "
kubectl get pods -n $NAMESPACE -l app=localstack --no-headers | grep -q "1/1"
check_status "LocalStack pod is ready"

echo -e "\n${BLUE}2. Checking MetalLB Configuration${NC}"
echo "--------------------------------"

# Check MetalLB namespace
echo -n "MetalLB namespace exists... "
kubectl get namespace metallb-system >/dev/null 2>&1
check_status "MetalLB namespace exists"

# Check MetalLB pods
echo -n "MetalLB controller is running... "
kubectl get pods -n metallb-system -l app=metallb,component=controller --no-headers | grep -q "Running"
check_status "MetalLB controller is running"

echo -n "MetalLB speakers are running... "
SPEAKER_COUNT=$(kubectl get pods -n metallb-system -l app=metallb,component=speaker --no-headers | grep -c "Running")
echo -e "${GREEN}✅ $SPEAKER_COUNT speaker(s) running${NC}"

# Check IP address pool
echo -n "IP address pool configured... "
kubectl get ipaddresspool -n metallb-system localstack-pool >/dev/null 2>&1
check_status "IP address pool 'localstack-pool' exists"

# Show IP pool details
echo "IP Pool Details:"
kubectl get ipaddresspool -n metallb-system localstack-pool -o jsonpath='{.spec.addresses}' | sed 's/\[//g' | sed 's/\]//g' | sed 's/"//g'
echo

echo -e "\n${BLUE}3. Checking Services and LoadBalancers${NC}"
echo "---------------------------------------"

# Check services
echo "Services status:"
kubectl get services -n $NAMESPACE

# Verify external IPs are assigned
echo -n "External service has external IP... "
kubectl get service -n $NAMESPACE localstack-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}' | grep -q "$EXTERNAL_IP"
check_status "External IP $EXTERNAL_IP assigned"

echo -n "Dev service has external IP... "
kubectl get service -n $NAMESPACE localstack-dev -o jsonpath='{.status.loadBalancer.ingress[0].ip}' | grep -q "$DEV_IP"
check_status "Dev IP $DEV_IP assigned"

echo -e "\n${BLUE}4. Testing LocalStack Health Endpoints${NC}"
echo "----------------------------------------"

# Test health endpoints
test_endpoint "http://$EXTERNAL_IP:$EDGE_PORT/_localstack/health" "External health endpoint"
test_endpoint "http://$DEV_IP:$DEV_PORT/_localstack/health" "Dev health endpoint"

echo -e "\n${BLUE}5. Testing AWS Services${NC}"
echo "------------------------"

# Test DynamoDB service
echo -n "Testing DynamoDB service... "
if curl -s -X POST "http://$EXTERNAL_IP:$EDGE_PORT/" \
    -H "Content-Type: application/x-amz-json-1.0" \
    -H "X-Amz-Target: DynamoDB_20120810.ListTables" \
    -d '{}' | grep -q "TableNames\|Error"; then
    echo -e "${GREEN}✅${NC}"
else
    echo -e "${RED}❌${NC}"
fi

echo -e "\n${BLUE}6. Performance and Resource Check${NC}"
echo "--------------------------------"

# Check pod resources
echo "Pod resource usage:"
kubectl top pod -n $NAMESPACE 2>/dev/null || echo "Metrics server not available"

# Check pod events
echo -e "\nRecent pod events:"
kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp' | tail -5

echo -e "\n${BLUE}7. Connectivity Test from Inside Cluster${NC}"
echo "-------------------------------------------"

# Test internal connectivity
echo -n "Testing internal service connectivity... "
kubectl run test-pod --rm -i --tty --restart=Never --image=curlimages/curl -- \
    curl -s "http://localstack-internal.$NAMESPACE.svc.cluster.local:4566/_localstack/health" >/dev/null 2>&1
check_status "Internal connectivity works"

echo -e "\n${BLUE}8. Configuration Summary${NC}"
echo "-------------------------"
echo "🌐 External endpoints:"
echo "   Main API:    http://$EXTERNAL_IP:$EDGE_PORT"
echo "   Dev API:     http://$DEV_IP:$DEV_PORT"
echo "   Admin UI:    http://$EXTERNAL_IP:$ADMIN_PORT"
echo ""
echo "🔧 Internal endpoints (from within cluster):"
echo "   Service:     http://localstack-internal.$NAMESPACE.svc.cluster.local:$EDGE_PORT"
echo "   External:    http://localstack-external.$NAMESPACE.svc.cluster.local:$EDGE_PORT"
echo ""
echo "📊 Available AWS services:"
curl -s "http://$EXTERNAL_IP:$EDGE_PORT/_localstack/health" | jq -r '.services | to_entries[] | select(.value == "available") | "   " + .key' 2>/dev/null || echo "   (Unable to fetch service list)"

echo -e "\n${BLUE}9. Sample AWS CLI Commands${NC}"
echo "---------------------------"
echo "Export these environment variables to use AWS CLI with LocalStack:"
echo ""
echo "export AWS_ACCESS_KEY_ID=test"
echo "export AWS_SECRET_ACCESS_KEY=test"
echo "export AWS_DEFAULT_REGION=us-east-1"
echo "export AWS_ENDPOINT_URL=http://$EXTERNAL_IP:$EDGE_PORT"
echo ""
echo "Test commands:"
echo "aws dynamodb list-tables"
echo "aws lambda list-functions"
echo "aws secretsmanager list-secrets"

echo -e "\n${GREEN}🎉 Verification Complete!${NC}"
echo "========================="

# Final status
if kubectl get pods -n $NAMESPACE -l app=localstack --no-headers | grep -q "1/1.*Running"; then
    echo -e "${GREEN}✅ LocalStack is running successfully on K3s with MetalLB!${NC}"
    exit 0
else
    echo -e "${RED}❌ LocalStack verification failed. Check the errors above.${NC}"
    exit 1
fi