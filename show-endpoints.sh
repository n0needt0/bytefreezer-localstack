#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🌐 LocalStack Service Endpoints${NC}"
echo "==============================="

NAMESPACE="localstack"

# Check if namespace exists
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    echo -e "${RED}❌ LocalStack namespace not found. Run ./deploy.sh first.${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}📊 Service Status:${NC}"
kubectl get svc -n $NAMESPACE -o wide

echo ""
echo -e "${BLUE}📋 Connection Details:${NC}"
echo "======================"

# Internal service
INTERNAL_IP=$(kubectl get svc localstack-internal -n $NAMESPACE -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "N/A")
if [ "$INTERNAL_IP" != "N/A" ]; then
    echo -e "${GREEN}🏠 Internal (Cluster) Access:${NC}"
    echo "   Service: localstack-internal"
    echo "   ClusterIP: $INTERNAL_IP"
    echo "   DNS: localstack-internal.localstack.svc.cluster.local"
    echo "   Endpoint: http://localstack-internal.localstack.svc.cluster.local:4566"
    echo "   Admin: http://localstack-internal.localstack.svc.cluster.local:4510"
    echo ""
fi

# External LoadBalancer services
EXTERNAL_IP=$(kubectl get svc localstack-external -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
if [ "$EXTERNAL_IP" != "pending" ] && [ -n "$EXTERNAL_IP" ]; then
    echo -e "${GREEN}🌍 External (Production) Access:${NC}"
    echo "   Service: localstack-external"
    echo "   LoadBalancer IP: $EXTERNAL_IP"
    echo "   Endpoint: http://$EXTERNAL_IP:4566"
    echo "   Admin: http://$EXTERNAL_IP:4510"
    echo ""
else
    echo -e "${YELLOW}⏳ External (Production) LoadBalancer:${NC}"
    echo "   Status: IP assignment pending"
    echo "   Service: localstack-external"
    echo ""
fi

DEV_IP=$(kubectl get svc localstack-dev -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
if [ "$DEV_IP" != "pending" ] && [ -n "$DEV_IP" ]; then
    echo -e "${GREEN}🛠️ Development Access:${NC}"
    echo "   Service: localstack-dev"
    echo "   LoadBalancer IP: $DEV_IP"
    echo "   Endpoint: http://$DEV_IP:4567"
    echo "   Admin: http://$DEV_IP:4511"
    echo ""
else
    echo -e "${YELLOW}⏳ Development LoadBalancer:${NC}"
    echo "   Status: IP assignment pending"
    echo "   Service: localstack-dev"
    echo ""
fi

echo -e "${BLUE}🔧 Environment Variables:${NC}"
echo "========================"
echo ""
echo -e "${GREEN}For Kubernetes Services:${NC}"
echo "export AWS_ENDPOINT_URL=http://localstack-internal.localstack.svc.cluster.local:4566"
echo "export AWS_ACCESS_KEY_ID=test"
echo "export AWS_SECRET_ACCESS_KEY=test"
echo "export AWS_DEFAULT_REGION=us-east-1"
echo ""

if [ "$EXTERNAL_IP" != "pending" ] && [ -n "$EXTERNAL_IP" ]; then
    echo -e "${GREEN}For External Applications (Production):${NC}"
    echo "export AWS_ENDPOINT_URL=http://$EXTERNAL_IP:4566"
    echo "export AWS_ACCESS_KEY_ID=test"
    echo "export AWS_SECRET_ACCESS_KEY=test"
    echo "export AWS_DEFAULT_REGION=us-east-1"
    echo ""
fi

if [ "$DEV_IP" != "pending" ] && [ -n "$DEV_IP" ]; then
    echo -e "${GREEN}For External Applications (Development):${NC}"
    echo "export AWS_ENDPOINT_URL=http://$DEV_IP:4567"
    echo "export AWS_ACCESS_KEY_ID=test"
    echo "export AWS_SECRET_ACCESS_KEY=test"
    echo "export AWS_DEFAULT_REGION=us-east-1"
    echo ""
fi

# Check if any LoadBalancer IPs are still pending
if [ "$EXTERNAL_IP" = "pending" ] || [ "$DEV_IP" = "pending" ]; then
    echo -e "${YELLOW}⏳ Some LoadBalancer IPs are still pending.${NC}"
    echo "   This is normal immediately after deployment."
    echo "   Check MetalLB status: kubectl get pods -n metallb-system"
    echo "   Watch for IP assignment: kubectl get svc -n localstack -w"
    echo ""
fi

echo -e "${BLUE}🧪 Quick Test:${NC}"
echo "============="
if [ "$EXTERNAL_IP" != "pending" ] && [ -n "$EXTERNAL_IP" ]; then
    echo "curl http://$EXTERNAL_IP:4566/_localstack/health"
elif [ "$INTERNAL_IP" != "N/A" ]; then
    echo "kubectl run test --rm -i --tty --image=curlimages/curl:latest -- curl http://localstack-internal.localstack.svc.cluster.local:4566/_localstack/health"
fi

echo ""
echo -e "${BLUE}📖 Management Commands:${NC}"
echo "======================"
echo "./manage.sh status    - Check detailed status"
echo "./manage.sh shell     - Interactive AWS CLI"
echo "./manage.sh resources - List AWS resources"