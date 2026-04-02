<#
.SYNOPSIS
  Derives and exports shared infrastructure names from the naming module.

.DESCRIPTION
  Runs `resources/naming-convention/get-names.bicep` once and stores outputs
  as pipeline variables (resource group, vnet, route table, subnet names, and
  optional private link names). This keeps naming logic centralized and DRY.
#>
param(
  [Parameter(Mandatory = $true)][string]$RootPath,
  [Parameter(Mandatory = $true)][string]$Location,
  [Parameter(Mandatory = $true)][string]$SubType,
  [Parameter(Mandatory = $true)][string]$ServiceCode,
  [Parameter(Mandatory = $true)][string]$DeploymentEnvInstance,
  [Parameter(Mandatory = $true)][string]$RegionCode,
  [Parameter(Mandatory = $true)][string]$InstanceNumber,
  [Parameter(Mandatory = $true)][string]$SubnetLayout,
  [string]$AdiPrivateLinkZoneSuffix = ''
)

$ErrorActionPreference = 'Stop'

$root = $RootPath
if (-not (Test-Path (Join-Path $root "resources"))) { $root = Join-Path $RootPath "self" }

$namingFile = Join-Path $root "resources/naming-convention/get-names.bicep"
if (-not (Test-Path $namingFile)) { throw "get-names.bicep not found at $namingFile" }

$namingDeploymentName = "get-names-infra-$(Get-Date -Format 'yyyyMMddHHmmss')" -replace '[^a-zA-Z0-9._-]', '-'
$params = @{
  subType = @{ value = $SubType }
  svc = @{ value = $ServiceCode }
  role = @{ value = "INF" }
  deploymentEnvInstance = @{ value = $DeploymentEnvInstance }
  regionCode = @{ value = $RegionCode }
  instanceNumber = @{ value = $InstanceNumber }
}

# Build subnet name configs based on the selected vnet layout file.
# This avoids hardcoding subnet counts in pipeline YAML.
$vnetParamsPath = Join-Path $root "resources/network/vnet/$SubnetLayout/virtual-network.parameters.json"
if (-not (Test-Path $vnetParamsPath)) { $vnetParamsPath = Join-Path $root "self/resources/network/vnet/$SubnetLayout/virtual-network.parameters.json" }
$subnetConfigs = @()
if (Test-Path $vnetParamsPath) {
  $vnetContent = Get-Content -Raw $vnetParamsPath
  $subnetCount = [regex]::Matches($vnetContent, 'subnet\d+AddressPrefix').Count
  for ($i = 1; $i -le $subnetCount; $i++) {
    $subnetConfigs += @{ resType = 'SUB'; instanceNumber = ('{0:D2}' -f $i) }
  }
}
if ($subnetConfigs.Count -gt 0) {
  $params['subnetNameConfigs'] = @{ value = $subnetConfigs }
}

# The pipeline knows this deployment needs ADI private-link naming.
if (-not [string]::IsNullOrWhiteSpace($AdiPrivateLinkZoneSuffix)) {
  $params['privateLinkZoneSuffix'] = @{ value = $AdiPrivateLinkZoneSuffix }
  $params['privateLinkZoneResType'] = @{ value = 'ADI' }
}

$tempDir = if ($env:TEMP) { $env:TEMP } elseif ($env:AGENT_TEMPDIRECTORY) { $env:AGENT_TEMPDIRECTORY } else { '/tmp' }
$paramsPath = Join-Path $tempDir "get-names-params-$(Get-Date -Format 'yyyyMMddHHmmss').json"
@{
  '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
  contentVersion = '1.0.0.0'
  parameters = $params
} | ConvertTo-Json -Depth 4 | Set-Content -Path $paramsPath -Encoding utf8

az deployment sub create --name $namingDeploymentName --location $Location --template-file $namingFile --parameters $paramsPath --output none
if ($LASTEXITCODE -ne 0) { throw "set-resource-names: get-names (INF) failed" }

$rgName = az deployment sub show --name $namingDeploymentName --query "properties.outputs.resourceGroupName.value" -o tsv
$vnetName = az deployment sub show --name $namingDeploymentName --query "properties.outputs.virtualNetworkName.value" -o tsv
$rtName = az deployment sub show --name $namingDeploymentName --query "properties.outputs.routeTableName.value" -o tsv
$subnetNamesJson = az deployment sub show --name $namingDeploymentName --query "properties.outputs.subnetNames.value" -o json 2>$null
$zoneName = az deployment sub show --name $namingDeploymentName --query "properties.outputs.privateLinkZoneName.value" -o tsv 2>$null
$privateLinkResourceName = az deployment sub show --name $namingDeploymentName --query "properties.outputs.privateLinkZoneResourceName.value" -o tsv 2>$null

if (-not $rgName) { throw "set-resource-names: could not get resourceGroupName" }
Write-Host "##vso[task.setvariable variable=infraResourceGroupName]$rgName"
Write-Host "##vso[task.setvariable variable=virtualNetworkName]$vnetName"
Write-Host "##vso[task.setvariable variable=routeTableName]$rtName"

if (-not [string]::IsNullOrWhiteSpace($subnetNamesJson) -and $subnetNamesJson -ne '[]') {
  $subnetNames = $subnetNamesJson | ConvertFrom-Json
  for ($i = 0; $i -lt $subnetNames.Count; $i++) {
    $n = $i + 1
    Write-Host "##vso[task.setvariable variable=subnet${n}Name]$($subnetNames[$i])"
  }
}
if (-not [string]::IsNullOrWhiteSpace($zoneName)) {
  Write-Host "##vso[task.setvariable variable=documentIntelligencePrivateLinkZoneName]$zoneName"
}
if (-not [string]::IsNullOrWhiteSpace($privateLinkResourceName)) {
  Write-Host "##vso[task.setvariable variable=documentIntelligenceResourceName]$privateLinkResourceName"
}
