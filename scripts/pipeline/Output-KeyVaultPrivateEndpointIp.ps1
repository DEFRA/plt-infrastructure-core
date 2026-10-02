<#
.SYNOPSIS
  Resolves the platform Key Vault private-endpoint IP for DNS (vaultcore.azure.net / privatelink.vaultcore.azure.net).
#>
param(
  [Parameter(Mandatory = $true)][string]$ResourceGroupName,
  [Parameter(Mandatory = $false)][string]$KeyVaultName = '',
  [Parameter(Mandatory = $false)][string]$PrivateEndpointName = ''
)

$ErrorActionPreference = 'Stop'
$rg = $ResourceGroupName

$deploymentName = az deployment group list -g $rg --query "sort_by([?starts_with(name, 'key-vault')], &properties.timestamp)[-1].name" -o tsv
if ($deploymentName) {
  if ([string]::IsNullOrWhiteSpace($KeyVaultName)) {
    $KeyVaultName = az deployment group show -g $rg -n $deploymentName --query "properties.outputs.name.value" -o tsv
  }
  if ([string]::IsNullOrWhiteSpace($PrivateEndpointName)) {
    $PrivateEndpointName = az deployment group show -g $rg -n $deploymentName --query "properties.outputs.privateEndpointName.value" -o tsv
  }
}

if ([string]::IsNullOrWhiteSpace($KeyVaultName)) {
  Write-Host "No Key Vault on this deploy; skipping PE IP lookup."
  exit 0
}

if ([string]::IsNullOrWhiteSpace($PrivateEndpointName)) {
  $PrivateEndpointName = ("{0}pep01" -f $KeyVaultName.ToLowerInvariant())
  if ($PrivateEndpointName.Length -gt 64) {
    $PrivateEndpointName = $PrivateEndpointName.Substring(0, 64)
  }
}

$ip = az network private-endpoint show -g $rg -n $PrivateEndpointName --query "customDnsConfigs[0].ipAddresses[0]" -o tsv
if ([string]::IsNullOrWhiteSpace($ip)) {
  $nicId = az network private-endpoint show -g $rg -n $PrivateEndpointName --query "networkInterfaces[0].id" -o tsv
  if (-not [string]::IsNullOrWhiteSpace($nicId)) {
    $ip = az network nic show --ids $nicId --query "ipConfigurations[0].privateIPAddress" -o tsv
  }
}

Write-Host "Key Vault: $KeyVaultName"
Write-Host "Key Vault private endpoint: $PrivateEndpointName"
Write-Host "Key Vault private endpoint IP: $ip"

Write-Host "##vso[task.setvariable variable=keyVaultName]$KeyVaultName"
if ([string]::IsNullOrWhiteSpace($ip)) {
  throw "Could not resolve private endpoint IP for $PrivateEndpointName in $rg"
}
Write-Host "##vso[task.setvariable variable=keyVaultPrivateEndpointIp]$ip"
