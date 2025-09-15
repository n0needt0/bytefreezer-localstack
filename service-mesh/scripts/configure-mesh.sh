#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🌐 Configuring ByteFreezer Service Mesh${NC}"
echo "======================================"

# Check if Istio is installed
if ! kubectl get namespace istio-system &> /dev/null; then
    echo -e "${RED}❌ Istio not installed. Run ./install-istio.sh first${NC}"
    exit 1
fi

# Apply ByteFreezer service mesh configuration
echo -e "${BLUE}📋 Applying service mesh configuration...${NC}"

# Apply all Istio configurations
kubectl apply -f ../config/

# Wait for configurations to be applied
echo -e "${BLUE}⏳ Waiting for configurations to be ready...${NC}"
sleep 5

# Restart LocalStack to get sidecar injection
if kubectl get deployment localstack -n localstack &> /dev/null; then
    echo -e "${BLUE}🔄 Restarting LocalStack with sidecar injection...${NC}"
    kubectl rollout restart deployment/localstack -n localstack
    kubectl rollout status deployment/localstack -n localstack --timeout=300s
fi

# Check mesh status
echo -e "${BLUE}📊 Service Mesh Status:${NC}"
istioctl proxy-status

echo ""
echo -e "${GREEN}🎉 Service Mesh Configuration Complete!${NC}"
echo ""
echo -e "${BLUE}📋 Access Information:${NC}"
echo "Kiali Dashboard: kubectl port-forward svc/kiali 20001:20001 -n istio-system"
echo "Then visit: http://localhost:20001"
echo ""
echo "Jaeger Tracing: kubectl port-forward svc/jaeger 16686:16686 -n istio-system"
echo "Then visit: http://localhost:16686"
echo ""
echo -e "${BLUE}🔍 Useful Commands:${NC}"
echo "Check proxy status: istioctl proxy-status"
echo "Check configuration: istioctl proxy-config cluster [POD_NAME] -n [NAMESPACE]"
echo "View traffic policies: kubectl get virtualservices,destinationrules -A"