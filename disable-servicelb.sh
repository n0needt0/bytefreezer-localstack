#!/bin/bash

# Script to disable k3s servicelb and allow MetalLB to take over

echo "🔧 Disabling k3s servicelb to resolve MetalLB conflicts..."

# Step 1: Delete existing servicelb daemonset
echo "Deleting servicelb daemonset..."
kubectl delete daemonset -n kube-system servicelb 2>/dev/null || echo "No servicelb daemonset found"

# Step 2: Delete localstack servicelb pods specifically
echo "Cleaning up LocalStack servicelb pods..."
kubectl delete pods -n kube-system -l "app=svclb-localstack-dev" --force --grace-period=0
kubectl delete pods -n kube-system -l "app=svclb-localstack-external" --force --grace-period=0

# Step 3: Remove servicelb-related annotations from services
echo "Cleaning up service annotations..."
kubectl annotate service -n localstack localstack-dev "svccontroller.k3s.cattle.io/enablelb-" || true
kubectl annotate service -n localstack localstack-external "svccontroller.k3s.cattle.io/enablelb-" || true

# Step 4: Add annotation to let MetalLB take over
echo "Adding MetalLB annotations..."
kubectl annotate service -n localstack localstack-dev "metallb.universe.tf/address-pool=localstack-pool" --overwrite
kubectl annotate service -n localstack localstack-external "metallb.universe.tf/address-pool=localstack-pool" --overwrite

# Step 5: Restart MetalLB controller to pick up changes
echo "Restarting MetalLB controller..."
kubectl rollout restart deployment -n metallb-system controller

echo "✅ ServiceLB disabled. Waiting for MetalLB to take over..."
sleep 10

# Step 6: Check status
echo "📊 Current service status:"
kubectl get services -n localstack

echo ""
echo "🔍 Checking for remaining servicelb pods:"
kubectl get pods -n kube-system | grep svclb-localstack || echo "No LocalStack servicelb pods found"

echo ""
echo "🎯 MetalLB should now manage LoadBalancer services exclusively."
echo "Run ./verify-install.sh to check if warnings are resolved."