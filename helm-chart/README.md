# LocalStack Helm Chart

A comprehensive Helm chart for deploying LocalStack AWS services emulator on Kubernetes with MetalLB integration for both internal and external access.

## 🎯 Features

- **Full LocalStack deployment** with persistent storage
- **MetalLB integration** for LoadBalancer services
- **Multi-environment support** (dev, prod, custom)
- **Automatic AWS resource initialization** (S3, SQS, SNS)
- **Three service endpoints**: internal, external, development
- **Production-ready features**: HPA, PDB, ServiceMonitor
- **Flexible configuration** via values files

## 🚀 Quick Start

### Prerequisites
- Kubernetes cluster (K3s recommended)
- Helm 3.x installed
- kubectl configured

### Basic Deployment

```bash
# Deploy with default settings
./deploy-helm.sh

# Deploy for development
./deploy-helm.sh --environment dev

# Deploy for production
./deploy-helm.sh --environment prod
```

### Custom Deployment

```bash
# Use custom values file
./deploy-helm.sh --environment my-values.yaml

# Custom release name and namespace
./deploy-helm.sh --environment prod --name my-localstack --namespace my-namespace

# Dry run to test configuration
./deploy-helm.sh --environment dev --dry-run

# Upgrade existing deployment
./deploy-helm.sh --environment prod --upgrade
```

## 📦 Chart Structure

```
localstack/
├── Chart.yaml                 # Chart metadata
├── values.yaml                # Default values
├── values-dev.yaml            # Development environment
├── values-prod.yaml           # Production environment
└── templates/
    ├── deployment.yaml        # LocalStack deployment
    ├── services.yaml          # Three service types
    ├── pvc.yaml              # Persistent volume claim
    ├── configmap.yaml        # Configuration and init scripts
    ├── init-job.yaml         # AWS resource initialization
    ├── metallb.yaml          # MetalLB configuration
    ├── hpa.yaml              # Horizontal Pod Autoscaler
    ├── pod-disruption-budget.yaml
    ├── servicemonitor.yaml   # Prometheus monitoring
    └── _helpers.tpl          # Template helpers
```

## ⚙️ Configuration

### Network Configuration

Edit the MetalLB settings in your values file:

```yaml
metallb:
  addressPool:
    addresses:
      - "192.168.1.240-192.168.1.249"  # Your IP range
  l2Advertisement:
    interfaces:
      - "eth0"  # Your network interface
```

### Service Configuration

Three service types are available:

```yaml
service:
  # Internal cluster access
  internal:
    enabled: true
    type: ClusterIP
    ports:
      edge: 4566
      admin: 4510
  
  # External production access
  external:
    enabled: true
    type: LoadBalancer
    ports:
      edge: 4566
      admin: 4510
  
  # Development external access
  development:
    enabled: true
    type: LoadBalancer
    ports:
      edge: 4567
      admin: 4511
```

### Resource Initialization

Configure AWS resources to create automatically:

```yaml
initJob:
  resources:
    s3Buckets:
      - "my-data-bucket"
      - "my-config-bucket"
    sqsQueues:
      - "my-event-queue"
    snsTopics:
      - "my-alert-topic"
```

## 🌍 Environment Configurations

### Development (`values-dev.yaml`)
- **Reduced resources**: 256Mi memory, 100m CPU
- **Limited services**: S3, SQS, SNS, DynamoDB, Lambda, IAM
- **Smaller storage**: 5Gi
- **Simple setup**: Only internal + development LoadBalancer
- **Basic resources**: dev-* prefixed AWS resources

### Production (`values-prod.yaml`)
- **Full resources**: 1Gi memory, 500m CPU (up to 4Gi/2CPU)
- **All services**: Complete LocalStack service set
- **Large storage**: 50Gi with fast storage class
- **All endpoints**: Internal + both LoadBalancers
- **Full resources**: Complete application resource set
- **Production features**: Security context, monitoring

### Custom Values
Create your own values file based on `values.yaml` and pass it:

```bash
./deploy-helm.sh --environment my-custom-values.yaml
```

## 📋 Access Information

After deployment, get connection details:

```bash
# Check services
kubectl get svc -n localstack

# Get LoadBalancer IPs
kubectl get svc localstack-external -n localstack -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Internal Access (Cluster)
```bash
AWS_ENDPOINT_URL=http://localstack-internal.localstack.svc.cluster.local:4566
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=us-east-1
```

### External Access (LoadBalancer)
```bash
AWS_ENDPOINT_URL=http://[EXTERNAL_IP]:4566
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=us-east-1
```

## 🛠️ Management Commands

### Deployment
```bash
# Install/Deploy
./deploy-helm.sh --environment prod

# Upgrade
./deploy-helm.sh --environment prod --upgrade

# Dry run
./deploy-helm.sh --environment dev --dry-run
```

### Monitoring
```bash
# Check status
helm status localstack -n localstack

# View logs
kubectl logs -f deployment/localstack -n localstack

# Check services
kubectl get all -n localstack
```

### Uninstall
```bash
# Remove LocalStack
./deploy-helm.sh --uninstall

# Or manually
helm uninstall localstack -n localstack
kubectl delete namespace localstack
```

## 🔧 Advanced Configuration

### Security Context
```yaml
securityContext:
  enabled: true
  runAsUser: 1000
  runAsGroup: 1000
  fsGroup: 1000
```

### Resource Limits
```yaml
localstack:
  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "2Gi"
      cpu: "1000m"
```

### Node Placement
```yaml
nodeSelector:
  node-type: "localstack"

tolerations:
  - key: "localstack"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"
```

### Monitoring
```yaml
serviceMonitor:
  enabled: true
  interval: 30s
  scrapeTimeout: 10s
```

## 🧪 Testing

### Test Internal Access
```bash
kubectl run test --rm -i --tty --image=amazon/aws-cli:latest -n localstack -- /bin/bash

# Inside pod:
export AWS_ENDPOINT_URL=http://localstack-internal.localstack.svc.cluster.local:4566
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=us-east-1
aws s3 ls
```

### Test External Access
```bash
# Get external IP
EXTERNAL_IP=$(kubectl get svc localstack-external -n localstack -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test from outside cluster
export AWS_ENDPOINT_URL=http://$EXTERNAL_IP:4566
aws s3 ls --endpoint-url=$AWS_ENDPOINT_URL
```

## 📊 Troubleshooting

### LoadBalancer IP Pending
```bash
# Check MetalLB
kubectl get pods -n metallb-system
kubectl get ipaddresspools -n metallb-system

# Check service events
kubectl describe svc localstack-external -n localstack
```

### Deployment Issues
```bash
# Check pods
kubectl get pods -n localstack
kubectl describe pod -l app.kubernetes.io/name=localstack -n localstack

# Check logs
kubectl logs -l app.kubernetes.io/name=localstack -n localstack
```

### Network Issues
- Verify MetalLB IP range doesn't conflict with DHCP
- Ensure network interface name is correct
- Check firewall rules for LoadBalancer IPs

## 🎯 Integration with Applications

This chart is designed for development environments. Use the appropriate environment configuration:

- **Development**: `--environment dev` for lightweight local development
- **Production**: `--environment prod` for full-featured testing
- **CI/CD**: Custom values with specific resource limits

All services can connect using the internal service endpoint for optimal performance within the cluster.

## 📚 Helm Chart Values Reference

See `values.yaml` for complete configuration options with detailed comments.

Key sections:
- `localstack.*` - LocalStack container configuration
- `service.*` - Service endpoint configuration  
- `metallb.*` - MetalLB LoadBalancer configuration
- `persistence.*` - Storage configuration
- `initJob.*` - AWS resource initialization
- Production features: `autoscaling`, `podDisruptionBudget`, `serviceMonitor`