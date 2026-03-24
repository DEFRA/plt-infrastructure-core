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
  # Set by resolve-app-rg-contributor-group (Get-AzADGroup + SSV); preferred over ARM-only az ad lookup.
  [string]$AppRgContributorObjectId = '',
  [string]$AdGroupObjectId = '',
  [Parameter(Mandatory = $true)][string]$ServiceCode,
  [Parameter(Mandatory = $true)][string]$DeploymentEnvInstance,
  [Parameter(Mandatory = $true)][string]$RegionCode,
  [Parameter(Mandatory = $true)][string]$InstanceNumber,
  [string]$PlatformResourceGroups = '',
  [string]$InfraResourceGroupName = ''
)

$ErrorActionPreference = 'Stop'

function Write-PltDebug {
  param([string]$Message)
  Write-Host "[Create-PlatformResourceGroups] DEBUG: $Message"
}

$tempDir = if ($env:TEMP) { $env:TEMP } elseif ($env:AGENT_TEMPDIRECTORY) { $env:AGENT_TEMPDIRECTORY } else { '/tmp' }
$root = $RootPath
if (-not (Test-Path (Join-Path $root "resources"))) { $root = Join-Path $RootPath "self" }

if (-not $SubType -or -not $Location) {
  throw 'Required config values missing: subType, location.'
}

# Prefer object id from resolve-app-rg-contributor-group (Get-AzADGroup + SSV, same as networkJoinGroupName).
# ARM-only Azure CLI often lacks Graph directory read. Then legacy adGroupObjectId; then az/Graph fallback for display name.
$resolvedAdGroupObjectId = ''
if (-not [string]::IsNullOrWhiteSpace($AppRgContributorObjectId)) {
  $resolvedAdGroupObjectId = $AppRgContributorObjectId.Trim()
  Write-PltDebug "Using AppRgContributorObjectId from pipeline (SSV Get-AzADGroup resolve): $resolvedAdGroupObjectId"
}
elseif (-not [string]::IsNullOrWhiteSpace($AdGroupObjectId)) {
  $resolvedAdGroupObjectId = $AdGroupObjectId.Trim()
  Write-PltDebug "Using AdGroupObjectId parameter: $resolvedAdGroupObjectId"
}
elseif (-not [string]::IsNullOrWhiteSpace($AppRgContributor)) {
  $acctJson = az account show -o json 2>$null | ConvertFrom-Json
  Write-PltDebug "Azure CLI context: tenant=$($acctJson.tenantId) subscription=$($acctJson.id) name=$($acctJson.name) identity=$($acctJson.user.name)"
  Write-PltDebug "Resolving AppRgContributor (display name) via Azure CLI fallback: '$AppRgContributor'"

  # `az ad group list --display-name` is prefix-based and often misses exact names. Prefer OData exact match.
  $nameEscaped = $AppRgContributor -replace "'", "''"
  $resolvedAdGroupObjectId = az ad group list --filter "displayName eq '$nameEscaped'" --query "[0].id" -o tsv 2>$null
  if ([string]::IsNullOrWhiteSpace($resolvedAdGroupObjectId)) {
    Write-PltDebug "Attempt 1 (az ad group list --filter exact displayName): no match"
  } else {
    Write-PltDebug "Attempt 1 (az ad group list --filter exact displayName): objectId=$resolvedAdGroupObjectId"
  }
  if ([string]::IsNullOrWhiteSpace($resolvedAdGroupObjectId)) {
    $resolvedAdGroupObjectId = az ad group list --display-name "$AppRgContributor" --query "[0].id" -o tsv 2>$null
    if ([string]::IsNullOrWhiteSpace($resolvedAdGroupObjectId)) {
      Write-PltDebug "Attempt 2 (az ad group list --display-name prefix): no match"
    } else {
      Write-PltDebug "Attempt 2 (az ad group list --display-name prefix): objectId=$resolvedAdGroupObjectId"
    }
  }
  if ([string]::IsNullOrWhiteSpace($resolvedAdGroupObjectId)) {
    $filterParam = "displayName eq '$nameEscaped'"
    $encoded = [uri]::EscapeDataString($filterParam)
    $graphUrl = "https://graph.microsoft.com/v1.0/groups?`$filter=$encoded"
    Write-PltDebug "Attempt 3 (Microsoft Graph groups `$filter): $filterParam"
    $resolvedAdGroupObjectId = az rest --method GET --url $graphUrl --headers "ConsistencyLevel=eventual" --query "value[0].id" -o tsv 2>$null
    if ([string]::IsNullOrWhiteSpace($resolvedAdGroupObjectId)) {
      Write-PltDebug "Attempt 3 (Microsoft Graph): no match (check Graph permissions and exact display name)"
    } else {
      Write-PltDebug "Attempt 3 (Microsoft Graph): objectId=$resolvedAdGroupObjectId"
    }
  }
  if ([string]::IsNullOrWhiteSpace($resolvedAdGroupObjectId)) {
    throw @"
Could not resolve appRgContributor group '$AppRgContributor' to an Entra object ID.
Prefer running resolve-app-rg-contributor-group (Get-AzADGroup + SSV). If using CLI only, check exact display name and Directory.Read.All (or Group.Read.All) on the ARM identity.
"@
  }
}
if ([string]::IsNullOrWhiteSpace($resolvedAdGroupObjectId)) {
  throw 'Required config missing: appRgContributor + pipeline resolve, or adGroupObjectId (fallback).'
}
Write-PltDebug "Using Entra group object id for RBAC: $resolvedAdGroupObjectId"

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
