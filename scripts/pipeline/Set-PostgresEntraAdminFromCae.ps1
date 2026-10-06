<#
.SYNOPSIS
  Sets pipeline variables for PostgreSQL Flexible Server Entra admins (optional CAE MI).
#>
param(
  [Parameter(Mandatory = $true)][string]$ResourceGroupName,
  [Parameter(Mandatory = $false)][string]$ContainerAppsEnvironmentName = ''
)

$ErrorActionPreference = 'Stop'

# Defaults: empty admin object (bicep skips CAE admin when objectId is blank)
Write-Host "##vso[task.setvariable variable=postgresCaeEntraAdminObjectId]"
Write-Host "##vso[task.setvariable variable=postgresCaeEntraAdminPrincipalName]"

if ([string]::IsNullOrWhiteSpace($ContainerAppsEnvironmentName)) {
  Write-Host "No Container Apps Environment name — Postgres Entra admin will be the platform UAMI only."
  exit 0
}

$identity = az containerapp env show -n $ContainerAppsEnvironmentName -g $ResourceGroupName --query identity -o json 2>$null
if (-not $identity) {
  Write-Host "CAE '$ContainerAppsEnvironmentName' not found or has no identity — UAMI-only Entra admin."
  exit 0
}

$obj = $identity | ConvertFrom-Json
$principalId = $obj.principalId
if ([string]::IsNullOrWhiteSpace($principalId)) {
  Write-Host "CAE has no system-assigned principalId — UAMI-only Entra admin."
  exit 0
}

Write-Host "CAE Entra admin principalId: $principalId"
Write-Host "##vso[task.setvariable variable=postgresCaeEntraAdminObjectId]$principalId"
Write-Host "##vso[task.setvariable variable=postgresCaeEntraAdminPrincipalName]$ContainerAppsEnvironmentName"
