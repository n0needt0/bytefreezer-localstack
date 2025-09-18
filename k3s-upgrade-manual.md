# k3s Manual Upgrade Guide: v1.33.1+k3s1 → v1.33.4+k3s1

## Overview
- **Current**: v1.33.1+k3s1
- **Target**: v1.33.4+k3s1
- **Cluster**: 3 masters (tp1, tp2, tp3) + 9 workers (tp4-tp12)

## Pre-upgrade Checklist

### 1. Backup etcd
```bash
# On first master (tp1)
sudo k3s etcd-snapshot save pre-upgrade-$(date +%Y%m%d-%H%M%S)
```

### 2. Check cluster health
```bash
kubectl get nodes
kubectl get pods --all-namespaces | grep -v Running
kubectl get pods -n localstack
kubectl get pods -n metallb-system
```

## Upgrade Process

### Phase 1: Upgrade Master Nodes (ONE AT A TIME)

#### Master 1 (tp1):
```bash
# Drain the node
kubectl drain tp1 --ignore-daemonsets --delete-emptydir-data --timeout=300s

# SSH to tp1 and upgrade
ssh tp1
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.33.4+k3s1 sh -s - server

# Wait for node to be ready, then uncordon
kubectl wait --for=condition=Ready node/tp1 --timeout=300s
kubectl uncordon tp1
```

#### Master 2 (tp2):
```bash
kubectl drain tp2 --ignore-daemonsets --delete-emptydir-data --timeout=300s

ssh tp2
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.33.4+k3s1 sh -s - server

kubectl wait --for=condition=Ready node/tp2 --timeout=300s
kubectl uncordon tp2
```

#### Master 3 (tp3):
```bash
kubectl drain tp3 --ignore-daemonsets --delete-emptydir-data --timeout=300s

ssh tp3
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.33.4+k3s1 sh -s - server

kubectl wait --for=condition=Ready node/tp3 --timeout=300s
kubectl uncordon tp3
```

### Phase 2: Upgrade Worker Nodes (IN BATCHES)

#### Batch 1 (tp4, tp5, tp6):
```bash
# Drain nodes
kubectl drain tp4 tp5 tp6 --ignore-daemonsets --delete-emptydir-data --timeout=300s

# Get token from master
TOKEN=$(ssh tp1 sudo cat /var/lib/rancher/k3s/server/node-token)

# Upgrade each worker
for node in tp4 tp5 tp6; do
    ssh $node "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.33.4+k3s1 K3S_URL=https://tp1:6443 K3S_TOKEN=$TOKEN sh -" &
done
wait

# Wait for ready and uncordon
for node in tp4 tp5 tp6; do
    kubectl wait --for=condition=Ready node/$node --timeout=300s
    kubectl uncordon $node
done
```

#### Batch 2 (tp7, tp8, tp9):
```bash
kubectl drain tp7 tp8 tp9 --ignore-daemonsets --delete-emptydir-data --timeout=300s

for node in tp7 tp8 tp9; do
    ssh $node "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.33.4+k3s1 K3S_URL=https://tp1:6443 K3S_TOKEN=$TOKEN sh -" &
done
wait

for node in tp7 tp8 tp9; do
    kubectl wait --for=condition=Ready node/$node --timeout=300s
    kubectl uncordon $node
done
```

#### Batch 3 (tp10, tp11, tp12):
```bash
kubectl drain tp10 tp11 tp12 --ignore-daemonsets --delete-emptydir-data --timeout=300s

for node in tp10 tp11 tp12; do
    ssh $node "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.33.4+k3s1 K3S_URL=https://tp1:6443 K3S_TOKEN=$TOKEN sh -" &
done
wait

for node in tp10 tp11 tp12; do
    kubectl wait --for=condition=Ready node/$node --timeout=300s
    kubectl uncordon $node
done
```

## Post-upgrade Verification

### 1. Check versions
```bash
kubectl version
kubectl get nodes -o wide
```

### 2. Test critical services
```bash
# LocalStack
kubectl get pods -n localstack
curl http://192.168.86.105:4566/_localstack/health

# MetalLB
kubectl get pods -n metallb-system
kubectl get services -n localstack

# Run verification script
cd /home/andrew/workspace/bytefreezer/bytefreezer-localstack
./verify-install.sh
```

## Key Changes in v1.33.4+k3s1

- **Kubernetes**: Updated to v1.33.4
- **Security fixes**: Various CVE patches
- **containerd**: 2.0.5-k3s2 (already current)
- **etcd**: v3.5.21-k3s1
- **Flannel**: v0.27.0

## Rollback Plan (if needed)

If issues occur, you can rollback:

```bash
# Restore etcd snapshot (on tp1)
sudo k3s server --cluster-reset --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/etcd-snapshot/pre-upgrade-YYYYMMDD-HHMMSS

# Or downgrade individual nodes
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.33.1+k3s1 sh -s - server
```

## Tips

1. **Monitor carefully**: Watch pods and services after each phase
2. **Test between phases**: Ensure LocalStack/MetalLB still work
3. **Have patience**: Allow time for each node to fully restart
4. **Keep notes**: Record any issues for troubleshooting
5. **Schedule maintenance**: Do this during a maintenance window