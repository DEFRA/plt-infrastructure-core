<#
.SYNOPSIS
  Applies extra DNS A records from additionalDnsConfig via shared DNS script.
#>
param(
  [Parameter(Mandatory = $true)][string]$Location,
  [Parameter(Mandatory = $false)][string]$AdditionalDnsConfig = '',
  [Parameter(Mandatory = $true)][string]$RegionToDnsResourcegroupMappingTable,
  [Parameter(Mandatory = $true)][string]$PipelineWorkspace,
  [Parameter(Mandatory = $true)][string]$BuildSourcesDirectory
)

$region = $Location.ToLowerInvariant()
$additionalRaw = $AdditionalDnsConfig
if ([string]::IsNullOrWhiteSpace($additionalRaw) -or $additionalRaw -eq '[]') {
  Write-Host "No additionalDnsConfig entries to set."
  exit 0
}

$additionalParsed = $additionalRaw | ConvertFrom-Json
if ($null -eq $additionalParsed) {
  Write-Host "additionalDnsConfig parsed to null; skipping."
  exit 0
}

$additionalItems = if ($additionalParsed -is [System.Array]) { $additionalParsed } else { @($additionalParsed) }
$dnsEntries = @()
foreach ($entry in $additionalItems) {
  # Region defaults to the runtime pipeline location when omitted in config.
  if ($null -eq $entry.Region -or [string]::IsNullOrWhiteSpace($entry.Region)) { $entry.Region = $region }
  if ($null -ne $entry.IpAddress -and -not ($entry.IpAddress -is [System.Array])) { $entry.IpAddress = @($entry.IpAddress) }
  $dnsEntries += $entry
}

if ($dnsEntries.Count -eq 0) {
  Write-Host "No additional DNS entries after normalization; skipping."
  exit 0
}

$env:PRIVATEENDPOINTDNSRECORDSJSON = ($dnsEntries | ConvertTo-Json -Depth 10)
$env:REGION_TO_DNS_RESOURCEGROUP_MAPPING_TABLE = $RegionToDnsResourcegroupMappingTable
$scriptPath = Join-Path $PipelineWorkspace "s/self/scripts/common-scripts/PowerShellLibrary/Set-PrivateDnsRecordSet.ps1"
if (-not (Test-Path $scriptPath)) { $scriptPath = Join-Path $BuildSourcesDirectory "self/scripts/common-scripts/PowerShellLibrary/Set-PrivateDnsRecordSet.ps1" }
if (-not (Test-Path $scriptPath)) { throw "Set-PrivateDnsRecordSet.ps1 not found" }
& $scriptPath -Ttl 300
