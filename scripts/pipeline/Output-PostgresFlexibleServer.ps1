<#
.SYNOPSIS
  Exports PostgreSQL Flexible Server private DNS zone name for hub linking.
#>
param(
  [Parameter(Mandatory = $true)][string]$ResourceGroupName,
  [Parameter(Mandatory = $false)][string]$DeploymentNamePrefix = 'postgres-flexible-server'
)

$ErrorActionPreference = 'Stop'
$rg = $ResourceGroupName

$deploymentName = az deployment group list -g $rg --query "sort_by([?starts_with(name, '$DeploymentNamePrefix') && contains(keys(properties.outputs), 'privateDnsZoneName')], &properties.timestamp)[-1].name" -o tsv
if ([string]::IsNullOrWhiteSpace($deploymentName)) {
  throw "Could not find a '$DeploymentNamePrefix' deployment with privateDnsZoneName output in RG '$rg'."
}

$privateDnsZoneName = az deployment group show -g $rg -n $deploymentName --query "properties.outputs.privateDnsZoneName.value" -o tsv
$fqdn = az deployment group show -g $rg -n $deploymentName --query "properties.outputs.fqdn.value" -o tsv 2>$null

Write-Host "PostgreSQL Flexible Server privateDnsZoneName: $privateDnsZoneName"
Write-Host "PostgreSQL Flexible Server fqdn: $fqdn"

if (-not [string]::IsNullOrWhiteSpace($privateDnsZoneName)) {
  Write-Host "##vso[task.setvariable variable=postgresFlexibleServerPrivateDnsZoneName]$privateDnsZoneName"
}
if (-not [string]::IsNullOrWhiteSpace($fqdn)) {
  Write-Host "##vso[task.setvariable variable=postgresFlexibleServerFqdn]$fqdn"
}
