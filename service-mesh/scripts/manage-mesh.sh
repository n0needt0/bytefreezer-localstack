#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}    ByteFreezer Service Mesh Manager${NC}"
    echo -e "${BLUE}============================================${NC}"
}

show_help() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  status       Show service mesh status"
    echo "  dashboard    Open Kiali dashboard"
    echo "  tracing      Open Jaeger tracing UI"
    echo "  grafana      Open Grafana metrics"
    echo "  analyze      Analyze mesh configuration"
    echo "  traffic      Show traffic policies"
    echo "  security     Show security policies"
    echo "  logs         Show Istio logs"
    echo "  restart      Restart mesh components"
    echo "  uninstall    Remove Istio from cluster"
    echo "  help         Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 dashboard"
    echo "  $0 analyze"
}

check_istio() {
    if ! command -v istioctl &> /dev/null; then
        echo -e "${RED}❌ istioctl not found. Please install Istio first.${NC}"
        exit 1
    fi
    
    if ! kubectl get namespace istio-system &> /dev/null; then
        echo -e "${RED}❌ Istio not installed. Run ./install-istio.sh first.${NC}"
        exit 1
    fi
}

show_status() {
    echo -e "${BLUE}📊 Service Mesh Status${NC}"
    echo "======================"
    
    # Istio version
    echo -e "${BLUE}Istio Version:${NC}"
    istioctl version --short
    echo ""
    
    # Control plane status
    echo -e "${BLUE}Control Plane Status:${NC}"
    kubectl get pods -n istio-system
    echo ""
    
    # Proxy status
    echo -e "${BLUE}Proxy Status:${NC}"
    istioctl proxy-status
    echo ""
    
    # Mesh configuration validation
    echo -e "${BLUE}Configuration Validation:${NC}"
    istioctl analyze || true
    echo ""
    
    # Service mesh services
    echo -e "${BLUE}Mesh Services:${NC}"
    kubectl get services -l istio-injection=enabled --all-namespaces
}

open_dashboard() {
    echo -e "${BLUE}🌐 Opening Kiali Dashboard...${NC}"
    echo "Dashboard will be available at: http://localhost:20001"
    echo "Press Ctrl+C to stop port forwarding"
    kubectl port-forward svc/kiali 20001:20001 -n istio-system
}

open_tracing() {
    echo -e "${BLUE}🔍 Opening Jaeger Tracing UI...${NC}"
    echo "Jaeger will be available at: http://localhost:16686"
    echo "Press Ctrl+C to stop port forwarding"
    kubectl port-forward svc/jaeger 16686:16686 -n istio-system
}

open_grafana() {
    echo -e "${BLUE}📊 Opening Grafana Metrics...${NC}"
    echo "Grafana will be available at: http://localhost:3000"
    echo "Press Ctrl+C to stop port forwarding"
    kubectl port-forward svc/grafana 3000:3000 -n istio-system
}

analyze_mesh() {
    echo -e "${BLUE}🔍 Analyzing Service Mesh Configuration${NC}"
    echo "======================================"
    
    echo -e "${BLUE}Configuration Issues:${NC}"
    istioctl analyze --all-namespaces || true
    echo ""
    
    echo -e "${BLUE}Proxy Configuration:${NC}"
    istioctl proxy-config cluster --fqdn localstack-internal.localstack.svc.cluster.local
    echo ""
    
    echo -e "${BLUE}mTLS Status:${NC}"
    istioctl authn tls-check || true
}

show_traffic() {
    echo -e "${BLUE}🚦 Traffic Management Policies${NC}"
    echo "=============================="
    
    echo -e "${BLUE}Virtual Services:${NC}"
    kubectl get virtualservices --all-namespaces -o wide
    echo ""
    
    echo -e "${BLUE}Destination Rules:${NC}"
    kubectl get destinationrules --all-namespaces -o wide
    echo ""
    
    echo -e "${BLUE}Gateways:${NC}"
    kubectl get gateways --all-namespaces -o wide
    echo ""
    
    echo -e "${BLUE}Service Entries:${NC}"
    kubectl get serviceentries --all-namespaces -o wide || echo "None found"
}

show_security() {
    echo -e "${BLUE}🔒 Security Policies${NC}"
    echo "==================="
    
    echo -e "${BLUE}Peer Authentication:${NC}"
    kubectl get peerauthentication --all-namespaces -o wide
    echo ""
    
    echo -e "${BLUE}Authorization Policies:${NC}"
    kubectl get authorizationpolicy --all-namespaces -o wide
    echo ""
    
    echo -e "${BLUE}Network Policies:${NC}"
    kubectl get networkpolicy --all-namespaces -o wide || echo "None found"
}

show_logs() {
    echo -e "${BLUE}📋 Service Mesh Logs${NC}"
    echo "==================="
    
    echo "Select component to view logs:"
    echo "1. Istiod (Control Plane)"
    echo "2. Istio Proxy (Ingress Gateway)"
    echo "3. Kiali"
    echo "4. Jaeger"
    echo "5. All components"
    
    read -p "Enter choice [1-5]: " choice
    
    case $choice in
        1)
            kubectl logs -l app=istiod -n istio-system --tail=100 -f
            ;;
        2)
            kubectl logs -l app=istio-proxy -n istio-system --tail=100 -f
            ;;
        3)
            kubectl logs -l app=kiali -n istio-system --tail=100 -f
            ;;
        4)
            kubectl logs -l app=jaeger -n istio-system --tail=100 -f
            ;;
        5)
            kubectl logs --all-containers -n istio-system --tail=50
            ;;
        *)
            echo "Invalid choice"
            ;;
    esac
}

restart_mesh() {
    echo -e "${BLUE}🔄 Restarting Service Mesh Components${NC}"
    echo "====================================="
    
    read -p "This will restart all Istio components. Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
    
    echo "Restarting istiod..."
    kubectl rollout restart deployment/istiod -n istio-system
    
    echo "Restarting ingress gateway..."
    kubectl rollout restart deployment/istio-ingressgateway -n istio-system
    
    echo "Restarting observability components..."
    kubectl rollout restart deployment/kiali -n istio-system
    kubectl rollout restart deployment/jaeger -n istio-system
    kubectl rollout restart deployment/grafana -n istio-system
    kubectl rollout restart deployment/prometheus -n istio-system
    
    echo -e "${GREEN}✅ Components restarted. Waiting for readiness...${NC}"
    kubectl rollout status deployment/istiod -n istio-system
    kubectl rollout status deployment/istio-ingressgateway -n istio-system
}

uninstall_mesh() {
    echo -e "${RED}🗑️  Uninstalling Service Mesh${NC}"
    echo "============================"
    
    echo -e "${YELLOW}⚠️  WARNING: This will remove Istio and all mesh configurations!${NC}"
    read -p "Are you sure? Type 'yes' to confirm: " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "Cancelled."
        exit 0
    fi
    
    echo "Removing Istio configurations..."
    kubectl delete -f ../config/ --ignore-not-found=true
    
    echo "Removing Istio components..."
    kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml --ignore-not-found=true
    kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/jaeger.yaml --ignore-not-found=true
    kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/prometheus.yaml --ignore-not-found=true
    kubectl delete -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/grafana.yaml --ignore-not-found=true
    
    echo "Uninstalling Istio..."
    istioctl uninstall --purge -y
    
    echo "Removing namespace labels..."
    kubectl label namespace localstack istio-injection- --ignore-not-found=true
    kubectl label namespace bytefreezer-dev istio-injection- --ignore-not-found=true
    kubectl label namespace default istio-injection- --ignore-not-found=true
    
    echo -e "${GREEN}✅ Service mesh uninstalled${NC}"
}

# Main script
case "${1:-help}" in
    status)
        print_header
        check_istio
        show_status
        ;;
    dashboard)
        check_istio
        open_dashboard
        ;;
    tracing)
        check_istio
        open_tracing
        ;;
    grafana)
        check_istio
        open_grafana
        ;;
    analyze)
        print_header
        check_istio
        analyze_mesh
        ;;
    traffic)
        print_header
        check_istio
        show_traffic
        ;;
    security)
        print_header
        check_istio
        show_security
        ;;
    logs)
        check_istio
        show_logs
        ;;
    restart)
        print_header
        check_istio
        restart_mesh
        ;;
    uninstall)
        print_header
        check_istio
        uninstall_mesh
        ;;
    help|--help|-h)
        print_header
        show_help
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac