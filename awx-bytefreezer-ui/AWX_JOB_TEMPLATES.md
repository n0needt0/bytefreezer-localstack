# AWX Job Templates for ByteFreezer UI Deployment

This document describes the AWX job templates needed to deploy ByteFreezer UI to your k3s cluster with proper connection to the ByteFreezer Control API.

## Prerequisites

1. **AWX Installation**: AWX server running and accessible
2. **k3s Cluster**: Running k3s cluster (v1.33.4+k3s1)
3. **MetalLB**: Configured with IP pool 192.168.86.101-192.168.86.120
4. **ByteFreezer Control API**: Running and accessible on port 8082
5. **Container Registry**: Access to push/pull container images

## Required AWX Setup

### 1. Project Configuration

**Name**: `ByteFreezer UI Deployment`
**Description**: `Automated deployment of ByteFreezer UI to k3s cluster`
**Organization**: `Default`
**SCM Type**: `Git`
**SCM URL**: `https://github.com/your-org/bytefreezer-awx-ui.git` (or local git repo)
**SCM Branch/Tag/Commit**: `main`
**Update Revision on Launch**: `✓`

### 2. Inventory Configuration

**Name**: `k3s-cluster`
**Description**: `ByteFreezer k3s cluster nodes`
**Organization**: `Default`
**Source**: Upload the `inventory/k3s-cluster.yml` file

### 3. Credentials Required

#### SSH Credential
- **Name**: `k3s-ssh-key`
- **Type**: `Machine`
- **Username**: `ubuntu` (or your SSH user)
- **SSH Private Key**: Your SSH private key for k3s nodes

#### Kubeconfig Credential
- **Name**: `k3s-kubeconfig`
- **Type**: `Kubernetes/OpenShift API Bearer Token`
- **Kubernetes/OpenShift API Endpoint**: `https://192.168.86.101:6443`
- **API Authentication Bearer Token**: Extract from your kubeconfig

#### Container Registry Credential
- **Name**: `docker-registry`
- **Type**: `Container Registry`
- **Authentication URL**: `docker.io` (or your registry)
- **Username**: Your registry username
- **Password**: Your registry password

## Job Templates

### Job Template 1: Build ByteFreezer UI Container

**Name**: `ByteFreezer UI - Build Container`
**Description**: `Build and push ByteFreezer UI container image`
**Job Type**: `Run`
**Inventory**: `k3s-cluster`
**Project**: `ByteFreezer UI Deployment`
**Playbook**: `playbooks/build-ui.yml`
**Credentials**:
- `docker-registry`
- `k3s-ssh-key`

**Variables**:
```yaml
container_registry: "docker.io/your-username"
ui_version: "1.0.0"
ui_git_repo: "https://github.com/your-org/bytefreezer-ui.git"
ui_git_branch: "main"
cleanup_build_artifacts: true
```

**Options**:
- ✓ Prompt on Launch (for ui_version)
- ✓ Enable Concurrent Jobs

---

### Job Template 2: Deploy ByteFreezer UI to k3s

**Name**: `ByteFreezer UI - Deploy to k3s`
**Description**: `Deploy ByteFreezer UI to k3s cluster with Control API integration`
**Job Type**: `Run`
**Inventory**: `k3s-cluster`
**Project**: `ByteFreezer UI Deployment`
**Playbook**: `playbooks/deploy-ui.yml`
**Credentials**:
- `k3s-kubeconfig`
- `k3s-ssh-key`

**Variables**:
```yaml
# Container configuration
container_registry: "docker.io/your-username"
ui_version: "1.0.0"
ui_replicas: 2

# ByteFreezer Control API connection - UPDATE THESE IPs
bytefreezer_control_service_ip: "192.168.86.109"
bytefreezer_receiver_service_ip: "192.168.86.110"
bytefreezer_piper_service_ip: "192.168.86.111"
bytefreezer_packer_service_ip: "192.168.86.112"

# UI external access via MetalLB
ui_external_ip: "192.168.86.113"
ui_hostname: "bytefreezer-ui.local"

# Security (use AWX secrets/vault)
jwt_secret: "{{ vault_jwt_secret }}"
nextauth_secret: "{{ vault_nextauth_secret }}"

# Optional features
create_ingress: false
```

**Options**:
- ✓ Prompt on Launch (for service IPs and ui_version)
- ✓ Enable Concurrent Jobs

---

### Job Template 3: Update UI Configuration

**Name**: `ByteFreezer UI - Update Configuration`
**Description**: `Update ByteFreezer UI configuration and restart pods`
**Job Type**: `Run`
**Inventory**: `k3s-cluster`
**Project**: `ByteFreezer UI Deployment`
**Playbook**: `playbooks/update-config.yml`
**Credentials**:
- `k3s-kubeconfig`

**Variables**:
```yaml
# Updated ByteFreezer service IPs
bytefreezer_control_service_ip: "192.168.86.109"
bytefreezer_receiver_service_ip: "192.168.86.110"
bytefreezer_piper_service_ip: "192.168.86.111"
bytefreezer_packer_service_ip: "192.168.86.112"

# UI configuration
ui_external_ip: "192.168.86.113"
ui_hostname: "bytefreezer-ui.local"
```

**Options**:
- ✓ Prompt on Launch (for all service IPs)
- ✓ Enable Concurrent Jobs

## Workflow Template (Optional)

**Name**: `ByteFreezer UI - Full Deployment`
**Description**: `Complete build and deployment workflow`

**Workflow Steps**:
1. `ByteFreezer UI - Build Container`
2. `ByteFreezer UI - Deploy to k3s` (on success)

## Usage Instructions

### Initial Deployment
1. Run `ByteFreezer UI - Build Container` job template
2. Wait for container build to complete
3. Run `ByteFreezer UI - Deploy to k3s` job template
4. Access UI at: `http://192.168.86.113:3000`

### Configuration Updates
1. Run `ByteFreezer UI - Update Configuration` with new service IPs
2. Pods will restart automatically with new configuration

### Version Updates
1. Update `ui_version` variable
2. Run `ByteFreezer UI - Build Container` with new version
3. Run `ByteFreezer UI - Deploy to k3s` with new version

## Post-Deployment Verification

After successful deployment, verify:

1. **UI Accessibility**: `http://192.168.86.113:3000`
2. **Control API Connection**: Check logs for successful API calls
3. **MetalLB Assignment**: Verify external IP is assigned
4. **Pod Health**: All pods running and ready

## Troubleshooting

### Common Issues

1. **No External IP**: Check MetalLB configuration and IP pool
2. **Control API Connection Failed**: Verify Control API service IP and port
3. **Build Failures**: Check container registry credentials
4. **Pod CrashLoopBackOff**: Check environment variables and secrets

### Debug Commands

```bash
# Check UI pods
kubectl get pods -n bytefreezer-ui

# Check service external IP
kubectl get svc -n bytefreezer-ui

# Check UI logs
kubectl logs -n bytefreezer-ui deployment/bytefreezer-ui

# Test Control API connectivity
curl http://192.168.86.109:8082/api/v1/system/health
```

## Security Notes

1. Store sensitive variables (JWT secrets) in AWX Vault
2. Use RBAC to limit access to job templates
3. Enable audit logging for all deployments
4. Rotate secrets regularly using update configuration job

## Customization

### Adding New Environment Variables
1. Update `k8s/configmap.yaml` template
2. Add variables to `deploy-ui.yml` playbook
3. Update job template variables

### Changing Resource Limits
1. Modify `k8s/deployment.yaml` resource requests/limits
2. Update variables in deployment playbook

### SSL/TLS Configuration
1. Uncomment TLS section in `k8s/ingress.yaml`
2. Add SSL certificate management to playbooks