#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

ISTIO_VERSION="1.20.0"
INSTALL_DIR="/tmp/istio-install"

echo -e "${BLUE}🚀 Installing Istio Service Mesh${NC}"
echo "=================================="

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found${NC}"
    exit 1
fi

# Download and install Istio
echo -e "${BLUE}📥 Downloading Istio ${ISTIO_VERSION}...${NC}"
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

if [ ! -f "istioctl" ]; then
    curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} sh -
    sudo mv istio-${ISTIO_VERSION}/bin/istioctl /usr/local/bin/
    echo -e "${GREEN}✅ Istioctl installed${NC}"
fi

# Install Istio
echo -e "${BLUE}🔧 Installing Istio...${NC}"
istioctl install --set values.defaultRevision=default -y

# Wait for Istio components
echo -e "${BLUE}⏳ Waiting for Istio components...${NC}"
kubectl wait --for=condition=available --timeout=600s deployment/istiod -n istio-system

# Install Istio addons (Kiali, Jaeger, Prometheus, Grafana)
echo -e "${BLUE}📊 Installing observability addons...${NC}"

# Kiali (Service Mesh Dashboard)
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml

# Jaeger (Distributed Tracing)
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/jaeger.yaml

# Prometheus (Metrics Collection)
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml

# Grafana (Metrics Visualization)
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/grafana.yaml

# Wait for addons
echo -e "${BLUE}⏳ Waiting for addons to be ready...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/kiali -n istio-system
kubectl wait --for=condition=available --timeout=300s deployment/jaeger -n istio-system

# Enable automatic sidecar injection for ByteFreezer namespaces
echo -e "${BLUE}🔗 Enabling sidecar injection...${NC}"
kubectl label namespace localstack istio-injection=enabled --overwrite
kubectl label namespace bytefreezer-dev istio-injection=enabled --overwrite || true
kubectl label namespace default istio-injection=enabled --overwrite

echo -e "${GREEN}🎉 Istio installation completed!${NC}"
echo ""
echo -e "${BLUE}📋 Access Information:${NC}"
echo "Kiali Dashboard: kubectl port-forward svc/kiali 20001:20001 -n istio-system"
echo "Jaeger UI: kubectl port-forward svc/jaeger 16686:16686 -n istio-system"
echo "Grafana: kubectl port-forward svc/grafana 3000:3000 -n istio-system"
echo ""
echo -e "${BLUE}🔧 Next Steps:${NC}"
echo "1. Apply ByteFreezer service mesh configuration: ./configure-mesh.sh"
echo "2. Deploy services with sidecar injection enabled"
echo "3. Access Kiali dashboard to visualize service mesh"

# Cleanup
rm -rf $INSTALL_DIR