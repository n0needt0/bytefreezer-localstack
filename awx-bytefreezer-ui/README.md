# ByteFreezer UI - AWX Deployment Automation

This project provides complete AWX automation for deploying the ByteFreezer UI to a k3s cluster with proper integration to the ByteFreezer Control API.

## Overview

The ByteFreezer UI is a Next.js dashboard that connects to the ByteFreezer Control API (port 8082) to provide:
- Tenant management
- Dataset monitoring
- System health dashboard
- Real-time metrics

This AWX automation handles:
- ✅ Container image building and registry push
- ✅ Kubernetes deployment to k3s cluster
- ✅ MetalLB LoadBalancer configuration
- ✅ ByteFreezer Control API integration
- ✅ Configuration updates and rolling restarts

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   AWX Server    │    │   k3s Cluster    │    │ ByteFreezer     │
│                 │    │                  │    │ Control API     │
│ ┌─────────────┐ │    │ ┌──────────────┐ │    │                 │
│ │ Build UI    │─┼────┼─│ UI Pods      │ │    │ Port 8082       │
│ │ Container   │ │    │ │              │ │    │                 │
│ └─────────────┘ │    │ └──────────────┘ │    │                 │
│                 │    │                  │    │                 │
│ ┌─────────────┐ │    │ ┌──────────────┐ │    │                 │
│ │ Deploy to   │─┼────┼─│ MetalLB      │─┼────┼─ API Calls      │
│ │ k3s         │ │    │ │ External IP  │ │    │                 │
│ └─────────────┘ │    │ └──────────────┘ │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                 │
                          ┌─────────────────┐
                          │ User Browser    │
                          │ 192.168.86.113  │
                          │ Port 3000       │
                          └─────────────────┘
```

## Quick Start

### 1. Prerequisites
- AWX server installed and running
- k3s cluster with MetalLB (IP pool: 192.168.86.101-192.168.86.120)
- ByteFreezer Control API running on port 8082
- Container registry access (Docker Hub, Harbor, etc.)

### 2. Import Project to AWX
1. Create new Project in AWX
2. Set SCM URL to this repository
3. Import inventory from `inventory/k3s-cluster.yml`
4. Configure credentials (SSH, kubeconfig, registry)

### 3. Update Configuration
Edit `inventory/k3s-cluster.yml` with your actual IPs:
```yaml
# Update these to match your ByteFreezer services
bytefreezer_control_service_ip: "192.168.86.109"  # Your Control API IP
bytefreezer_receiver_service_ip: "192.168.86.110" # Your Receiver IP
bytefreezer_piper_service_ip: "192.168.86.111"    # Your Piper IP
bytefreezer_packer_service_ip: "192.168.86.112"   # Your Packer IP
ui_external_ip: "192.168.86.113"                  # Available MetalLB IP
```

### 4. Deploy
1. Run `ByteFreezer UI - Build Container` job template
2. Run `ByteFreezer UI - Deploy to k3s` job template
3. Access UI at: `http://192.168.86.113:3000`

## Project Structure

```
awx-bytefreezer-ui/
├── playbooks/                 # AWX Ansible playbooks
│   ├── build-ui.yml          # Build and push container
│   ├── deploy-ui.yml         # Deploy to k3s
│   └── update-config.yml     # Update configuration
├── k8s/                      # Kubernetes manifests
│   ├── namespace.yaml        # Namespace definition
│   ├── configmap.yaml        # ConfigMap with Control API config
│   ├── deployment.yaml       # UI deployment
│   ├── service.yaml          # LoadBalancer service
│   └── ingress.yaml          # Optional ingress
├── templates/                # Configuration templates
│   ├── Dockerfile.j2         # Multi-stage Docker build
│   └── .env.production.j2    # Production environment
├── inventory/                # AWX inventory
│   └── k3s-cluster.yml      # k3s cluster definition
├── AWX_JOB_TEMPLATES.md     # AWX setup instructions
└── README.md                # This file
```

## Key Features

### ByteFreezer Control API Integration
- Configures UI to connect to Control API on port 8082
- Supports dynamic service IP configuration
- Includes health checks and connectivity testing

### k3s Deployment
- Uses MetalLB for external IP assignment
- Implements rolling updates with zero downtime
- Configures resource limits and security contexts

### Container Management
- Multi-stage Docker build for optimized images
- Automated registry push/pull
- Version tagging and latest updates

### AWX Automation
- Three job templates for complete lifecycle management
- Inventory-based configuration management
- Credential management for security

## Configuration

### Environment Variables
The UI is configured via Kubernetes ConfigMap with these key variables:

```yaml
# ByteFreezer Control API connection
NEXT_PUBLIC_API_BASE_URL: "http://192.168.86.109:8082"

# Other ByteFreezer services
NEXT_PUBLIC_RECEIVER_URL: "http://192.168.86.110:8080"
NEXT_PUBLIC_PIPER_URL: "http://192.168.86.111:8083"
NEXT_PUBLIC_PACKER_URL: "http://192.168.86.112:8084"

# Security
NEXT_PUBLIC_JWT_SECRET: "secure-jwt-secret"
NEXTAUTH_SECRET: "secure-nextauth-secret"
```

### Service IPs
Update these in your AWX inventory to match your actual services:
- **Control API**: Default 192.168.86.109:8082
- **Receiver**: Default 192.168.86.110:8080
- **Piper**: Default 192.168.86.111:8083
- **Packer**: Default 192.168.86.112:8084
- **UI External IP**: Default 192.168.86.113:3000

## Job Templates

### 1. Build Container (`build-ui.yml`)
- Clones UI source code
- Builds production Next.js bundle
- Creates optimized Docker image
- Pushes to container registry

### 2. Deploy to k3s (`deploy-ui.yml`)
- Creates namespace and configurations
- Deploys UI pods with Control API integration
- Sets up LoadBalancer service with MetalLB
- Performs health checks and connectivity tests

### 3. Update Configuration (`update-config.yml`)
- Updates ConfigMap with new service IPs
- Performs rolling restart of UI pods
- Verifies Control API connectivity
- Tests UI health after update

## Usage Scenarios

### Initial Deployment
```bash
# 1. Build and push container image
AWX Job: "ByteFreezer UI - Build Container"

# 2. Deploy to k3s cluster
AWX Job: "ByteFreezer UI - Deploy to k3s"

# 3. Access UI
Browser: http://192.168.86.113:3000
```

### Service IP Updates
```bash
# Update Control API IP in AWX inventory
# Run configuration update
AWX Job: "ByteFreezer UI - Update Configuration"
```

### Version Updates
```bash
# Update ui_version variable in AWX
# Build new container
AWX Job: "ByteFreezer UI - Build Container" (new version)

# Deploy new version
AWX Job: "ByteFreezer UI - Deploy to k3s" (new version)
```

## Monitoring & Troubleshooting

### Health Checks
- UI pods include liveness/readiness probes
- Control API connectivity is tested during deployment
- External IP assignment is verified

### Common Issues
1. **No External IP**: Check MetalLB configuration
2. **Control API Connection Failed**: Verify service IP and port
3. **Build Failures**: Check container registry credentials
4. **Pod Crashes**: Check environment variables and logs

### Debug Commands
```bash
# Check UI deployment
kubectl get pods -n bytefreezer-ui
kubectl get svc -n bytefreezer-ui

# Check UI logs
kubectl logs -n bytefreezer-ui deployment/bytefreezer-ui

# Test Control API
curl http://192.168.86.109:8082/api/v1/system/health
```

## Security

### Secrets Management
- JWT secrets stored in Kubernetes secrets
- AWX vault integration for sensitive variables
- Container registry credentials managed by AWX

### Network Security
- Pods run as non-root user
- Read-only root filesystem (where possible)
- Security contexts enforce least privilege

### Access Control
- AWX RBAC for job template access
- Kubernetes namespace isolation
- Service account with minimal permissions

## Customization

### Adding New Services
1. Add service IP variable to inventory
2. Update ConfigMap template with new environment variable
3. Modify deployment playbook to include new configuration

### Resource Scaling
1. Update `ui_replicas` variable in inventory
2. Modify resource requests/limits in deployment manifest
3. Re-run deployment job template

### SSL/TLS
1. Enable ingress in deployment variables
2. Configure SSL certificates in ingress manifest
3. Update NEXTAUTH_URL to use HTTPS

## Support

For issues with:
- **AWX Setup**: See `AWX_JOB_TEMPLATES.md`
- **k3s Deployment**: Check Kubernetes manifests in `k8s/`
- **Control API Integration**: Verify service IPs and connectivity
- **Container Building**: Check Dockerfile and build playbook

## License

© 2024 ByteFreezer. All rights reserved.