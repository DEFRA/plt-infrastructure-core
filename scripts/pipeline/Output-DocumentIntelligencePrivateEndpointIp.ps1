<#
.SYNOPSIS
  Reads the latest ai-document-intelligence deployment output and exports private endpoint IP.
#>
param(
  [Parameter(Mandatory = $true)][string]$ResourceGroupName
)

$rg = $ResourceGroupName
$deploymentName = az deployment group list -g $rg --query "sort_by([?starts_with(name, 'ai-document-intelligence')], &properties.timestamp)[-1].name" -o tsv
if (-not $deploymentName) {
  Write-Host "No ai-document-intelligence deployment found in $rg"
  exit 0
}

$ip = az deployment group show -g $rg -n $deploymentName --query "properties.outputs.privateEndpointIpAddress.value" -o tsv
Write-Host "Document Intelligence Private Endpoint IP (for subsequent DNS update): $ip"
if (-not [string]::IsNullOrWhiteSpace($ip)) { Write-Host "##vso[task.setvariable variable=documentIntelligencePrivateEndpointIp]$ip" }
