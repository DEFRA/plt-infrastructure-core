<#
.SYNOPSIS
  Validates pipeline parameters against runtime config values.

.DESCRIPTION
  Args:
    1 expected environmentName (pipeline parameter, e.g. snd4)
    2 config subType (e.g. SND)
    3 config deploymentEnvInstance (e.g. 4)
    4 expected location (pipeline parameter)
    5 actual location (resolved from config variables)
#>
param(
  [string]$ExpectedEnvironment = '',
  [string]$ConfigSubType = '',
  [string]$ConfigDeploymentEnvInstance = '',
  [string]$ExpectedLocation = '',
  [string]$ActualLocation = ''
)

$ErrorActionPreference = 'Stop'
$hasError = $false

$expEnv = $ExpectedEnvironment.ToLowerInvariant().Replace(' ', '')
$cfgSub = $ConfigSubType.ToLowerInvariant().Replace(' ', '')
$cfgInst = $ConfigDeploymentEnvInstance.ToLowerInvariant().Replace(' ', '')

# environmentName is a logical value (snd4), so compare it to config-derived subType+deploymentEnvInstance.
$cfgEnv = "$cfgSub$cfgInst"
if (-not [string]::IsNullOrWhiteSpace($expEnv) -and -not [string]::IsNullOrWhiteSpace($cfgEnv) -and $cfgEnv -ne $expEnv) {
  Write-Host "##vso[task.logissue type=error]Environment mismatch: pipeline parameter (environmentName=$expEnv) does not match config (subType+deploymentEnvInstance=$cfgEnv)."
  $hasError = $true
}

$expLoc = $ExpectedLocation.ToLowerInvariant().Replace(' ', '')
$actLoc = $ActualLocation.ToLowerInvariant().Replace(' ', '')
# Keep location validation as a direct parameter-vs-config check.
if (-not [string]::IsNullOrWhiteSpace($expLoc) -and $actLoc -ne $expLoc) {
  Write-Host "##vso[task.logissue type=error]Location mismatch: pipeline parameter (location=$expLoc) does not match config (location=$ActualLocation)."
  $hasError = $true
}

if ($hasError) { exit 1 }
Write-Host "Config validation passed: parameters match config."
