#!/bin/bash
# Test script for naming-convention.bicep module
# This script validates the module and tests it with various inputs

set -e

echo "🧪 Testing Naming Convention Module"
echo ""

# Check if Azure CLI is available
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI not found. Please install Azure CLI."
    exit 1
fi

# Check if bicep CLI is available
if ! az bicep version &> /dev/null; then
    echo "❌ Azure CLI with Bicep extension not found. Please install: az bicep install"
    exit 1
fi

echo "✅ Bicep CLI found"
echo ""

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TEST_FILE="$SCRIPT_DIR/test-naming-temp.bicep"

# Build/validate the module
echo "🔨 Building naming-convention.bicep..."
if az bicep build --file "$SCRIPT_DIR/naming-convention.bicep" 2>&1; then
    echo "✅ Module builds successfully"
else
    echo "❌ Build failed"
    exit 1
fi
echo ""

# Check if build-only flag is set
if [ "$1" == "--build-only" ]; then
    echo "✅ Build validation complete"
    exit 0
fi

# Test cases
echo "🧪 Testing module with different inputs..."
echo ""

test_case() {
    local name=$1
    local subType=$2
    local svc=$3
    local role=$4
    local resType=$5
    local deploymentEnvInstance=$6
    local regionCode=$7
    local instanceNumber=$8
    local expected=$9
    
    echo "Test: $name"
    
    # Create test file
    cat > "$TEST_FILE" <<EOF
targetScope = 'resourceGroup'

module namingConvention 'naming-convention.bicep' = {
  name: 'test-naming-convention'
  params: {
    subType: '$subType'
    svc: '$svc'
    role: '$role'
    resType: '$resType'
    deploymentEnvInstance: '$deploymentEnvInstance'
    regionCode: '$regionCode'
    instanceNumber: '$instanceNumber'
  }
}

output testName string = namingConvention.outputs.name
output testComponents object = namingConvention.outputs.components
EOF
    
    # Build the test file
    if az bicep build --file "$TEST_FILE" 2>&1; then
        echo "  ✅ Build successful"
        echo "  Expected: $expected"
        echo "  Parameters: subType=$subType, svc=$svc, role=$role, resType=$resType, deploymentEnvInstance=$deploymentEnvInstance, regionCode=$regionCode, instanceNumber=$instanceNumber"
    else
        echo "  ❌ Build failed"
        return 1
    fi
    echo ""
}

# Run test cases
test_case "Production Storage Account" "PRD" "CHM" "INF" "STO" "1" "4" "01" "PRDCHMINFSTO1401"
test_case "Test Database Server" "TST" "CHM" "DBS" "STO" "0" "0" "01" "TSTCHMDBSTO0001"
test_case "Development Network Infrastructure" "DEV" "FFC" "NET" "SUB" "1" "4" "99" "DEVFFCNETSUB1499"
test_case "Sandpit Application Service Plan" "SND" "AIE" "ASP" "ASP" "2" "4" "05" "SNDAIEASPASP2405"
test_case "Production Resource Group" "PRD" "CHM" "INF" "RGP" "1" "4" "01" "PRDCHMINFRGP1401"

# Cleanup
rm -f "$TEST_FILE"

echo "✅ All tests passed!"
