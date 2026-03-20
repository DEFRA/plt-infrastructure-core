<#
.SYNOPSIS
  Deploys NSGs from numbered templates based on per-subnet config (subnetNsgLayout).

  Core contract:
    - subnetNsgLayout is resolved per subnet
    - omitted/blank => defaults to NSG layout 1
    - '0' => no NSG for that subnet
  We deploy only the distinct NSG layouts that are required by the resolved subnet config.
#>
param(
  [string]$BuildSourcesDirectory,
  [string]$ResourceGroupName,
  [string]$SubnetLayout = '1',
  [string]$Location = '',
  [string]$SubType = '',
  [string]$ServiceCode = '',
  [string]$DeploymentEnvInstance = '',
  [string]$RegionCode = ''
)

$ErrorActionPreference = 'Stop'

function Get-EnvValue {
  param([string]$Name)
  return [Environment]::GetEnvironmentVariable($Name, 'Process')
}

# Derive subnet count from VNet template for the given SubnetLayout.
$vnetParamsPath = Join-Path $BuildSourcesDirectory "resources/network/vnet/$SubnetLayout/virtual-network.parameters.json"
if (-not (Test-Path $vnetParamsPath)) {
  $vnetParamsPath = Join-Path $BuildSourcesDirectory "self/resources/network/vnet/$SubnetLayout/virtual-network.parameters.json"
}

$subnetCount = 1
if (Test-Path $vnetParamsPath) {
  $content = Get-Content -LiteralPath $vnetParamsPath -Raw -Encoding UTF8
  $matches = [regex]::Matches($content, 'subnet\d+AddressPrefix')
  if ($matches.Count -gt 0) { $subnetCount = $matches.Count }
}

Write-Host "NSG deployment: subnet count for subnetLayout=$SubnetLayout is $subnetCount"

$nsgPath = Join-Path $BuildSourcesDirectory "resources/network/nsg"
if (-not (Test-Path $nsgPath)) {
  $nsgPath = Join-Path $BuildSourcesDirectory "self/resources/network/nsg"
}

$templateFile = Join-Path $nsgPath "network-security-group.bicep"
if (-not (Test-Path $templateFile)) { throw "NSG template not found: $templateFile" }

$replaceTokensScript = Join-Path $BuildSourcesDirectory "scripts/pipeline/Replace-Tokens.ps1"
if (-not (Test-Path $replaceTokensScript)) { $replaceTokensScript = Join-Path $BuildSourcesDirectory "self/scripts/pipeline/Replace-Tokens.ps1" }

$layoutsToDeploy = [System.Collections.Generic.HashSet[int]]::new()

for ($i = 1; $i -le $subnetCount; $i++) {
  # Prefer the canonical env-var name derived from core.yaml key casing, but keep fallbacks.
  $v = Get-EnvValue ("SUBNET${i}NSGLAYOUT")
  if ([string]::IsNullOrWhiteSpace($v)) {
    $v = Get-EnvValue ("subnet${i}NsgLayout")
  }
  if ([string]::IsNullOrWhiteSpace($v)) {
    $v = Get-EnvValue ("subnet${i}NSGLAYOUT")
  }
  if ([string]::IsNullOrWhiteSpace($v)) {
    $v = Get-EnvValue ("subnet${i}nsglayout")
  }
  if ([string]::IsNullOrWhiteSpace($v)) {
    # Omitted/blank => default to NSG layout 1.
    $v = '1'
  }

  $n = 0
  if (-not [int]::TryParse($v, [ref]$n)) {
    Write-Warning "Could not parse subnet${i}NsgLayout value '$v' as int; defaulting to 1"
    $n = 1
  }

  if ($n -gt 0) { [void]$layoutsToDeploy.Add($n) }
}

$toDeploy = $layoutsToDeploy | Sort-Object
if ($toDeploy.Count -eq 0) {
  Write-Host "No NSG layouts referenced by subnet config; skipping NSG deployment."
  exit 0
}

Write-Host "NSG layouts to deploy: $($toDeploy -join ', ')"

$subType = if (-not [string]::IsNullOrWhiteSpace($SubType)) { $SubType } else { Get-EnvValue 'subType' }
$serviceCode = if (-not [string]::IsNullOrWhiteSpace($ServiceCode)) { $ServiceCode } else { Get-EnvValue 'serviceCode' }
$deploymentEnvInstance = if (-not [string]::IsNullOrWhiteSpace($DeploymentEnvInstance)) { $DeploymentEnvInstance } else { Get-EnvValue 'deploymentEnvInstance' }
$regionCode = if (-not [string]::IsNullOrWhiteSpace($RegionCode)) { $RegionCode } else { Get-EnvValue 'regionCode' }
$locationForNamingDeployment = if (-not [string]::IsNullOrWhiteSpace($Location)) { $Location } else { Get-EnvValue 'location' }

if ([string]::IsNullOrWhiteSpace($locationForNamingDeployment)) {
  throw "Missing location for naming deployment. Pass -Location from the pipeline (e.g. -Location '$(location)')."
}

if ([string]::IsNullOrWhiteSpace($subType) -or [string]::IsNullOrWhiteSpace($serviceCode) -or [string]::IsNullOrWhiteSpace($deploymentEnvInstance) -or [string]::IsNullOrWhiteSpace($regionCode)) {
  throw "Missing required naming variables for NSG name: subType/serviceCode/deploymentEnvInstance/regionCode"
}

foreach ($layout in $toDeploy) {
  $paramDir = Join-Path $nsgPath $layout
  $paramFile = Join-Path $paramDir "network-security-group.parameters.json"
  $transformedFile = Join-Path $paramDir "network-security-group.transformed.parameters.json"

  if (-not (Test-Path $paramFile)) {
    throw "NSG parameter file not found for layout ${layout}: $paramFile"
  }

  # Always generate transformed parameters so `nsgResourceName` is correct for this deployment.
  if (-not (Test-Path $replaceTokensScript)) { throw "Replace-Tokens.ps1 not found: $replaceTokensScript" }

  $instanceNumber = $layout.ToString("00")

  # Use the naming module to derive the NSG name (keeps it consistent with route tables).
  # Pattern:
  #   <subType><svc><role=NET><resType=NSG><deploymentEnvInstance><regionCode><instanceNumber>
  $root = $BuildSourcesDirectory
  if (-not (Test-Path (Join-Path $root "resources"))) { $root = "$(Build.SourcesDirectory)" }
  if (-not (Test-Path (Join-Path $root "resources"))) { $root = "$BuildSourcesDirectory/self" }
  $namingFile = Join-Path $root "resources/naming-convention/naming-convention.bicep"
  if (-not (Test-Path $namingFile)) { $namingFile = Join-Path $root "self/resources/naming-convention/naming-convention.bicep" }
  if (-not (Test-Path $namingFile)) { throw "naming-convention.bicep not found near $root" }

  $tempDir = if ($env:TEMP) { $env:TEMP } elseif ($env:AGENT_TEMPDIRECTORY) { $env:AGENT_TEMPDIRECTORY } else { '/tmp' }
  $namingDeploymentName = "nsg-name-${instanceNumber}-$(Get-Date -Format 'yyyyMMdd-HHmmss')" -replace '[^a-zA-Z0-9._-]', '-'
  $paramsPath = Join-Path $tempDir "naming-params-nsg-${instanceNumber}-$(Get-Date -Format 'yyyyMMddHHmmss').json"
  $namingParams = @{
    subType = @{ value = $subType }
    svc = @{ value = $serviceCode }
    role = @{ value = 'NET' }
    resType = @{ value = 'NSG' }
    deploymentEnvInstance = @{ value = $deploymentEnvInstance }
    regionCode = @{ value = $regionCode }
    instanceNumber = @{ value = $instanceNumber }
    toLower = @{ value = $false }
  }
  @{ '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'; contentVersion = '1.0.0.0'; parameters = $namingParams } |
    ConvertTo-Json -Depth 6 |
    Set-Content -Path $paramsPath -Encoding utf8

  az deployment sub create `
    --name $namingDeploymentName `
    --location $locationForNamingDeployment `
    --template-file $namingFile `
    --parameters $paramsPath `
    --output none

  if ($LASTEXITCODE -ne 0) { throw "Naming module deployment failed for NSG layout $layout" }

  $derivedNsgName = az deployment sub show --name $namingDeploymentName --query "properties.outputs.name.value" -o tsv
  if ([string]::IsNullOrWhiteSpace($derivedNsgName)) { throw "Naming module returned empty NSG name for layout $layout" }

  $env:nsgResourceName = $derivedNsgName

  & $replaceTokensScript -Paths $paramDir
  if ($LASTEXITCODE -ne 0) { throw "Replace-Tokens failed for NSG layout $layout" }

  $suffix = $layout.ToString("00")
  $deploymentName = "nsg-${suffix}-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
  Write-Host "Deploying NSG layout $layout from $templateFile to RG=$ResourceGroupName"
  az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file $templateFile `
    --parameters $transformedFile `
    --name $deploymentName `
    --output none

  if ($LASTEXITCODE -ne 0) { throw "NSG layout $layout deployment failed." }
}

Write-Host "NSG deployment(s) completed."

