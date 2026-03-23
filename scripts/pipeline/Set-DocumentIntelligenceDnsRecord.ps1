<#
.SYNOPSIS
  Creates/updates DNS A record for Document Intelligence private endpoint.
#>
param(
  [Parameter(Mandatory = $true)][string]$PrivateEndpointIp,
  [Parameter(Mandatory = $true)][string]$DocumentIntelligenceResourceName,
  [Parameter(Mandatory = $true)][string]$Location,
  [Parameter(Mandatory = $true)][string]$RegionToDnsResourcegroupMappingTable,
  [Parameter(Mandatory = $true)][string]$PipelineWorkspace,
  [Parameter(Mandatory = $true)][string]$BuildSourcesDirectory
)

$ip = $PrivateEndpointIp
$fqdn = "$DocumentIntelligenceResourceName.cognitiveservices.azure.com"
$region = $Location.ToLowerInvariant()
if ([string]::IsNullOrWhiteSpace($ip)) {
  Write-Host "Document Intelligence DNS record skipped: no private endpoint IP"
  exit 0
}

$dnsEntries = @([PSCustomObject]@{ Fqdn = $fqdn; IpAddress = @($ip); Region = $region })
$env:PRIVATEENDPOINTDNSRECORDSJSON = ($dnsEntries | ConvertTo-Json -Depth 10)
$env:REGION_TO_DNS_RESOURCEGROUP_MAPPING_TABLE = $RegionToDnsResourcegroupMappingTable
$scriptPath = Join-Path $PipelineWorkspace "s/self/common-scripts/PowerShellLibrary/Set-PrivateDnsRecordSet.ps1"
if (-not (Test-Path $scriptPath)) { $scriptPath = Join-Path $BuildSourcesDirectory "self/common-scripts/PowerShellLibrary/Set-PrivateDnsRecordSet.ps1" }
if (-not (Test-Path $scriptPath)) { throw "Set-PrivateDnsRecordSet.ps1 not found" }
& $scriptPath -Ttl 300
