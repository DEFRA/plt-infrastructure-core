<#
.SYNOPSIS
  Resolves an Entra group display name to object ID for VNet join RBAC.
#>
param(
  [Parameter(Mandatory = $false)][string]$GroupName = ''
)

& "$PSScriptRoot/Resolve-EntraGroupByDisplayName.ps1" -GroupName $GroupName -OutputVariableName 'networkJoinGroupObjectId' -IfNotFound 'Warn'
