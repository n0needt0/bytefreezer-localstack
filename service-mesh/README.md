# ByteFreezer Service Mesh with Istio

Complete Istio service mesh setup for ByteFreezer microservices with LocalStack integration.

## 🌐 **What This Provides**

### **Service Mesh Benefits**
- **Traffic Management**: Intelligent routing, load balancing, circuit breakers
- **Security**: mTLS, authentication, authorization policies
- **Observability**: Distributed tracing, metrics, service topology
- **Resilience**: Fault injection, retries, timeouts
- **Canary Deployments**: A/B testing and gradual rollouts

### **ByteFreezer Integration**
- **LocalStack Routing**: Route external AWS calls to LocalStack
- **Service Communication**: Secure inter-service communication
- **External Access**: Gateway for external service access
- **Development Tools**: Integrated observability stack

## 🚀 **Quick Start**

### **1. Install Istio**
```bash
cd service-mesh
./scripts/install-istio.sh
```

This installs:
- ✅ **Istio Control Plane** (istiod)
- ✅ **Kiali Dashboard** (Service mesh visualization)
- ✅ **Jaeger** (Distributed tracing)
- ✅ **Prometheus** (Metrics collection)
- ✅ **Grafana** (Metrics visualization)
- ✅ **Sidecar Injection** (Enabled for key namespaces)

### **2. Configure Service Mesh**
```bash
./scripts/configure-mesh.sh
```

This applies:
- ✅ **Gateways** for external access
- ✅ **Virtual Services** for traffic routing
- ✅ **Destination Rules** for load balancing
- ✅ **Security Policies** for authentication/authorization
- ✅ **Observability Configuration** for monitoring

### **3. Access Dashboards**
```bash
# Kiali (Service mesh dashboard)
kubectl port-forward svc/kiali 20001:20001 -n istio-system
# Visit: http://localhost:20001

# Jaeger (Distributed tracing)
kubectl port-forward svc/jaeger 16686:16686 -n istio-system  
# Visit: http://localhost:16686

# Grafana (Metrics visualization)
kubectl port-forward svc/grafana 3000:3000 -n istio-system
# Visit: http://localhost:3000
```

## 🌐 **Service Mesh Architecture**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Istio Gateway │───▶│  ByteFreezer    │───▶│   LocalStack    │
│                 │    │    Services     │    │                 │
│ • External      │    │ • Proxy         │    │ • S3, SQS, SNS  │
│ • Load Balancer │    │ • Receiver      │    │ • Lambda, IAM   │
│ • TLS           │    │ • Piper         │    │ • DynamoDB      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Observability │    │  Traffic Mgmt   │    │    Security     │
│                 │    │                 │    │                 │
│ • Kiali         │    │ • Load Balance  │    │ • mTLS          │
│ • Jaeger        │    │ • Circuit Break │    │ • AuthZ/AuthN   │
│ • Grafana       │    │ • Retries       │    │ • Network Pol   │
│ • Prometheus    │    │ • Canary Deploy │    │ • Rate Limiting │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🔧 **Configuration Overview**

### **Gateways (`gateway.yaml`)**
- **Development Gateway**: Access services via `*.dev.bytefreezer.local`
- **Production Gateway**: HTTPS access via `*.prod.bytefreezer.local`
- **Service Ports**: LocalStack (4566), Proxy (8080), Receiver (3000), Piper (4000)

### **Virtual Services (`virtual-services.yaml`)**
- **LocalStack**: Route AWS API calls to LocalStack
- **ByteFreezer Services**: HTTP routing with path-based matching
- **AWS Mock**: Route `*.amazonaws.com` to LocalStack
- **Timeouts**: Service-specific timeout configurations

### **Destination Rules (`destination-rules.yaml`)**
- **Connection Pooling**: Service-specific connection limits
- **Load Balancing**: Round-robin, least-request, random strategies
- **Circuit Breaking**: Outlier detection and ejection
- **Retry Policies**: Automatic retry with backoff

### **Security Policies (`security-policies.yaml`)**
- **mTLS**: Permissive mode for development
- **Authorization**: Namespace and service-based access control
- **Network Policies**: Additional K8s network security
- **Service Accounts**: Identity-based authorization

### **Traffic Management (`traffic-management.yaml`)**
- **Canary Deployments**: Gradual traffic shifting (10% v2, 90% v1)
- **Fault Injection**: Chaos testing with delays and errors
- **Rate Limiting**: Request rate control
- **Session Affinity**: Consistent hash load balancing

## 🎯 **Development Workflows**

### **LocalStack Integration**
```yaml
# All AWS calls automatically routed to LocalStack
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
spec:
  hosts:
  - "*.amazonaws.com"
  route:
  - destination:
      host: localstack-internal.localstack.svc.cluster.local
      port: 4566
```

### **Service Communication**
```bash
# Internal service calls use service mesh
curl http://bytefreezer-receiver.bytefreezer-dev.svc.cluster.local/data

# External calls go through gateway  
curl http://receiver.dev.bytefreezer.local/data
```

### **Canary Deployments**
```bash
# Deploy new version with v2 label
kubectl set image deployment/bytefreezer-proxy proxy=bytefreezer/proxy:v2 -n bytefreezer-dev
kubectl patch deployment bytefreezer-proxy -p '{"spec":{"template":{"metadata":{"labels":{"version":"v2"}}}}}' -n bytefreezer-dev

# Traffic automatically splits 90% v1, 10% v2
# Monitor in Kiali dashboard
```

### **Chaos Testing**
```bash
# Inject faults with header
curl -H "x-chaos-test: true" http://receiver.dev.bytefreezer.local/data
# 50% chance of 2s delay, 10% chance of 503 error
```

## 📊 **Observability Features**

### **Kiali Dashboard**
- **Service Topology**: Visual service mesh map
- **Traffic Flow**: Real-time request flow visualization  
- **Performance Metrics**: Success rates, response times
- **Configuration Validation**: Istio config validation

### **Jaeger Tracing**
- **Distributed Tracing**: End-to-end request tracking
- **Service Dependencies**: Service call chains
- **Performance Analysis**: Latency breakdown
- **Error Tracking**: Failed request investigation

### **Grafana Dashboards**
- **Service Metrics**: Request rates, error rates, durations
- **Infrastructure Metrics**: CPU, memory, network
- **Custom Dashboards**: ByteFreezer-specific metrics
- **Alerts**: Automated alerting rules

### **Prometheus Metrics**
- **Istio Metrics**: Service mesh performance data
- **Custom Metrics**: Application-specific metrics
- **Alerting**: Prometheus alerting rules
- **Federation**: Multi-cluster metric collection

## 🛠️ **Management Commands**

### **Status and Monitoring**
```bash
# Check Istio installation
istioctl version

# Check proxy status
istioctl proxy-status

# Check configuration
istioctl proxy-config cluster [POD_NAME] -n [NAMESPACE]

# Validate configuration
istioctl analyze

# Check mesh status
kubectl get pods -n istio-system
```

### **Traffic Management**
```bash
# View traffic policies
kubectl get virtualservices,destinationrules -A

# Check gateway configuration
kubectl get gateway -A

# Monitor traffic in Kiali
kubectl port-forward svc/kiali 20001:20001 -n istio-system
```

### **Debugging**
```bash
# Check sidecar logs
kubectl logs [POD_NAME] -c istio-proxy -n [NAMESPACE]

# Check Istio configuration
istioctl proxy-config listeners [POD_NAME] -n [NAMESPACE]

# Validate mesh configuration
istioctl analyze -n [NAMESPACE]
```

## 🔍 **Troubleshooting**

### **Common Issues**

#### **Services Not Accessible**
1. Check sidecar injection: `kubectl get pods -o wide`
2. Verify virtual service: `kubectl get virtualservices`
3. Check gateway configuration: `kubectl get gateway`

#### **mTLS Issues** 
1. Check peer authentication: `kubectl get peerauthentication`
2. Verify certificates: `istioctl authn tls-check [POD_NAME]`
3. Check authorization policies: `kubectl get authorizationpolicy`

#### **Traffic Not Routing**
1. Check destination rules: `kubectl get destinationrules`
2. Verify service labels match selectors
3. Check Kiali for traffic flow visualization

#### **Performance Issues**
1. Check connection pool settings in destination rules
2. Monitor metrics in Grafana
3. Review circuit breaker configurations
4. Analyze traces in Jaeger

## 🎯 **Integration with ByteFreezer**

### **Service Environment Variables**
Your ByteFreezer services automatically benefit from:
```yaml
env:
# LocalStack access remains the same
- name: AWS_ENDPOINT_URL
  value: "http://localstack-internal.localstack.svc.cluster.local:4566"
  
# Service mesh provides additional capabilities:
- name: JAEGER_ENDPOINT
  value: "http://jaeger:14268/api/traces"
- name: PROMETHEUS_ENDPOINT  
  value: "http://prometheus:9090"
```

### **DevSpace/Skaffold Integration**
Service mesh works seamlessly with development workflows:
- DevSpace and Skaffold deploy services with automatic sidecar injection
- Port forwarding works through Istio gateway
- Live reload and development features maintained

### **External Access**
Services are accessible via clean URLs:
- LocalStack: `http://localstack.dev.bytefreezer.local:4566`
- Proxy API: `http://proxy.dev.bytefreezer.local/api`
- Receiver: `http://receiver.dev.bytefreezer.local/data`
- Piper: `http://piper.dev.bytefreezer.local/pipeline`

## 🚀 **Production Features**

- **Zero-downtime deployments** with traffic shifting
- **Automatic failover** with circuit breakers
- **Security** with mTLS and authorization policies
- **Monitoring** with comprehensive observability stack
- **Scalability** with intelligent load balancing
- **Resilience** with fault injection and chaos testing

This service mesh setup transforms your ByteFreezer development environment into a production-like ecosystem with enterprise-grade service communication, security, and observability! 🌟