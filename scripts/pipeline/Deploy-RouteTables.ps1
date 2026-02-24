<#
.SYNOPSIS
  Deploys route tables from numbered templates. Route table 1 (default) is always deployed.
  Any alternative route tables referenced in config (subnetNRouteTable) are deployed dynamically.
  Prefers .transformed.parameters.json from framework; if missing, replaces tokens in .parameters.json here and writes .transformed.parameters.json.
  Subnet count is derived from the VNet template for the given SubnetLayout.
#>
param(
  [string]$BuildSourcesDirectory,
  [string]$ResourceGroupName,
  [string]$RouteTableName,
  [string]$Location,
  [string]$FirewallVirtualApplianceIp = '',
  [string]$SubnetLayout = '1'
)

$ErrorActionPreference = 'Stop'

function Get-TokenValue {
  param([string]$Name, [hashtable]$Overrides)
  if ($Overrides -and $Overrides.ContainsKey($Name)) { return $Overrides[$Name] }
  $v = [Environment]::GetEnvironmentVariable($Name, 'Process')
  if ($null -ne $v) { return $v }
  $v = [Environment]::GetEnvironmentVariable($Name.ToUpperInvariant(), 'Process')
  if ($null -ne $v) { return $v }
  $v = [Environment]::GetEnvironmentVariable($Name.ToUpperInvariant().Replace('.', '_'), 'Process')
  if ($null -ne $v) { return $v }
  return ''
}

function Escape-JsonString {
  param([string]$s)
  if ($null -eq $s) { return '' }
  $s.ToString() -replace '\\', '\\\\' -replace '"', '\"'
}

function New-TransformedParametersFile {
  param([string]$ParamFile, [string]$OutFile, [hashtable]$TokenOverrides = @{})
  $content = Get-Content -LiteralPath $ParamFile -Raw -Encoding UTF8
  foreach ($key in $TokenOverrides.Keys) {
    $val = Escape-JsonString -s $TokenOverrides[$key]
    $content = $content.Replace("#{{ $key }}", $val)
  }
  $content = [regex]::Replace($content, '#\{\{\s*([\w\.]+)\s*\}\}#', {
    param($m)
    $name = $m.Groups[1].Value
    $val = Get-TokenValue -Name $name -Overrides $TokenOverrides
    Escape-JsonString -s $val
  })
  [System.IO.File]::WriteAllText($OutFile, $content, [System.Text.UTF8Encoding]::new($false))
}

$routeTablePath = Join-Path $BuildSourcesDirectory "resources/network/route-table"
if (-not (Test-Path $routeTablePath)) {
  $routeTablePath = Join-Path $BuildSourcesDirectory "self/resources/network/route-table"
}
$templateFile = Join-Path $routeTablePath "route-table.bicep"
if (-not (Test-Path $templateFile)) { Write-Error "Template not found: $templateFile" }

# Derive subnet count from VNet template for the selected layout
$vnetParamsPath = Join-Path $BuildSourcesDirectory "resources/network/vnet/$SubnetLayout/virtual-network.parameters.json"
if (-not (Test-Path $vnetParamsPath)) {
  $vnetParamsPath = Join-Path $BuildSourcesDirectory "self/resources/network/vnet/$SubnetLayout/virtual-network.parameters.json"
}
$SubnetCount = 1
if (Test-Path $vnetParamsPath) {
  try {
    $vnetJson = Get-Content -LiteralPath $vnetParamsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $subnets = $vnetJson.parameters.subnets.value
    if ($subnets -is [Array]) { $SubnetCount = $subnets.Count }
    elseif ($subnets) { $SubnetCount = 1 }
  } catch {
    Write-Warning "Could not read subnet count from $vnetParamsPath : $_"
  }
}
Write-Host "##vso[task.setvariable variable=subnetCount]$SubnetCount"

# 1 is default and always deployed; add any alternative numbers referenced by subnets (subnet1RouteTable .. subnetNRouteTable)
$referenced = [System.Collections.Generic.HashSet[int]]::new()
[void]$referenced.Add(1)
foreach ($i in 1..$SubnetCount) {
  $v = (Get-Item -Path "Env:SUBNET${i}ROUTETABLE" -ErrorAction SilentlyContinue).Value
  if (-not [string]::IsNullOrWhiteSpace($v)) {
    $n = [int]$v
    if ($n -gt 0) { [void]$referenced.Add($n) }
  }
}
$toDeploy = $referenced | Sort-Object
Write-Host "Route tables to deploy (from config): $($toDeploy -join ', ')"

$subscriptionId = (az account show --query id -o tsv 2>$null)
if (-not $subscriptionId) { Write-Error "Could not get subscription ID" }

foreach ($n in $toDeploy) {
  $paramDir = Join-Path $routeTablePath $n
  $paramFile = Join-Path $paramDir "route-table.parameters.json"
  $transformed = Join-Path $paramDir "route-table.transformed.parameters.json"

  if (-not (Test-Path $paramFile)) {
    Write-Warning "Parameter file not found: $paramFile; skipping route table $n"
    continue
  }

  if (Test-Path $transformed) {
    $paramsToUse = $transformed
  } else {
    Write-Host "Creating $transformed from $paramFile (replacing #{{ tokens }} with pipeline variables)."
    $overrides = @{}
    if (-not [string]::IsNullOrWhiteSpace($Location)) { $overrides['location'] = $Location }
    if (-not [string]::IsNullOrWhiteSpace($RouteTableName)) { $overrides['routeTableName'] = $RouteTableName }
    if (-not [string]::IsNullOrWhiteSpace($FirewallVirtualApplianceIp)) { $overrides['firewallVirtualApplianceIp'] = $FirewallVirtualApplianceIp }
    if (-not $overrides.ContainsKey('location')) {
      $loc = [Environment]::GetEnvironmentVariable('location', 'Process')
      if ([string]::IsNullOrEmpty($loc)) { $loc = [Environment]::GetEnvironmentVariable('LOCATION', 'Process') }
      $overrides['location'] = if ($loc) { $loc } else { '' }
    }
    if (-not $overrides.ContainsKey('routeTableName')) {
      $rt = [Environment]::GetEnvironmentVariable('routeTableName', 'Process')
      if ([string]::IsNullOrEmpty($rt)) { $rt = [Environment]::GetEnvironmentVariable('ROUTETABLENAME', 'Process') }
      $overrides['routeTableName'] = if ($rt) { $rt } else { '' }
    }
    if (-not $overrides.ContainsKey('firewallVirtualApplianceIp')) {
      $fw = [Environment]::GetEnvironmentVariable('firewallVirtualApplianceIp', 'Process')
      if ([string]::IsNullOrEmpty($fw)) { $fw = [Environment]::GetEnvironmentVariable('FIREWALLVIRTUALAPPLIANCEIP', 'Process') }
      $overrides['firewallVirtualApplianceIp'] = if ($fw) { $fw } else { '' }
    }
    New-TransformedParametersFile -ParamFile $paramFile -OutFile $transformed -TokenOverrides $overrides
    $paramsToUse = $transformed
  }

  $suffix = $n.ToString("00")
  Write-Host "Deploying route table $suffix from template $n..."
  az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file $templateFile `
    --parameters $paramsToUse `
    --name "route-table-${suffix}-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
    --output none
  if ($LASTEXITCODE -ne 0) { throw "Route table $suffix deployment failed." }

  $rtName = "${RouteTableName}${suffix}"
  $resourceId = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/routeTables/$rtName"
  Write-Host "##vso[task.setvariable variable=routeTable${suffix}ResourceId]$resourceId"
}

Write-Host "Route table deployment(s) completed."
