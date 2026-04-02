<#
.SYNOPSIS
  Resolves an Entra group display name to a pipeline variable (object id).

.DESCRIPTION
  Uses Get-AzADGroup -DisplayName, matching the former Resolve-NetworkJoinGroup.ps1 behavior.
  Run under the SSV Azure PowerShell service connection (directory read), not ARM-only CLI.
#>
param(
  [Parameter(Mandatory = $false)][string]$GroupName = '',
  [Parameter(Mandatory = $true)][string]$OutputVariableName,
  [ValidateSet('Warn', 'Error')]
  [string]$IfNotFound = 'Warn'
)

if ([string]::IsNullOrWhiteSpace($GroupName)) {
  Write-Host "Group name not set; clearing $OutputVariableName."
  Write-Host "##vso[task.setvariable variable=$OutputVariableName]"
  exit 0
}

try {
  $result = Get-AzADGroup -DisplayName $GroupName -ErrorAction Stop
  if ($null -eq $result) {
    throw "No matching group returned for display name '$GroupName'."
  }
  $groups = @($result)
  if ($groups.Count -gt 1) {
    Write-Warning "Multiple groups matched display name '$GroupName'; using first (object id $($groups[0].Id))."
  }
  $id = $groups[0].Id
  Write-Host "Resolved group '$GroupName' to object ID: $id"
  Write-Host "##vso[task.setvariable variable=$OutputVariableName]$id"
} catch {
  if ($IfNotFound -eq 'Error') {
    throw "Could not resolve Entra group '$GroupName': $_"
  }
  Write-Host "##vso[task.logissue type=warning]Could not resolve AD group '$GroupName': $_"
  Write-Host "##vso[task.setvariable variable=$OutputVariableName]"
}
