# LocalStack on K3s/K8s

Deploy AWS LocalStack on Kubernetes (K3s/K8s) with MetalLB LoadBalancer integration. Provides local AWS service emulation for development and testing.

## 🎯 What This Provides

LocalStack emulates AWS services locally, providing:
- **S3**: Object storage buckets
- **SQS**: Message queues and dead letter queues
- **SNS**: Pub/sub topics and notifications
- **DynamoDB**: NoSQL database tables
- **Lambda**: Serverless function execution
- **IAM**: Identity and access management
- **Secrets Manager**: Secure credential storage
- **Systems Manager**: Parameter store and configuration

## 🚀 Quick Start

### Prerequisites
- K3s cluster running
- `kubectl` configured to access your cluster
- MetalLB installed (script will install if not present)
- Network IP range available for MetalLB pool

### Deploy LocalStack

```bash
# Deploy LocalStack to K3s with MetalLB
./deploy.sh
```

This will:
1. Install MetalLB if not present
2. Configure MetalLB IP address pools (you'll need to edit network settings)
3. Create the `localstack` namespace
4. Deploy LocalStack with persistent storage
5. Set up internal ClusterIP and external LoadBalancer services
6. Initialize example AWS resources
7. Display connection information with LoadBalancer IPs

### Remove LocalStack

```bash
# Remove LocalStack from K3s
./undeploy.sh
```

## 📋 Access Information

### Internal Access (from within cluster)
```
AWS_ENDPOINT_URL=http://localstack-internal.localstack.svc.cluster.local:4566
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=us-east-1
```

### External Access (from outside cluster via MetalLB)
```bash
# Get LoadBalancer IPs
kubectl get svc -n localstack

# Production LoadBalancer
AWS_ENDPOINT_URL=http://[EXTERNAL_IP]:4566
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=us-east-1

# Development LoadBalancer (alternative ports)
AWS_ENDPOINT_URL=http://[DEV_IP]:4567
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=us-east-1
```

### Admin UI
- Production: `http://[EXTERNAL_IP]:4510`
- Development: `http://[DEV_IP]:4511`

## 🌐 MetalLB Configuration

### Network Setup
Before deploying, edit `metallb-config.yaml` to match your network:

```yaml
spec:
  addresses:
  - 192.168.1.240-192.168.1.249  # Change to your available IP range
```

### Service Types
This deployment creates three service types:
- `localstack-internal`: ClusterIP for internal cluster access
- `localstack-external`: LoadBalancer for production external access (ports 4566, 4510)  
- `localstack-dev`: LoadBalancer for development external access (ports 4567, 4511)

### IP Pool Management
- Uses dedicated `localstack-pool` IP address pool
- L2 Advertisement for layer 2 networking
- Supports BGP mode (commented configuration available)

## 🎯 Pre-Created Resources

The deployment automatically creates example AWS resources:

### S3 Buckets
- `app-data` - Application data storage
- `app-config` - Configuration files
- `app-logs` - Log storage
- `app-artifacts` - Build artifacts and packages

### SQS Queues
- `app-events` - Event processing queue
- `app-dlq` - Dead letter queue for failed messages
- `app-processing` - Data processing pipeline queue

### SNS Topics
- `app-alerts` - System alerts and monitoring
- `app-notifications` - User notifications

## 🔧 Using LocalStack in Your Services

### Environment Variables
Add these environment variables to your application deployments:

```yaml
env:
- name: AWS_ENDPOINT_URL
  value: "http://localstack.localstack.svc.cluster.local:4566"
- name: AWS_ACCESS_KEY_ID
  value: "test"
- name: AWS_SECRET_ACCESS_KEY
  value: "test"
- name: AWS_DEFAULT_REGION
  value: "us-east-1"
- name: AWS_DISABLE_SSL
  value: "true"
```

### Go Applications
```go
import (
    "github.com/aws/aws-sdk-go/aws"
    "github.com/aws/aws-sdk-go/aws/credentials"
    "github.com/aws/aws-sdk-go/aws/session"
)

sess := session.Must(session.NewSession(&aws.Config{
    Region:           aws.String("us-east-1"),
    Endpoint:         aws.String("http://localstack.localstack.svc.cluster.local:4566"),
    Credentials:      credentials.NewStaticCredentials("test", "test", ""),
    DisableSSL:       aws.Bool(true),
    S3ForcePathStyle: aws.Bool(true), // Required for S3
}))
```

### Python Applications
```python
import boto3

client = boto3.client(
    's3',
    endpoint_url='http://localstack.localstack.svc.cluster.local:4566',
    aws_access_key_id='test',
    aws_secret_access_key='test',
    region_name='us-east-1'
)
```

## 🧪 Testing LocalStack

### From within the cluster
```bash
kubectl run aws-cli --rm -i --tty --image=amazon/aws-cli:latest -- /bin/bash

# Inside the pod:
export AWS_ENDPOINT_URL=http://localstack.localstack.svc.cluster.local:4566
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# Test S3
aws s3 ls
aws s3 cp /etc/hostname s3://app-data/test.txt
aws s3 ls s3://app-data/

# Test SQS
aws sqs list-queues
aws sqs send-message --queue-url http://localstack.localstack.svc.cluster.local:4566/000000000000/app-events --message-body "Test message"

# Test SNS
aws sns list-topics
aws sns publish --topic-arn arn:aws:sns:us-east-1:000000000000:app-alerts --message "Test alert"
```

### From outside the cluster (replace NODE_IP)
```bash
export AWS_ENDPOINT_URL=http://[NODE_IP]:30566
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

aws s3 ls
```

## 📊 Monitoring LocalStack

### Check deployment status
```bash
kubectl get all -n localstack
```

### View logs
```bash
kubectl logs -f deployment/localstack -n localstack
```

### Check health
```bash
curl http://[NODE_IP]:30566/_localstack/health
```

## ⚙️ Configuration

### Persistent Storage
- LocalStack data is persisted using K3s local-path storage class
- Storage size: 10GB (configurable in `pvc.yaml`)
- Data survives pod restarts but not cluster rebuilds

### Resource Limits
- Memory: 512Mi request, 2Gi limit
- CPU: 250m request, 1000m limit
- Adjust in `deployment.yaml` based on your cluster capacity

### Services Enabled
Current configuration enables: S3, SQS, SNS, DynamoDB, Lambda, CloudFormation, IAM, Secrets Manager, SSM

To modify services, edit the `SERVICES` environment variable in `deployment.yaml`.

## 🔍 Troubleshooting

### Pod fails to start
```bash
kubectl describe pod -l app=localstack -n localstack
kubectl logs -l app=localstack -n localstack
```

### Initialization job fails
```bash
kubectl logs job/localstack-init -n localstack
```

### Cannot access from services
- Verify the service DNS: `kubectl get svc -n localstack`
- Test connectivity: `kubectl run test --rm -i --tty --image=busybox -- nslookup localstack.localstack.svc.cluster.local`

### External access issues
- Check NodePort services: `kubectl get svc localstack-external -n localstack`
- Verify node IP: `kubectl get nodes -o wide`
- Ensure firewall allows ports 30566 and 30510

## 🚀 Integration with Applications

This LocalStack deployment provides a consistent, shared AWS environment for your applications:

- **Data Storage**: S3 buckets for files, configurations, and logs
- **Message Processing**: SQS queues for asynchronous processing and DLQ
- **Notifications**: SNS topics for pub/sub messaging and alerts
- **Database**: DynamoDB for NoSQL data storage
- **Security**: IAM, Secrets Manager for credentials and access control
- **Configuration**: Systems Manager for parameter storage

All applications can use the same LocalStack instance with the environment variables listed above, providing a unified development environment that closely mirrors production AWS services.

## 📚 Additional Resources

- [LocalStack Documentation](https://docs.localstack.cloud/)
- [AWS CLI with LocalStack](https://docs.localstack.cloud/integrations/aws-cli/)
- [LocalStack Pro Features](https://docs.localstack.cloud/getting-started/pro/)