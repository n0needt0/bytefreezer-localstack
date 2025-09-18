#!/bin/bash

# k3s Upgrade Plan: v1.33.1+k3s1 → v1.33.4+k3s1
# Safe upgrade strategy for 12-node cluster (3 masters + 9 workers)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CURRENT_VERSION="v1.33.1+k3s1"
TARGET_VERSION="v1.33.4+k3s1"
MASTER_NODES=("tp1" "tp2" "tp3")
WORKER_NODES=("tp4" "tp5" "tp6" "tp7" "tp8" "tp9" "tp10" "tp11" "tp12")

echo -e "${BLUE}🚀 k3s Upgrade Plan: ${CURRENT_VERSION} → ${TARGET_VERSION}${NC}"
echo "============================================================"

# Pre-upgrade checks
pre_upgrade_checks() {
    echo -e "\n${BLUE}1. Pre-upgrade Checks${NC}"
    echo "----------------------"

    echo "Checking cluster health..."
    kubectl get nodes --no-headers | grep -v Ready && echo "❌ Some nodes not ready!" || echo "✅ All nodes ready"

    echo "Checking critical pods..."
    kubectl get pods --all-namespaces | grep -E "(kube-system|metallb-system|localstack)" | grep -v Running

    echo "Creating etcd snapshot backup..."
    ssh tp1 "sudo k3s etcd-snapshot save pre-upgrade-$(date +%Y%m%d-%H%M%S)"

    echo "Checking LocalStack deployment..."
    kubectl get pods -n localstack -l app=localstack
}

# Upgrade master nodes (one at a time for HA)
upgrade_masters() {
    echo -e "\n${BLUE}2. Upgrading Master Nodes${NC}"
    echo "----------------------------"

    for master in "${MASTER_NODES[@]}"; do
        echo -e "\n${YELLOW}Upgrading master: ${master}${NC}"

        # Drain node (except for daemonsets)
        echo "Draining node ${master}..."
        kubectl drain ${master} --ignore-daemonsets --delete-emptydir-data --timeout=300s

        # Upgrade k3s on the master
        echo "Upgrading k3s on ${master}..."
        ssh ${master} "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${TARGET_VERSION} sh -s - server"

        # Wait for node to be ready
        echo "Waiting for ${master} to be ready..."
        kubectl wait --for=condition=Ready node/${master} --timeout=300s

        # Uncordon the node
        echo "Uncordoning ${master}..."
        kubectl uncordon ${master}

        # Wait a bit between master upgrades
        echo "Waiting 30 seconds before next master..."
        sleep 30
    done
}

# Upgrade worker nodes (in batches)
upgrade_workers() {
    echo -e "\n${BLUE}3. Upgrading Worker Nodes${NC}"
    echo "---------------------------"

    # Upgrade workers in batches of 3 to maintain service availability
    batch_size=3
    for ((i=0; i<${#WORKER_NODES[@]}; i+=batch_size)); do
        batch=("${WORKER_NODES[@]:i:batch_size}")

        echo -e "\n${YELLOW}Upgrading worker batch: ${batch[*]}${NC}"

        # Drain all nodes in batch
        for worker in "${batch[@]}"; do
            echo "Draining ${worker}..."
            kubectl drain ${worker} --ignore-daemonsets --delete-emptydir-data --timeout=300s &
        done
        wait

        # Upgrade all nodes in batch
        for worker in "${batch[@]}"; do
            echo "Upgrading k3s on ${worker}..."
            ssh ${worker} "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=${TARGET_VERSION} K3S_URL=https://tp1:6443 K3S_TOKEN=\$(ssh tp1 sudo cat /var/lib/rancher/k3s/server/node-token) sh -" &
        done
        wait

        # Wait for all nodes in batch to be ready
        for worker in "${batch[@]}"; do
            echo "Waiting for ${worker} to be ready..."
            kubectl wait --for=condition=Ready node/${worker} --timeout=300s
            kubectl uncordon ${worker}
        done

        echo "Batch complete. Waiting 60 seconds before next batch..."
        sleep 60
    done
}

# Post-upgrade verification
post_upgrade_checks() {
    echo -e "\n${BLUE}4. Post-upgrade Verification${NC}"
    echo "------------------------------"

    echo "Checking cluster version..."
    kubectl version

    echo "Checking all nodes..."
    kubectl get nodes -o wide

    echo "Checking system pods..."
    kubectl get pods --all-namespaces | grep -E "(kube-system|metallb-system)"

    echo "Testing LocalStack..."
    kubectl get pods -n localstack
    curl -s http://192.168.86.105:4566/_localstack/health | head -3

    echo "Checking MetalLB..."
    kubectl get services -n localstack

    echo -e "\n${GREEN}✅ Upgrade completed successfully!${NC}"
    echo "Current version: $(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}')"
}

# Main execution
main() {
    echo "This script will upgrade your k3s cluster from ${CURRENT_VERSION} to ${TARGET_VERSION}"
    echo "Masters: ${MASTER_NODES[*]}"
    echo "Workers: ${WORKER_NODES[*]}"
    echo ""
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Upgrade cancelled."
        exit 0
    fi

    pre_upgrade_checks
    upgrade_masters
    upgrade_workers
    post_upgrade_checks
}

# Run the upgrade
main "$@"