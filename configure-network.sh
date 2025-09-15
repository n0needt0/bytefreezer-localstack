#!/bin/bash
set -e

echo "🌐 MetalLB Network Configuration Helper"
echo "======================================"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Detecting network configuration...${NC}"

# Get node information
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')

echo -e "${GREEN}✅ K3s Node Information:${NC}"
echo "   Node Name: $NODE_NAME"
echo "   Node IP: $NODE_IP"

# Detect network interface and subnet
if command -v ip &> /dev/null; then
    # Get the interface that has the node IP
    INTERFACE=$(ip route get $NODE_IP | grep -oP 'dev \K\S+' | head -1)
    SUBNET=$(ip route | grep $INTERFACE | grep -E '192\.168\.|10\.|172\.' | grep -v default | head -1 | awk '{print $1}')
    
    echo "   Interface: $INTERFACE"
    echo "   Subnet: $SUBNET"
    
    # Suggest IP range based on subnet
    if [[ $SUBNET =~ ^192\.168\.([0-9]+)\. ]]; then
        NETWORK_PREFIX="192.168.${BASH_REMATCH[1]}"
        START_IP="${NETWORK_PREFIX}.240"
        END_IP="${NETWORK_PREFIX}.249"
    elif [[ $SUBNET =~ ^10\.([0-9]+)\.([0-9]+)\. ]]; then
        NETWORK_PREFIX="10.${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
        START_IP="${NETWORK_PREFIX}.240"
        END_IP="${NETWORK_PREFIX}.249"
    elif [[ $SUBNET =~ ^172\.([0-9]+)\.([0-9]+)\. ]]; then
        NETWORK_PREFIX="172.${BASH_REMATCH[1]}.${BASH_REMATCH[2]}"
        START_IP="${NETWORK_PREFIX}.240"
        END_IP="${NETWORK_PREFIX}.249"
    else
        echo -e "${YELLOW}⚠️  Could not determine network prefix automatically${NC}"
        START_IP="192.168.1.240"
        END_IP="192.168.1.249"
    fi
else
    echo -e "${YELLOW}⚠️  'ip' command not available, using defaults${NC}"
    INTERFACE="eth0"
    START_IP="192.168.1.240"
    END_IP="192.168.1.249"
fi

echo ""
echo -e "${BLUE}📝 Suggested MetalLB Configuration:${NC}"
echo "================================="

# Create suggested configuration
cat > metallb-config-suggested.yaml << EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: localstack-pool
  namespace: metallb-system
spec:
  addresses:
  - ${START_IP}-${END_IP}  # Suggested range for your network
  autoAssign: true
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: localstack-l2-adv
  namespace: metallb-system
spec:
  ipAddressPools:
  - localstack-pool
  interfaces:
  - ${INTERFACE}  # Detected network interface
EOF

cat metallb-config-suggested.yaml

echo ""
echo -e "${GREEN}✅ Configuration saved to: metallb-config-suggested.yaml${NC}"
echo ""
echo -e "${YELLOW}📋 Next Steps:${NC}"
echo "1. Review the suggested configuration above"
echo "2. Verify the IP range ${START_IP}-${END_IP} is available on your network"
echo "3. Check that interface '${INTERFACE}' is correct"
echo "4. Copy metallb-config-suggested.yaml to metallb-config.yaml if it looks correct:"
echo "   cp metallb-config-suggested.yaml metallb-config.yaml"
echo "5. Or manually edit metallb-config.yaml with your preferred settings"
echo "6. Run ./deploy.sh to deploy LocalStack with MetalLB"
echo ""
echo -e "${YELLOW}⚠️  Important:${NC}"
echo "- Ensure the IP range doesn't conflict with your DHCP server"
echo "- The IPs should be on the same subnet as your K3s nodes"
echo "- Consider reserving these IPs in your router/DHCP configuration"

# Test connectivity to suggested range
echo ""
echo -e "${BLUE}🔍 Testing IP range availability...${NC}"
for i in {240..242}; do
    TEST_IP="${NETWORK_PREFIX}.$i"
    if ping -c 1 -W 1 "$TEST_IP" &> /dev/null; then
        echo -e "${YELLOW}⚠️  $TEST_IP is responding to ping (may be in use)${NC}"
    else
        echo -e "${GREEN}✅ $TEST_IP appears available${NC}"
    fi
done

echo ""
echo -e "${GREEN}🎉 Network configuration helper complete!${NC}"