<#
.SYNOPSIS
  Invokes AAD group creation when an app manifest exists.
#>
param(
  [Parameter(Mandatory = $true)][string]$ManifestPath,
  [Parameter(Mandatory = $true)][string]$ScriptPath,
  [Parameter(Mandatory = $true)][string]$ClientId,
  [Parameter(Mandatory = $true)][string]$TenantId,
  [Parameter(Mandatory = $true)][string]$ClientSecret
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $ManifestPath)) {
  Write-Host "No aad-group.json at $ManifestPath; skipping Create AAD Groups."
  exit 0
}

& $ScriptPath -AADGroupsJsonManifestPath $ManifestPath -ClientId $ClientId -TenantId $TenantId -ClientSecret $ClientSecret
if ($LASTEXITCODE -ne 0) { throw "Create-AADGroups failed" }
