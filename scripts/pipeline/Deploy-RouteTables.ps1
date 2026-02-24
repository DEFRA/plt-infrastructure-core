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
  [string]$FirewallVirtualApplianceIp = '',
  [int]$SubnetCount = 0
)

$ErrorActionPreference = 'Stop'
$DebugPrefix = '[Deploy-RouteTables.DEBUG]'

Write-Host "$DebugPrefix === SCRIPT PARAMS ==="
Write-Host "$DebugPrefix BuildSourcesDirectory = '$BuildSourcesDirectory'"
Write-Host "$DebugPrefix ResourceGroupName      = '$ResourceGroupName'"
Write-Host "$DebugPrefix RouteTableName         = '$RouteTableName' (length=$($RouteTableName.Length))"
Write-Host "$DebugPrefix Location              = '$Location' (length=$($Location.Length))"
Write-Host "$DebugPrefix FirewallVirtualApplianceIp = '$FirewallVirtualApplianceIp' (length=$($FirewallVirtualApplianceIp.Length))"
Write-Host "$DebugPrefix SubnetCount           = $SubnetCount"

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
  Write-Host "$DebugPrefix New-TransformedParametersFile: ParamFile='$ParamFile' OutFile='$OutFile'"
  Write-Host "$DebugPrefix TokenOverrides keys: $($TokenOverrides.Keys -join ', ')"

  $content = Get-Content -LiteralPath $ParamFile -Raw -Encoding UTF8
  Write-Host "$DebugPrefix Source file length: $($content.Length) chars"

  # Debug: what token strings actually exist in the file (exact bytes matter)
  $tokenPattern = '#\{\{\s*[\w\.]+\s*\}\}'
  $matches = [regex]::Matches($content, $tokenPattern)
  Write-Host "$DebugPrefix Tokens found in file (regex): $($matches.Count)"
  foreach ($m in $matches) {
    $exact = $m.Value
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($exact)
    Write-Host "$DebugPrefix   token='$exact' (length=$($exact.Length) bytes=$($bytes -join ','))"
  }

  # Replace known tokens from overrides (script params) with explicit .Replace so values are used
  foreach ($key in $TokenOverrides.Keys) {
    $search = "#{{ $key }}"
    $rawVal = $TokenOverrides[$key]
    $val = Escape-JsonString -s $rawVal
    $foundBefore = $content.Contains($search)
    Write-Host "$DebugPrefix Replace key='$key' search='$search' found=$foundBefore rawValue='$rawVal' escapedValue='$val'"
    $content = $content.Replace($search, $val)
    $foundAfter = $content.Contains($search)
    if ($foundBefore -and $foundAfter) { Write-Host "$DebugPrefix   WARNING: token still present after Replace (no change)" }
  }

  Write-Host "$DebugPrefix After overrides: content contains '#{{ location }}' = $($content.Contains('#{{ location }}'))"
  Write-Host "$DebugPrefix After overrides: content contains '#{{ routeTableName }}' = $($content.Contains('#{{ routeTableName }}'))"
  Write-Host "$DebugPrefix After overrides: content contains '#{{ firewallVirtualApplianceIp }}' = $($content.Contains('#{{ firewallVirtualApplianceIp }}'))"

  # Replace any remaining #{{ token }} with env/overrides
  $content = [regex]::Replace($content, '#\{\{\s*([\w\.]+)\s*\}\}#', {
    param($m)
    $name = $m.Groups[1].Value
    $val = Get-TokenValue -Name $name -Overrides $TokenOverrides
    Escape-JsonString -s $val
  })

  Write-Host "$DebugPrefix After regex pass: content contains '#{{ location }}' = $($content.Contains('#{{ location }}'))"
  Write-Host "$DebugPrefix Writing to: $OutFile"

  # Show snippet of content that should contain location (for verification)
  if ($content -match '"location"\s*:\s*"([^"]*)"') {
    Write-Host "$DebugPrefix Snippet location value in output: '$($Matches[1])'"
  }

  [System.IO.File]::WriteAllText($OutFile, $content, [System.Text.UTF8Encoding]::new($false))
  Write-Host "$DebugPrefix Written. Verifying: file on disk contains '#{{ location }}' = $((Get-Content -LiteralPath $OutFile -Raw).Contains('#{{ location }}'))"
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
    Write-Host "$DebugPrefix Using existing transformed file: $paramsToUse"
  } else {
    Write-Host "Creating $transformed from $paramFile (replacing #{{ tokens }} with pipeline variables)."
    $overrides = @{}
    if (-not [string]::IsNullOrWhiteSpace($Location)) { $overrides['location'] = $Location }
    if (-not [string]::IsNullOrWhiteSpace($RouteTableName)) { $overrides['routeTableName'] = $RouteTableName }
    if (-not [string]::IsNullOrWhiteSpace($FirewallVirtualApplianceIp)) { $overrides['firewallVirtualApplianceIp'] = $FirewallVirtualApplianceIp }
    # Fallback: pipeline may pass vars as env instead of args
    if (-not $overrides.ContainsKey('location')) {
      $loc = [Environment]::GetEnvironmentVariable('location', 'Process')
      if ([string]::IsNullOrEmpty($loc)) { $loc = [Environment]::GetEnvironmentVariable('LOCATION', 'Process') }
      $overrides['location'] = if ($loc) { $loc } else { '' }
      Write-Host "$DebugPrefix location from env: '$loc' -> overrides[location]='$($overrides['location'])'"
    }
    if (-not $overrides.ContainsKey('routeTableName')) {
      $rt = [Environment]::GetEnvironmentVariable('routeTableName', 'Process')
      if ([string]::IsNullOrEmpty($rt)) { $rt = [Environment]::GetEnvironmentVariable('ROUTETABLENAME', 'Process') }
      $overrides['routeTableName'] = if ($rt) { $rt } else { '' }
      Write-Host "$DebugPrefix routeTableName from env: '$rt' -> overrides[routeTableName]='$($overrides['routeTableName'])'"
    }
    if (-not $overrides.ContainsKey('firewallVirtualApplianceIp')) {
      $fw = [Environment]::GetEnvironmentVariable('firewallVirtualApplianceIp', 'Process')
      if ([string]::IsNullOrEmpty($fw)) { $fw = [Environment]::GetEnvironmentVariable('FIREWALLVIRTUALAPPLIANCEIP', 'Process') }
      $overrides['firewallVirtualApplianceIp'] = if ($fw) { $fw } else { '' }
      Write-Host "$DebugPrefix firewallVirtualApplianceIp from env: length=$(if ($fw) { $fw.Length } else { 0 }) -> overrides[firewallVirtualApplianceIp] length=$($overrides['firewallVirtualApplianceIp'].Length)"
    }
    Write-Host "$DebugPrefix Final overrides: location='$($overrides['location'])' routeTableName='$($overrides['routeTableName'])' firewallVirtualApplianceIp length=$($overrides['firewallVirtualApplianceIp'].Length)"
    New-TransformedParametersFile -ParamFile $paramFile -OutFile $transformed -TokenOverrides $overrides
    $paramsToUse = $transformed
  }

  $suffix = $n.ToString("00")
  Write-Host "$DebugPrefix About to deploy: paramsToUse=$paramsToUse (exists=$(Test-Path $paramsToUse))"
  $deployContent = Get-Content -LiteralPath $paramsToUse -Raw -ErrorAction SilentlyContinue
  if ($deployContent -match '"location"\s*:\s*"([^"]*)"') {
    Write-Host "$DebugPrefix File we will pass to az: location param = '$($Matches[1])'"
  }
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
