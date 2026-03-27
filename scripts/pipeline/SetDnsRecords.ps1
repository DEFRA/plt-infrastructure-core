<#
.SYNOPSIS
  Creates/updates private DNS A records via shared DNS helper script.

.DESCRIPTION
  Supports both:
  - bulk entries from additionalDnsConfig JSON
  - a single explicit DNS A record (FQDN + IP)
#>
param(
  [Parameter(Mandatory = $true)][string]$Location,
  [Parameter(Mandatory = $false)][string]$AdditionalDnsConfig = '',
  [Parameter(Mandatory = $false)][string]$Fqdn = '',
  [Parameter(Mandatory = $false)][string]$IpAddress = '',
  [Parameter(Mandatory = $true)][string]$RegionToDnsResourcegroupMappingTable,
  [Parameter(Mandatory = $true)][string]$PipelineWorkspace,
  [Parameter(Mandatory = $true)][string]$BuildSourcesDirectory
)

$region = $Location.ToLowerInvariant()
$dnsEntries = @()

# Mode 1: explicit single DNS A record.
if (-not [string]::IsNullOrWhiteSpace($Fqdn) -and -not [string]::IsNullOrWhiteSpace($IpAddress)) {
  $dnsEntries += [PSCustomObject]@{
    Fqdn = $Fqdn
    IpAddress = @($IpAddress)
    Region = $region
  }
}
else {
  # Mode 2: additionalDnsConfig JSON from config.
  $additionalRaw = $AdditionalDnsConfig
  if ([string]::IsNullOrWhiteSpace($additionalRaw) -or $additionalRaw -eq '[]' -or $additionalRaw -eq 'null') {
    Write-Host "No DNS records to set."
    exit 0
  }

  $additionalParsed = $additionalRaw | ConvertFrom-Json
  if ($null -eq $additionalParsed) {
    Write-Host "additionalDnsConfig parsed to null; skipping."
    exit 0
  }

  $additionalItems = if ($additionalParsed -is [System.Array]) { $additionalParsed } else { @($additionalParsed) }
  foreach ($entry in $additionalItems) {
    # Region defaults to runtime location when omitted.
    if ($null -eq $entry.Region -or [string]::IsNullOrWhiteSpace($entry.Region)) { $entry.Region = $region }
    if ($null -ne $entry.IpAddress -and -not ($entry.IpAddress -is [System.Array])) { $entry.IpAddress = @($entry.IpAddress) }
    $dnsEntries += $entry
  }
}

if ($dnsEntries.Count -eq 0) {
  Write-Host "No DNS entries after normalization; skipping."
  exit 0
}

$env:PRIVATEENDPOINTDNSRECORDSJSON = ($dnsEntries | ConvertTo-Json -Depth 10)
$env:REGION_TO_DNS_RESOURCEGROUP_MAPPING_TABLE = $RegionToDnsResourcegroupMappingTable
$scriptPath = Join-Path $PipelineWorkspace "s/self/scripts/common-scripts/PowerShellLibrary/Set-PrivateDnsRecordSet.ps1"
if (-not (Test-Path $scriptPath)) { $scriptPath = Join-Path $BuildSourcesDirectory "self/scripts/common-scripts/PowerShellLibrary/Set-PrivateDnsRecordSet.ps1" }
if (-not (Test-Path $scriptPath)) { throw "Set-PrivateDnsRecordSet.ps1 not found" }
& $scriptPath -Ttl 300
