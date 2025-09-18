# LocalStack Helm Chart - Complete Overview

## 📦 Chart Structure

```
helm-chart/
├── deploy-helm.sh              # Deployment automation script
├── validate-chart.sh           # Chart validation and testing
├── README.md                   # Comprehensive documentation
├── OVERVIEW.md                 # This file
└── localstack/                 # Helm chart directory
    ├── Chart.yaml              # Chart metadata and version
    ├── values.yaml             # Default configuration values
    ├── values-dev.yaml         # Development environment config
    ├── values-prod.yaml        # Production environment config
    └── templates/              # Kubernetes resource templates
        ├── _helpers.tpl        # Template helper functions
        ├── NOTES.txt           # Post-install instructions
        ├── namespace.yaml      # Namespace creation
        ├── deployment.yaml     # LocalStack deployment
        ├── services.yaml       # Three service types
        ├── pvc.yaml           # Persistent volume claim
        ├── configmap.yaml     # Configuration and init scripts
        ├── init-job.yaml      # AWS resource initialization job
        ├── metallb.yaml       # MetalLB IP pools and L2 advertisement
        ├── hpa.yaml           # Horizontal Pod Autoscaler
        ├── pod-disruption-budget.yaml  # Pod disruption budget
        └── servicemonitor.yaml # Prometheus ServiceMonitor
```

## 🚀 Quick Start Commands

### Development Deployment
```bash
cd helm-chart
./deploy-helm.sh --environment dev
```

### Production Deployment  
```bash
cd helm-chart
./deploy-helm.sh --environment prod
```

### Custom Configuration
```bash
# Create custom values
cp localstack/values.yaml my-values.yaml
# Edit my-values.yaml
./deploy-helm.sh --environment my-values.yaml
```

### Validation and Testing
```bash
./validate-chart.sh  # Validate chart structure and templates
./deploy-helm.sh --environment dev --dry-run  # Test deployment
```

## 🌐 Service Architecture

The chart creates three service endpoints:

1. **Internal (`ClusterIP`)**
   - `localstack-internal.localstack.svc.cluster.local:4566`
   - For services running inside the Kubernetes cluster
   - Fastest access, no external networking

2. **External Production (`LoadBalancer`)**
   - MetalLB assigned IP on ports 4566/4510
   - For external applications and production testing
   - Full production-like access

3. **Development (`LoadBalancer`)**
   - MetalLB assigned IP on ports 4567/4511
   - Alternative endpoint for development testing
   - Separates dev and prod external access

## ⚙️ Configuration Environments

### Default (`values.yaml`)
- Balanced configuration for general use
- All services enabled with moderate resources
- Complete application resource initialization
- Production features available but can be disabled

### Development (`values-dev.yaml`)
- **Optimized for**: Local development and testing
- **Resources**: 256Mi memory, 100m CPU
- **Storage**: 5Gi persistent volume
- **Services**: Core AWS services only (S3, SQS, SNS, DynamoDB, Lambda, IAM)
- **Features**: Simplified setup, dev-prefixed resources
- **External Access**: Internal + Development LoadBalancer only

### Production (`values-prod.yaml`)
- **Optimized for**: Production-like testing environments
- **Resources**: 1Gi memory, 500m CPU (up to 4Gi/2CPU limits)
- **Storage**: 50Gi with fast storage class preference
- **Services**: All available LocalStack services
- **Features**: Security context, monitoring, PDB
- **External Access**: All three service endpoints

## 🛠️ Advanced Features

### MetalLB Integration
- Automatic MetalLB installation if not present
- Dedicated IP address pools for LocalStack
- L2 Advertisement and optional BGP support
- Network interface detection and configuration

### AWS Resource Management
- Post-install job creates AWS resources automatically
- Configurable S3 buckets, SQS queues, SNS topics
- Application-specific resource sets included
- Helm hooks ensure proper initialization order

### Production Features
- **Horizontal Pod Autoscaler**: Scale based on CPU/memory
- **Pod Disruption Budget**: Maintain availability during updates
- **ServiceMonitor**: Prometheus metrics collection
- **Security Context**: Run as non-root user
- **Resource Limits**: Prevent resource exhaustion

### Monitoring and Observability
- Health check endpoints for probes
- Prometheus metrics via ServiceMonitor
- Comprehensive logging via kubectl logs
- Helm status and notes for deployment info

## 🔧 Customization Examples

### Network Configuration
```yaml
metallb:
  addressPool:
    addresses:
      - "10.0.1.100-10.0.1.110"  # Your network range
  l2Advertisement:
    interfaces:
      - "ens192"  # Your network interface
```

### Service Customization
```yaml
service:
  external:
    enabled: true
    loadBalancerIP: "10.0.1.100"  # Pin to specific IP
    annotations:
      metallb.universe.tf/loadBalancerIPs: "10.0.1.100,10.0.1.101"
```

### Resource Scaling
```yaml
localstack:
  resources:
    requests:
      memory: "2Gi"
      cpu: "1000m"
    limits:
      memory: "8Gi" 
      cpu: "4000m"

autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 3
```

### AWS Service Selection
```yaml
localstack:
  env:
    services: "s3,sqs,sns,dynamodb,lambda,apigateway,kinesis,secretsmanager"
```

## 🧪 Testing and Validation

### Chart Validation
```bash
./validate-chart.sh
```
- Runs helm lint
- Tests template rendering with all value files
- Validates required files exist
- Tests various configuration combinations
- Packages the chart

### Deployment Testing
```bash
# Dry run to test configuration
./deploy-helm.sh --environment dev --dry-run

# Test deployment with immediate cleanup
helm install test-localstack localstack/ -f localstack/values-dev.yaml --namespace test
# Test functionality...
helm uninstall test-localstack --namespace test
```

### Connectivity Testing
```bash
# Internal testing
kubectl run test --rm -i --tty --image=amazon/aws-cli:latest -n localstack -- /bin/bash
export AWS_ENDPOINT_URL=http://localstack-internal.localstack.svc.cluster.local:4566
aws s3 ls

# External testing (after getting LoadBalancer IP)
export AWS_ENDPOINT_URL=http://[EXTERNAL_IP]:4566
aws s3 ls
```

## 🔍 Troubleshooting Guide

### LoadBalancer IP Pending
1. Check MetalLB installation: `kubectl get pods -n metallb-system`
2. Verify IP address pool: `kubectl get ipaddresspools -n metallb-system`
3. Check network interface configuration
4. Verify IP range doesn't conflict with DHCP

### Deployment Issues
1. Check pod status: `kubectl get pods -n localstack`
2. View pod logs: `kubectl logs -l app.kubernetes.io/name=localstack -n localstack`
3. Describe problematic pods: `kubectl describe pod [POD_NAME] -n localstack`
4. Check persistent volume: `kubectl get pvc -n localstack`

### Initialization Job Failures
1. Check job status: `kubectl get jobs -n localstack`
2. View job logs: `kubectl logs job/localstack-init -n localstack`
3. Verify LocalStack is ready before job runs
4. Check AWS CLI configuration in init script

### Chart Template Issues
1. Run validation: `./validate-chart.sh`
2. Test rendering: `helm template test localstack/ --debug`
3. Check specific values: `helm template test localstack/ --set key=value --debug`

## 📊 Comparison: Helm vs Manual Deployment

| Feature | Manual Deployment | Helm Chart |
|---------|------------------|------------|
| **Deployment** | Multiple kubectl commands | Single command |
| **Configuration** | Multiple YAML files to edit | Values file configuration |
| **Environments** | Manual file management | Built-in dev/prod configs |
| **Upgrades** | Manual resource management | `helm upgrade` |
| **Rollbacks** | Manual state management | `helm rollback` |
| **Customization** | Direct YAML editing | Values override system |
| **Validation** | Manual testing | Built-in validation |
| **Documentation** | Separate documentation | Self-documenting via templates |

## 🎯 Integration with Applications

The Helm chart is specifically designed for development workflows:

### Service Integration
```yaml
# In your service deployments
env:
- name: AWS_ENDPOINT_URL
  value: "http://localstack-internal.localstack.svc.cluster.local:4566"
- name: AWS_ACCESS_KEY_ID
  value: "test"
- name: AWS_SECRET_ACCESS_KEY
  value: "test"
- name: AWS_DEFAULT_REGION
  value: "us-east-1"
```

### CI/CD Integration
```yaml
# Example CI values file
persistence:
  enabled: false  # Use emptyDir for CI
initJob:
  enabled: true
  resources:
    s3Buckets: ["ci-test-bucket"]
    sqsQueues: ["ci-test-queue"]
service:
  external:
    enabled: false  # Only internal access needed
  development:
    enabled: false
```

## 🎉 Benefits Summary

✅ **Easy Deployment**: One command deployment with environment selection  
✅ **Production Ready**: Includes HPA, PDB, monitoring, security contexts  
✅ **Network Flexible**: Works with any MetalLB network configuration  
✅ **Application Optimized**: Pre-configured for service integration  
✅ **Multi-Environment**: Development and production configurations included  
✅ **Maintainable**: Helm's upgrade/rollback capabilities  
✅ **Validated**: Built-in testing and validation scripts  
✅ **Documented**: Comprehensive documentation and examples  

This Helm chart provides enterprise-grade LocalStack deployment capabilities while maintaining the simplicity needed for development workflows.