#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

CHART_DIR="localstack"
RELEASE_NAME="localstack"
NAMESPACE="localstack"

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}    LocalStack Helm Chart Deployment${NC}"
    echo -e "${BLUE}============================================${NC}"
}

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --environment ENV    Environment (dev, prod, or custom values file)"
    echo "  -n, --name NAME          Release name (default: localstack)"
    echo "  -ns, --namespace NS      Namespace (default: localstack)"
    echo "  --dry-run               Perform a dry run"
    echo "  --upgrade               Upgrade existing installation"
    echo "  --uninstall             Uninstall LocalStack"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --environment dev"
    echo "  $0 --environment prod --name localstack-prod"
    echo "  $0 --environment values-custom.yaml --upgrade"
    echo "  $0 --uninstall"
}

check_prerequisites() {
    echo -e "${BLUE}🔍 Checking prerequisites...${NC}"
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        echo -e "${RED}❌ Helm not found. Please install Helm first.${NC}"
        exit 1
    fi
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}❌ kubectl not found. Please install kubectl first.${NC}"
        exit 1
    fi
    
    # Check if K3s cluster is accessible
    if ! kubectl get nodes &> /dev/null; then
        echo -e "${RED}❌ Cannot access K3s cluster. Please check your kubeconfig.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Prerequisites satisfied${NC}"
}

install_metallb() {
    echo -e "${BLUE}🌐 Checking MetalLB installation...${NC}"
    
    if ! kubectl get namespace metallb-system &> /dev/null; then
        echo -e "${YELLOW}⚠️  MetalLB not detected. Installing MetalLB...${NC}"
        kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
        echo -e "${BLUE}⏳ Waiting for MetalLB to be ready...${NC}"
        kubectl wait --for=condition=ready pod -l app=metallb -n metallb-system --timeout=300s
        echo -e "${GREEN}✅ MetalLB installed successfully${NC}"
    else
        echo -e "${GREEN}✅ MetalLB is already installed${NC}"
    fi
}

validate_values() {
    local values_file=$1
    
    if [ ! -f "$values_file" ]; then
        echo -e "${RED}❌ Values file not found: $values_file${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}📋 Using values file: $values_file${NC}"
    
    # Show network configuration from values
    if grep -q "addresses:" "$values_file"; then
        echo -e "${YELLOW}📊 Network configuration from values file:${NC}"
        grep -A 2 "addresses:" "$values_file" | head -3
        echo ""
        read -p "Does this network configuration look correct for your environment? (Y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            echo -e "${YELLOW}Please edit $values_file to match your network settings.${NC}"
            exit 1
        fi
    fi
}

deploy_localstack() {
    local environment=$1
    local release_name=$2
    local namespace=$3
    local dry_run=$4
    local upgrade=$5
    
    echo -e "${BLUE}🚀 Deploying LocalStack with Helm...${NC}"
    
    # Determine values file
    local values_file=""
    case $environment in
        "dev")
            values_file="$CHART_DIR/values-dev.yaml"
            ;;
        "prod")
            values_file="$CHART_DIR/values-prod.yaml"
            ;;
        "")
            values_file="$CHART_DIR/values.yaml"
            ;;
        *)
            # Custom values file
            values_file="$environment"
            ;;
    esac
    
    validate_values "$values_file"
    
    # Build helm command
    local helm_cmd="helm"
    if [ "$upgrade" = "true" ]; then
        helm_cmd="$helm_cmd upgrade"
    else
        helm_cmd="$helm_cmd install"
    fi
    
    helm_cmd="$helm_cmd $release_name $CHART_DIR"
    helm_cmd="$helm_cmd --values $values_file"
    helm_cmd="$helm_cmd --namespace $namespace"
    helm_cmd="$helm_cmd --create-namespace"
    
    if [ "$dry_run" = "true" ]; then
        helm_cmd="$helm_cmd --dry-run --debug"
        echo -e "${YELLOW}🧪 Performing dry run...${NC}"
    fi
    
    echo -e "${BLUE}📋 Executing: $helm_cmd${NC}"
    eval $helm_cmd
    
    if [ "$dry_run" != "true" ]; then
        echo -e "${GREEN}✅ LocalStack deployed successfully!${NC}"
        
        echo -e "${BLUE}⏳ Waiting for deployment to be ready...${NC}"
        kubectl wait --for=condition=available --timeout=300s deployment/$release_name -n $namespace
        
        echo -e "${BLUE}📊 Deployment status:${NC}"
        helm status $release_name -n $namespace
        
        echo -e "${BLUE}🌐 Service endpoints:${NC}"
        kubectl get svc -n $namespace
    fi
}

uninstall_localstack() {
    local release_name=$1
    local namespace=$2
    
    echo -e "${BLUE}🗑️  Uninstalling LocalStack...${NC}"
    
    if helm list -n $namespace | grep -q $release_name; then
        helm uninstall $release_name -n $namespace
        echo -e "${GREEN}✅ LocalStack uninstalled successfully${NC}"
    else
        echo -e "${YELLOW}⚠️  LocalStack release '$release_name' not found in namespace '$namespace'${NC}"
    fi
    
    # Optionally remove namespace
    read -p "Remove namespace '$namespace'? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        kubectl delete namespace $namespace --ignore-not-found=true
        echo -e "${GREEN}✅ Namespace removed${NC}"
    fi
}

# Parse command line arguments
ENVIRONMENT=""
DRY_RUN="false"
UPGRADE="false"
UNINSTALL="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -n|--name)
            RELEASE_NAME="$2"
            shift 2
            ;;
        -ns|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --upgrade)
            UPGRADE="true"
            shift
            ;;
        --uninstall)
            UNINSTALL="true"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
print_header

if [ "$UNINSTALL" = "true" ]; then
    check_prerequisites
    uninstall_localstack "$RELEASE_NAME" "$NAMESPACE"
else
    check_prerequisites
    install_metallb
    deploy_localstack "$ENVIRONMENT" "$RELEASE_NAME" "$NAMESPACE" "$DRY_RUN" "$UPGRADE"
fi

echo -e "${GREEN}🎉 Operation completed successfully!${NC}"