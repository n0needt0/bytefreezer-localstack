#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

CHART_DIR="localstack"

echo -e "${BLUE}🔍 Validating LocalStack Helm Chart${NC}"
echo "=================================="

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "${RED}❌ Helm not found. Please install Helm first.${NC}"
    exit 1
fi

# Helm lint
echo -e "${BLUE}📋 Running helm lint...${NC}"
if helm lint $CHART_DIR; then
    echo -e "${GREEN}✅ Helm lint passed${NC}"
else
    echo -e "${RED}❌ Helm lint failed${NC}"
    exit 1
fi

echo ""

# Template validation with different values
echo -e "${BLUE}🧪 Testing template rendering...${NC}"

echo "Testing default values..."
helm template test $CHART_DIR --debug --dry-run > /dev/null
echo -e "${GREEN}✅ Default values work${NC}"

echo "Testing dev values..."
helm template test $CHART_DIR -f $CHART_DIR/values-dev.yaml --debug --dry-run > /dev/null
echo -e "${GREEN}✅ Dev values work${NC}"

echo "Testing prod values..."
helm template test $CHART_DIR -f $CHART_DIR/values-prod.yaml --debug --dry-run > /dev/null
echo -e "${GREEN}✅ Prod values work${NC}"

echo ""

# Check for required files
echo -e "${BLUE}📁 Checking required files...${NC}"
required_files=(
    "$CHART_DIR/Chart.yaml"
    "$CHART_DIR/values.yaml"
    "$CHART_DIR/values-dev.yaml"
    "$CHART_DIR/values-prod.yaml"
    "$CHART_DIR/templates/deployment.yaml"
    "$CHART_DIR/templates/services.yaml"
    "$CHART_DIR/templates/pvc.yaml"
    "$CHART_DIR/templates/configmap.yaml"
    "$CHART_DIR/templates/init-job.yaml"
    "$CHART_DIR/templates/metallb.yaml"
    "$CHART_DIR/templates/_helpers.tpl"
    "$CHART_DIR/templates/NOTES.txt"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✅ $file${NC}"
    else
        echo -e "${RED}❌ $file (missing)${NC}"
        exit 1
    fi
done

echo ""

# Test specific configurations
echo -e "${BLUE}🔧 Testing specific configurations...${NC}"

echo "Testing MetalLB disabled..."
helm template test $CHART_DIR --set metallb.enabled=false --debug --dry-run > /dev/null
echo -e "${GREEN}✅ MetalLB disabled works${NC}"

echo "Testing initJob disabled..."
helm template test $CHART_DIR --set initJob.enabled=false --debug --dry-run > /dev/null
echo -e "${GREEN}✅ InitJob disabled works${NC}"

echo "Testing external service disabled..."
helm template test $CHART_DIR --set service.external.enabled=false --debug --dry-run > /dev/null
echo -e "${GREEN}✅ External service disabled works${NC}"

echo "Testing persistence disabled..."
helm template test $CHART_DIR --set persistence.enabled=false --debug --dry-run > /dev/null
echo -e "${GREEN}✅ Persistence disabled works${NC}"

echo ""

# Generate sample output for inspection
echo -e "${BLUE}📄 Generating sample output...${NC}"
mkdir -p output

echo "Generating default configuration..."
helm template localstack $CHART_DIR > output/default.yaml
echo -e "${GREEN}✅ Default: output/default.yaml${NC}"

echo "Generating dev configuration..."
helm template localstack $CHART_DIR -f $CHART_DIR/values-dev.yaml > output/dev.yaml
echo -e "${GREEN}✅ Dev: output/dev.yaml${NC}"

echo "Generating prod configuration..."
helm template localstack $CHART_DIR -f $CHART_DIR/values-prod.yaml > output/prod.yaml
echo -e "${GREEN}✅ Prod: output/prod.yaml${NC}"

echo ""

# Package the chart
echo -e "${BLUE}📦 Packaging chart...${NC}"
if helm package $CHART_DIR; then
    echo -e "${GREEN}✅ Chart packaged successfully${NC}"
    ls -la *.tgz 2>/dev/null || true
else
    echo -e "${RED}❌ Chart packaging failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 Chart validation completed successfully!${NC}"
echo ""
echo -e "${BLUE}📋 Summary:${NC}"
echo "- Chart lint: ✅ Passed"
echo "- Template rendering: ✅ All configurations work"
echo "- Required files: ✅ All present"  
echo "- Configuration tests: ✅ All passed"
echo "- Chart packaging: ✅ Successfully packaged"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Review generated templates in output/ directory"
echo "2. Test deployment: ./deploy-helm.sh --environment dev --dry-run"
echo "3. Deploy for real: ./deploy-helm.sh --environment dev"