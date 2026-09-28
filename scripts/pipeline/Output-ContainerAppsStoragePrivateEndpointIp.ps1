<#
.SYNOPSIS
  Resolves the Container Apps storage file private-endpoint IP for DNS (privatelink.file.core.windows.net).
#>
param(
  [Parameter(Mandatory = $true)][string]$ResourceGroupName,
  [Parameter(Mandatory = $false)][string]$StorageAccountName = '',
  [Parameter(Mandatory = $false)][string]$PrivateEndpointName = ''
)

$ErrorActionPreference = 'Stop'
$rg = $ResourceGroupName

$deploymentName = az deployment group list -g $rg --query "[?name=='container-apps-environment'].name | [0]" -o tsv
if (-not $deploymentName) {
  $deploymentName = az deployment group list -g $rg --query "sort_by([?starts_with(name, 'container-apps-environment') && contains(keys(properties.outputs), 'storageAccountName')], &properties.timestamp)[-1].name" -o tsv
}

if ($deploymentName) {
  if ([string]::IsNullOrWhiteSpace($StorageAccountName)) {
    $StorageAccountName = az deployment group show -g $rg -n $deploymentName --query "properties.outputs.storageAccountName.value" -o tsv
  }
  if ([string]::IsNullOrWhiteSpace($PrivateEndpointName)) {
    $PrivateEndpointName = az deployment group show -g $rg -n $deploymentName --query "properties.outputs.storagePrivateEndpointName.value" -o tsv
  }
}

if ([string]::IsNullOrWhiteSpace($StorageAccountName)) {
  Write-Host "No Container Apps storage account on this deploy; skipping PE IP lookup."
  exit 0
}

if ([string]::IsNullOrWhiteSpace($PrivateEndpointName)) {
  $PrivateEndpointName = "${StorageAccountName}pep01"
}

$ip = az network private-endpoint show -g $rg -n $PrivateEndpointName --query "customDnsConfigs[0].ipAddresses[0]" -o tsv
if ([string]::IsNullOrWhiteSpace($ip)) {
  # Some API versions nest configs differently; fall back to NIC private IP.
  $nicId = az network private-endpoint show -g $rg -n $PrivateEndpointName --query "networkInterfaces[0].id" -o tsv
  if (-not [string]::IsNullOrWhiteSpace($nicId)) {
    $ip = az network nic show --ids $nicId --query "ipConfigurations[0].privateIPAddress" -o tsv
  }
}

Write-Host "Container Apps storage account: $StorageAccountName"
Write-Host "Container Apps storage private endpoint: $PrivateEndpointName"
Write-Host "Container Apps storage private endpoint IP: $ip"

Write-Host "##vso[task.setvariable variable=containerAppsStorageAccountName]$StorageAccountName"
if ([string]::IsNullOrWhiteSpace($ip)) {
  throw "Could not resolve private endpoint IP for $PrivateEndpointName in $rg"
}
Write-Host "##vso[task.setvariable variable=containerAppsStoragePrivateEndpointIp]$ip"
