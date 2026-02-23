<#
.SYNOPSIS
  Deploys route tables from numbered templates. Route table 1 (default) is always deployed.
  Any alternative route tables referenced in config (subnetNRouteTable) are deployed dynamically.
  Uses framework-produced .transformed.parameters.json only (framework replace-tokens step must run first).
#>
param(
  [string]$BuildSourcesDirectory,
  [string]$ResourceGroupName,
  [string]$RouteTableName,
  [string]$Location,
  [int]$SubnetCount = 0
)

$ErrorActionPreference = 'Stop'
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

  if (-not (Test-Path $transformed)) {
    Write-Error "Transformed parameter file not found: $transformed (framework replace-tokens step must run first; no tokenisation in consumer pipeline)."
  }

  $suffix = $n.ToString("00")
  Write-Host "Deploying route table $suffix from template $n..."
  az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file $templateFile `
    --parameters $transformed `
    --name "route-table-${suffix}-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
    --output none
  if ($LASTEXITCODE -ne 0) { throw "Route table $suffix deployment failed." }

  $rtName = "${RouteTableName}${suffix}"
  $resourceId = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/routeTables/$rtName"
  Write-Host "##vso[task.setvariable variable=routeTable${suffix}ResourceId]$resourceId"
}

Write-Host "Route table deployment(s) completed."
