<#
.SYNOPSIS
  Creates INF (+ optional APP/EXP) resource groups and applies RBAC.

.DESCRIPTION
  Uses naming-convention output for each role, then deploys
  `resource-group-with-rbac.bicep` with a JSON parameter file (robust on Linux/Windows).
#>
param(
  [Parameter(Mandatory = $true)][string]$RootPath,
  [Parameter(Mandatory = $true)][string]$SubType,
  [Parameter(Mandatory = $true)][string]$Location,
  [string]$AppRgContributor = '',
  [string]$AdGroupObjectId = '',
  [Parameter(Mandatory = $true)][string]$ServiceCode,
  [Parameter(Mandatory = $true)][string]$DeploymentEnvInstance,
  [Parameter(Mandatory = $true)][string]$RegionCode,
  [Parameter(Mandatory = $true)][string]$InstanceNumber,
  [string]$PlatformResourceGroups = '',
  [string]$InfraResourceGroupName = ''
)

$ErrorActionPreference = 'Stop'

$tempDir = if ($env:TEMP) { $env:TEMP } elseif ($env:AGENT_TEMPDIRECTORY) { $env:AGENT_TEMPDIRECTORY } else { '/tmp' }
$root = $RootPath
if (-not (Test-Path (Join-Path $root "resources"))) { $root = Join-Path $RootPath "self" }

if (-not $SubType -or -not $Location) {
  throw 'Required config values missing: subType, location.'
}

# Prefer group-name driven config (appRgContributor). Keep adGroupObjectId as compatibility fallback.
$resolvedAdGroupObjectId = $AdGroupObjectId
if (-not [string]::IsNullOrWhiteSpace($AppRgContributor)) {
  $resolvedAdGroupObjectId = az ad group list --display-name "$AppRgContributor" --query "[0].id" -o tsv 2>$null
  if ([string]::IsNullOrWhiteSpace($resolvedAdGroupObjectId)) {
    throw "Could not resolve appRgContributor group '$AppRgContributor' to an Entra object ID."
  }
}
if ([string]::IsNullOrWhiteSpace($resolvedAdGroupObjectId)) {
  throw 'Required config missing: appRgContributor (preferred) or adGroupObjectId (fallback).'
}

$namingFile = Join-Path $root "resources/naming-convention/get-names.bicep"
if (-not (Test-Path $namingFile)) { $namingFile = Join-Path $root "self/resources/naming-convention/get-names.bicep" }
$bicepFile = Join-Path $root "resources/resource-group/resource-group-with-rbac.bicep"
if (-not (Test-Path $bicepFile)) { $bicepFile = Join-Path $root "self/resources/resource-group/resource-group-with-rbac.bicep" }

$roles = @('INF') + (($PlatformResourceGroups -split ',').Trim() | Where-Object { $_ })
foreach ($Role in $roles) {
  $resourceGroupName = $null
  if ($Role -eq 'INF' -and -not [string]::IsNullOrWhiteSpace($InfraResourceGroupName)) {
    $resourceGroupName = $InfraResourceGroupName
  } else {
    $namingDeploymentName = "get-names-rg-$Role-$(Get-Date -Format 'yyyyMMddHHmmss')" -replace '[^a-zA-Z0-9._-]', '-'
    $namingParams = @{
      subType = @{ value = $SubType }
      svc = @{ value = $ServiceCode }
      role = @{ value = $Role }
      deploymentEnvInstance = @{ value = $DeploymentEnvInstance }
      regionCode = @{ value = $RegionCode }
      instanceNumber = @{ value = $InstanceNumber }
    }
    $namingParamsPath = Join-Path $tempDir "get-names-rg-$Role-$(Get-Date -Format 'yyyyMMddHHmmss').json"
    @{ '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'; contentVersion = '1.0.0.0'; parameters = $namingParams } | ConvertTo-Json -Depth 4 | Set-Content -Path $namingParamsPath -Encoding utf8
    az deployment sub create --name $namingDeploymentName --location $Location --template-file $namingFile --parameters $namingParamsPath --output none
    if ($LASTEXITCODE -ne 0) { throw "Naming convention deployment failed for role $Role" }
    $resourceGroupName = az deployment sub show --name $namingDeploymentName --query "properties.outputs.resourceGroupName.value" -o tsv
  }

  if (-not $resourceGroupName) { throw "Could not get resourceGroupName for role $Role" }
  $rgDeploymentName = "rg-$Role-$(Get-Date -Format 'yyyyMMddHHmmss')" -replace '[^a-zA-Z0-9._-]', '-'
  $rgParams = @{
    name = @{ value = $resourceGroupName }
    location = @{ value = $Location }
    subType = @{ value = $SubType }
    adGroupObjectId = @{ value = $resolvedAdGroupObjectId }
    resourceGroupRole = @{ value = $Role }
  }
  $rgParamsPath = Join-Path $tempDir "rg-$Role-$(Get-Date -Format 'yyyyMMddHHmmss').json"
  @{ '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'; contentVersion = '1.0.0.0'; parameters = $rgParams } | ConvertTo-Json -Depth 4 | Set-Content -Path $rgParamsPath -Encoding utf8
  az deployment sub create --name $rgDeploymentName --location $Location --template-file $bicepFile --parameters $rgParamsPath --output none
  if ($LASTEXITCODE -ne 0) { throw "Resource group deployment failed for role $Role" }

  $resourceGroupNameOutput = az deployment sub show --name $rgDeploymentName --query "properties.outputs.resourceGroupName.value" -o tsv
  if ($Role -eq 'INF') { Write-Host "##vso[task.setvariable variable=virtualNetworkResourceGroup]$resourceGroupNameOutput" }
  if ($Role -eq 'APP') { Write-Host "##vso[task.setvariable variable=servicesResourceGroup]$resourceGroupNameOutput" }
}
