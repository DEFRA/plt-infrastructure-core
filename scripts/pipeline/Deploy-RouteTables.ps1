<#
.SYNOPSIS
  Deploys route tables from numbered templates. Route table 1 (default) is always deployed.
  Any alternative route tables referenced in config (subnetNRouteTable) are deployed dynamically.
  Prefers .transformed.parameters.json from framework; if missing, replaces tokens in .parameters.json here and writes .transformed.parameters.json.
#>
param(
  [string]$BuildSourcesDirectory,
  [string]$ResourceGroupName,
  [string]$RouteTableName,
  [string]$Location,
  [int]$SubnetCount = 0
)

$ErrorActionPreference = 'Stop'

function Get-TokenValue {
  param([string]$Name)
  $v = [Environment]::GetEnvironmentVariable($Name, 'Process')
  if ($null -ne $v) { return $v }
  $v = [Environment]::GetEnvironmentVariable($Name.ToUpperInvariant(), 'Process')
  if ($null -ne $v) { return $v }
  $v = [Environment]::GetEnvironmentVariable($Name.ToUpperInvariant().Replace('.', '_'), 'Process')
  if ($null -ne $v) { return $v }
  return ''
}

function New-TransformedParametersFile {
  param([string]$ParamFile, [string]$OutFile)
  $content = Get-Content -LiteralPath $ParamFile -Raw -Encoding UTF8
  $content = [regex]::Replace($content, '#\{\{\s*([\w\.]+)\s*\}\}#', {
    param($m)
    $val = Get-TokenValue -Name $m.Groups[1].Value
    $val -replace '\\', '\\\\' -replace '"', '\"'
  })
  [System.IO.File]::WriteAllText($OutFile, $content, [System.Text.UTF8Encoding]::new($false))
}

$routeTablePath = Join-Path $BuildSourcesDirectory "resources/network/route-table"
if (-not (Test-Path $routeTablePath)) {
  $routeTablePath = Join-Path $BuildSourcesDirectory "self/resources/network/route-table"
}
$templateFile = Join-Path $routeTablePath "route-table.bicep"
if (-not (Test-Path $templateFile)) { Write-Error "Template not found: $templateFile" }

# Subnet count from parameter or env (config: subnetCount); default 7 for backwards compatibility
if ($SubnetCount -lt 1) {
  $SubnetCount = [int](Get-Item -Path "Env:SUBNETCOUNT" -ErrorAction SilentlyContinue).Value
  if (-not $SubnetCount -or $SubnetCount -lt 1) { $SubnetCount = 7 }
}
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
    New-TransformedParametersFile -ParamFile $paramFile -OutFile $transformed
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
