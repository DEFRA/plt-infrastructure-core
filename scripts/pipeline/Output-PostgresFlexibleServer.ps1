<#
.SYNOPSIS
  Exports PostgreSQL Flexible Server private DNS zone name for hub linking.

.DESCRIPTION
  Prefers the deterministic zone name from the server name (set-resource-names).
  Falls back to reading the latest parent deployment outputs when needed.
#>
param(
  [Parameter(Mandatory = $true)][string]$ResourceGroupName,
  [Parameter(Mandatory = $false)][string]$PostgresFlexibleServerName = '',
  [Parameter(Mandatory = $false)][string]$DeploymentNamePrefix = 'postgres-flexible-server'
)

$ErrorActionPreference = 'Stop'
$rg = $ResourceGroupName

$privateDnsZoneName = ''
$fqdn = ''

if (-not [string]::IsNullOrWhiteSpace($PostgresFlexibleServerName)) {
  $serverName = $PostgresFlexibleServerName.Trim().ToLowerInvariant()
  $privateDnsZoneName = "$serverName.privatelink.postgres.database.azure.com"
  $fqdn = "$serverName.$privateDnsZoneName"
  Write-Host "Using deterministic private DNS zone from server name '$serverName'."
}
else {
  # Avoid JMESPath keys() on null outputs (other deployments in the RG break that filter).
  $candidatesJson = az deployment group list -g $rg --query "[?starts_with(name, '$DeploymentNamePrefix')].{name:name, timestamp:properties.timestamp}" -o json 2>$null
  if (-not [string]::IsNullOrWhiteSpace($candidatesJson) -and $candidatesJson -ne '[]') {
    $candidates = @($candidatesJson | ConvertFrom-Json | Sort-Object timestamp -Descending)
    foreach ($candidate in $candidates) {
      $zone = az deployment group show -g $rg -n $candidate.name --query "properties.outputs.privateDnsZoneName.value" -o tsv 2>$null
      if (-not [string]::IsNullOrWhiteSpace($zone)) {
        $privateDnsZoneName = $zone
        $fqdn = az deployment group show -g $rg -n $candidate.name --query "properties.outputs.fqdn.value" -o tsv 2>$null
        Write-Host "Resolved private DNS zone from deployment '$($candidate.name)'."
        break
      }
    }
  }
}

if ([string]::IsNullOrWhiteSpace($privateDnsZoneName)) {
  throw "Could not resolve PostgreSQL private DNS zone name in RG '$rg' (pass -PostgresFlexibleServerName or ensure a parent deployment has privateDnsZoneName output)."
}

Write-Host "PostgreSQL Flexible Server privateDnsZoneName: $privateDnsZoneName"
Write-Host "PostgreSQL Flexible Server fqdn: $fqdn"

Write-Host "##vso[task.setvariable variable=postgresFlexibleServerPrivateDnsZoneName]$privateDnsZoneName"
if (-not [string]::IsNullOrWhiteSpace($fqdn)) {
  Write-Host "##vso[task.setvariable variable=postgresFlexibleServerFqdn]$fqdn"
}
