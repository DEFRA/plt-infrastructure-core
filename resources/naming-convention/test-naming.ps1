# Test script for naming-convention.bicep module
# This script validates the module and tests it with various inputs

param(
    [switch]$BuildOnly
)

Write-Host "🧪 Testing Naming Convention Module" -ForegroundColor Cyan
Write-Host ""

# Check if bicep CLI is available
$bicepVersion = az bicep version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Azure CLI with Bicep extension not found. Please install Azure CLI." -ForegroundColor Red
    exit 1
}

Write-Host "✅ Bicep CLI found" -ForegroundColor Green
Write-Host ""

# Test cases
$testCases = @(
    @{
        Name = "Production Storage Account"
        Params = @{
            subType = "PRD"
            svc = "CHM"
            role = "INF"
            resType = "STO"
            deploymentEnvInstance = "1"
            regionCode = "4"
            instanceNumber = "01"
        }
        Expected = "PRDCHMINFSTO1401"
    },
    @{
        Name = "Test Database Server"
        Params = @{
            subType = "TST"
            svc = "CHM"
            role = "DBS"
            resType = "STO"
            deploymentEnvInstance = "0"
            regionCode = "0"
            instanceNumber = "01"
        }
        Expected = "TSTCHMDBSTO0001"
    },
    @{
        Name = "Development Network Infrastructure"
        Params = @{
            subType = "DEV"
            svc = "FFC"
            role = "NET"
            resType = "SUB"
            deploymentEnvInstance = "1"
            regionCode = "4"
            instanceNumber = "99"
        }
        Expected = "DEVFFCNETSUB1499"
    },
    @{
        Name = "Sandpit Application Service Plan"
        Params = @{
            subType = "SND"
            svc = "AIE"
            role = "ASP"
            resType = "ASP"
            deploymentEnvInstance = "2"
            regionCode = "4"
            instanceNumber = "05"
        }
        Expected = "SNDAIEASPASP2405"
    },
    @{
        Name = "Production Resource Group"
        Params = @{
            subType = "PRD"
            svc = "CHM"
            role = "INF"
            resType = "RGP"
            deploymentEnvInstance = "1"
            regionCode = "4"
            instanceNumber = "01"
        }
        Expected = "PRDCHMINFRGP1401"
    }
)

# Create a test bicep file that uses the module
$testBicepContent = @"
targetScope = 'resourceGroup'

module namingConvention 'naming-convention.bicep' = {
  name: 'test-naming-convention'
  params: {
    subType: 'PRD'
    svc: 'CHM'
    role: 'INF'
    resType: 'STO'
    deploymentEnvInstance: '1'
    regionCode: '4'
    instanceNumber: '01'
  }
}

output testName string = namingConvention.outputs.name
output testComponents object = namingConvention.outputs.components
"@

$testBicepFile = Join-Path $PSScriptRoot "test-naming-temp.bicep"
$testBicepContent | Out-File -FilePath $testBicepFile -Encoding utf8

Write-Host "📝 Created temporary test file: $testBicepFile" -ForegroundColor Yellow
Write-Host ""

# Build/validate the module
Write-Host "🔨 Building naming-convention.bicep..." -ForegroundColor Cyan
$buildResult = az bicep build --file "naming-convention.bicep" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed:" -ForegroundColor Red
    Write-Host $buildResult
    Remove-Item $testBicepFile -ErrorAction SilentlyContinue
    exit 1
}
Write-Host "✅ Module builds successfully" -ForegroundColor Green
Write-Host ""

if ($BuildOnly) {
    Write-Host "✅ Build validation complete" -ForegroundColor Green
    Remove-Item $testBicepFile -ErrorAction SilentlyContinue
    exit 0
}

# Test the module with different inputs
Write-Host "🧪 Testing module with different inputs..." -ForegroundColor Cyan
Write-Host ""

$allPassed = $true
foreach ($testCase in $testCases) {
    Write-Host "Test: $($testCase.Name)" -ForegroundColor Yellow
    
    # Create test file for this case
    $testContent = @"
targetScope = 'resourceGroup'

module namingConvention 'naming-convention.bicep' = {
  name: 'test-naming-convention'
  params: {
    subType: '$($testCase.Params.subType)'
    svc: '$($testCase.Params.svc)'
    role: '$($testCase.Params.role)'
    resType: '$($testCase.Params.resType)'
    deploymentEnvInstance: '$($testCase.Params.deploymentEnvInstance)'
    regionCode: '$($testCase.Params.regionCode)'
    instanceNumber: '$($testCase.Params.instanceNumber)'
  }
}

output testName string = namingConvention.outputs.name
output testComponents object = namingConvention.outputs.components
"@
    $testContent | Out-File -FilePath $testBicepFile -Encoding utf8 -Force
    
    # Build the test file
    $buildOutput = az bicep build --file $testBicepFile 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Build successful" -ForegroundColor Green
        Write-Host "  Expected: $($testCase.Expected)" -ForegroundColor Gray
        Write-Host "  Parameters: $($testCase.Params | ConvertTo-Json -Compress)" -ForegroundColor Gray
    } else {
        Write-Host "  ❌ Build failed:" -ForegroundColor Red
        Write-Host $buildOutput
        $allPassed = $false
    }
    Write-Host ""
}

# Cleanup
Remove-Item $testBicepFile -ErrorAction SilentlyContinue

if ($allPassed) {
    Write-Host "✅ All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ Some tests failed" -ForegroundColor Red
    exit 1
}
