<#
.SYNOPSIS
  Normalises applicationID to upper/lower variants for downstream token replacement.
#>
param(
  [string]$ApplicationId = ''
)

$ErrorActionPreference = 'Stop'

$applicationIdUpper = $ApplicationId.ToUpperInvariant()
$applicationIdLower = $ApplicationId.ToLowerInvariant()

Write-Host "##vso[task.setvariable variable=applicationID]$applicationIdUpper"
Write-Host "##vso[task.setvariable variable=applicationIDLower]$applicationIdLower"
Write-Host "Normalised applicationID to $applicationIdUpper, applicationIDLower to $applicationIdLower"
