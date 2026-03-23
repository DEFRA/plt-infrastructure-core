<#
.SYNOPSIS
  Resolves an Entra group display name to object ID for VNet join RBAC.
#>
param(
  [Parameter(Mandatory = $false)][string]$GroupName = ''
)

if ([string]::IsNullOrWhiteSpace($GroupName)) {
  Write-Host "networkJoinGroupName not set; skipping network join role assignment."
  Write-Host "##vso[task.setvariable variable=networkJoinGroupObjectId]"
  exit 0
}

try {
  $group = Get-AzADGroup -DisplayName $GroupName
  Write-Host "Resolved group '$GroupName' to object ID: $($group.Id)"
  Write-Host "##vso[task.setvariable variable=networkJoinGroupObjectId]$($group.Id)"
} catch {
  Write-Host "##vso[task.logissue type=warning]Could not resolve AD group '$GroupName': $_"
  Write-Host "##vso[task.setvariable variable=networkJoinGroupObjectId]"
}
