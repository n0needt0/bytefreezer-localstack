#!/bin/bash

set -e

NAMESPACE="localstack"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}        LocalStack K3s Management${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_prerequisites() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl first."
        exit 1
    fi
    
    if ! kubectl get nodes &> /dev/null; then
        print_error "Cannot access K3s cluster. Please check your kubeconfig."
        exit 1
    fi
}

show_status() {
    echo -e "\n${BLUE}📊 LocalStack Status${NC}"
    echo "==================="
    
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        print_status "Namespace exists"
        
        # Check deployment
        if kubectl get deployment localstack -n $NAMESPACE &> /dev/null; then
            READY=$(kubectl get deployment localstack -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
            DESIRED=$(kubectl get deployment localstack -n $NAMESPACE -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
            
            if [ "$READY" = "$DESIRED" ] && [ "$READY" != "0" ]; then
                print_status "Deployment ready ($READY/$DESIRED)"
            else
                print_warning "Deployment not ready ($READY/$DESIRED)"
            fi
        else
            print_warning "Deployment not found"
        fi
        
        # Check internal service
        if kubectl get service localstack-internal -n $NAMESPACE &> /dev/null; then
            CLUSTER_IP=$(kubectl get service localstack-internal -n $NAMESPACE -o jsonpath='{.spec.clusterIP}')
            print_status "Internal service available at: http://$CLUSTER_IP:4566"
        fi
        
        # Check external LoadBalancer services
        if kubectl get service localstack-external -n $NAMESPACE &> /dev/null; then
            EXTERNAL_IP=$(kubectl get service localstack-external -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
            if [ "$EXTERNAL_IP" != "pending" ] && [ -n "$EXTERNAL_IP" ]; then
                print_status "External LoadBalancer available at: http://$EXTERNAL_IP:4566"
            else
                print_warning "External LoadBalancer IP pending"
            fi
        fi
        
        if kubectl get service localstack-dev -n $NAMESPACE &> /dev/null; then
            DEV_IP=$(kubectl get service localstack-dev -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending")
            if [ "$DEV_IP" != "pending" ] && [ -n "$DEV_IP" ]; then
                print_status "Development LoadBalancer available at: http://$DEV_IP:4567"
            else
                print_warning "Development LoadBalancer IP pending"
            fi
        fi
        
        # Check PVC
        if kubectl get pvc localstack-data-pvc -n $NAMESPACE &> /dev/null; then
            PVC_STATUS=$(kubectl get pvc localstack-data-pvc -n $NAMESPACE -o jsonpath='{.status.phase}')
            if [ "$PVC_STATUS" = "Bound" ]; then
                print_status "Persistent storage bound"
            else
                print_warning "Persistent storage status: $PVC_STATUS"
            fi
        fi
        
    else
        print_warning "LocalStack not deployed"
    fi
}

show_logs() {
    echo -e "\n${BLUE}📋 LocalStack Logs${NC}"
    echo "=================="
    kubectl logs -f deployment/localstack -n $NAMESPACE
}

show_resources() {
    echo -e "\n${BLUE}🎯 AWS Resources${NC}"
    echo "================"
    
    # Try to get LoadBalancer IP first, fall back to internal service
    EXTERNAL_IP=$(kubectl get service localstack-external -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "$EXTERNAL_IP" ] && [ "$EXTERNAL_IP" != "pending" ]; then
        ENDPOINT="http://$EXTERNAL_IP:4566"
    else
        ENDPOINT="http://localstack-internal.localstack.svc.cluster.local:4566"
    fi
    
    echo "Using endpoint: $ENDPOINT"
    echo ""
    
    # Test if LocalStack is accessible
    if curl -s "$ENDPOINT/_localstack/health" > /dev/null; then
        print_status "LocalStack is accessible"
        
        echo ""
        echo "S3 Buckets:"
        kubectl run aws-test --rm -i --restart=Never --image=amazon/aws-cli:latest -- \
            aws --endpoint-url=$ENDPOINT --region=us-east-1 --output=table \
            s3 ls 2>/dev/null || echo "  (none or unavailable)"
        
        echo ""
        echo "SQS Queues:"
        kubectl run aws-test --rm -i --restart=Never --image=amazon/aws-cli:latest -- \
            aws --endpoint-url=$ENDPOINT --region=us-east-1 --output=table \
            sqs list-queues 2>/dev/null || echo "  (none or unavailable)"
        
        echo ""
        echo "SNS Topics:"
        kubectl run aws-test --rm -i --restart=Never --image=amazon/aws-cli:latest -- \
            aws --endpoint-url=$ENDPOINT --region=us-east-1 --output=table \
            sns list-topics 2>/dev/null || echo "  (none or unavailable)"
        
    else
        print_error "LocalStack not accessible at $ENDPOINT"
    fi
}

restart_localstack() {
    echo -e "\n${BLUE}🔄 Restarting LocalStack${NC}"
    echo "======================="
    
    kubectl rollout restart deployment/localstack -n $NAMESPACE
    kubectl rollout status deployment/localstack -n $NAMESPACE
    print_status "LocalStack restarted"
}

run_shell() {
    echo -e "\n${BLUE}🐚 AWS CLI Shell${NC}"
    echo "==============="
    echo "Starting interactive AWS CLI session..."
    echo "LocalStack endpoint will be pre-configured."
    echo ""
    
    kubectl run aws-cli-shell --rm -i --tty --restart=Never --image=amazon/aws-cli:latest -- \
        /bin/bash -c "
        export AWS_ENDPOINT_URL=http://localstack-internal.localstack.svc.cluster.local:4566
        export AWS_ACCESS_KEY_ID=test
        export AWS_SECRET_ACCESS_KEY=test
        export AWS_DEFAULT_REGION=us-east-1
        echo 'AWS CLI configured for LocalStack'
        echo 'Internal Endpoint: \$AWS_ENDPOINT_URL'
        echo ''
        echo 'Try: aws s3 ls'
        echo '     aws sqs list-queues'
        echo '     aws sns list-topics'
        echo ''
        exec /bin/bash
        "
}

show_help() {
    echo -e "\n${BLUE}📖 LocalStack Management Commands${NC}"
    echo "================================="
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  status    Show LocalStack deployment status"
    echo "  logs      Show and follow LocalStack logs"
    echo "  restart   Restart LocalStack deployment"
    echo "  resources List AWS resources in LocalStack"
    echo "  shell     Start interactive AWS CLI session"
    echo "  help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 logs"
    echo "  $0 shell"
}

# Main script logic
case "${1:-status}" in
    status)
        print_header
        check_prerequisites
        show_status
        ;;
    logs)
        check_prerequisites
        show_logs
        ;;
    restart)
        print_header
        check_prerequisites
        restart_localstack
        ;;
    resources)
        print_header
        check_prerequisites
        show_resources
        ;;
    shell)
        check_prerequisites
        run_shell
        ;;
    help|--help|-h)
        print_header
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac