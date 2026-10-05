<#
.SYNOPSIS
  Resolves the Container Apps storage file private-endpoint IP for DNS (privatelink.file.core.windows.net).
#>
param(
  [Parameter(Mandatory = $true)][string]$ResourceGroupName,
  [Parameter(Mandatory = $false)][string]$StorageAccountName = '',
  [Parameter(Mandatory = $false)][string]$PrivateEndpointName = '',
  [Parameter(Mandatory = $false)][string]$OutputAccountNameVariable = 'containerAppsStorageAccountName',
  [Parameter(Mandatory = $false)][string]$OutputIpVariable = 'containerAppsStoragePrivateEndpointIp',
  [Parameter(Mandatory = $false)][string]$OutputPrivateEndpointNameVariable = '',
  # When set, read this deployment output for the account name if -StorageAccountName is empty
  # (default: storageAccountName; NFS uses storageNfsAccountName).
  [Parameter(Mandatory = $false)][string]$DeploymentAccountOutput = 'storageAccountName',
  [Parameter(Mandatory = $false)][string]$DeploymentPrivateEndpointOutput = 'storagePrivateEndpointName'
)

$ErrorActionPreference = 'Stop'
$rg = $ResourceGroupName

$deploymentName = az deployment group list -g $rg --query "[?name=='container-apps-environment'].name | [0]" -o tsv
if (-not $deploymentName) {
  $deploymentName = az deployment group list -g $rg --query "sort_by([?starts_with(name, 'container-apps-environment') && contains(keys(properties.outputs), 'storageAccountName')], &properties.timestamp)[-1].name" -o tsv
}

if ($deploymentName) {
  if ([string]::IsNullOrWhiteSpace($StorageAccountName)) {
    $StorageAccountName = az deployment group show -g $rg -n $deploymentName --query "properties.outputs.$DeploymentAccountOutput.value" -o tsv
  }
  if ([string]::IsNullOrWhiteSpace($PrivateEndpointName)) {
    $PrivateEndpointName = az deployment group show -g $rg -n $deploymentName --query "properties.outputs.$DeploymentPrivateEndpointOutput.value" -o tsv
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

Write-Host "##vso[task.setvariable variable=$OutputAccountNameVariable]$StorageAccountName"
if (-not [string]::IsNullOrWhiteSpace($OutputPrivateEndpointNameVariable)) {
  Write-Host "##vso[task.setvariable variable=$OutputPrivateEndpointNameVariable]$PrivateEndpointName"
}
if ([string]::IsNullOrWhiteSpace($ip)) {
  throw "Could not resolve private endpoint IP for $PrivateEndpointName in $rg"
}
Write-Host "##vso[task.setvariable variable=$OutputIpVariable]$ip"
