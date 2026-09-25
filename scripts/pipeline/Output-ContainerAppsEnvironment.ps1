<#
.SYNOPSIS
  Reads the latest container-apps-environment deployment outputs for hub DNS linking.
#>
param(
  [Parameter(Mandatory = $true)][string]$ResourceGroupName
)

$rg = $ResourceGroupName
# Prefer the parent template deployment (exact name) over nested modules that share the same prefix.
$deploymentName = az deployment group list -g $rg --query "[?name=='container-apps-environment'].name | [0]" -o tsv
if (-not $deploymentName) {
  $deploymentName = az deployment group list -g $rg --query "sort_by([?starts_with(name, 'container-apps-environment') && contains(keys(properties.outputs), 'privateDnsZoneName')], &properties.timestamp)[-1].name" -o tsv
}
if (-not $deploymentName) {
  Write-Host "No container-apps-environment deployment found in $rg"
  exit 0
}

$defaultDomain = az deployment group show -g $rg -n $deploymentName --query "properties.outputs.defaultDomain.value" -o tsv
$staticIp = az deployment group show -g $rg -n $deploymentName --query "properties.outputs.staticIp.value" -o tsv
$privateDnsZoneName = az deployment group show -g $rg -n $deploymentName --query "properties.outputs.privateDnsZoneName.value" -o tsv

Write-Host "Container Apps Environment defaultDomain: $defaultDomain"
Write-Host "Container Apps Environment staticIp: $staticIp"
Write-Host "Container Apps Environment privateDnsZoneName: $privateDnsZoneName"

if (-not [string]::IsNullOrWhiteSpace($defaultDomain)) {
  Write-Host "##vso[task.setvariable variable=containerAppsEnvironmentDefaultDomain]$defaultDomain"
}
if (-not [string]::IsNullOrWhiteSpace($staticIp)) {
  Write-Host "##vso[task.setvariable variable=containerAppsEnvironmentStaticIp]$staticIp"
}
if (-not [string]::IsNullOrWhiteSpace($privateDnsZoneName)) {
  Write-Host "##vso[task.setvariable variable=containerAppsEnvironmentPrivateDnsZoneName]$privateDnsZoneName"
}
