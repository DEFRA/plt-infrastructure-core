<#
.SYNOPSIS
  Invokes Add-AdAppRegistrations when an instance manifest exists.

.DESCRIPTION
  Skips when app-registration.json is absent (same optional-manifest pattern as AAD groups).
  Graph is authenticated with the same entra SP client id/secret as Create-AADGroups.
  Replaces #{{ token }} placeholders with pipeline variables.
#>
param(
  [Parameter(Mandatory = $true)][string]$ManifestPath,
  [Parameter(Mandatory = $true)][string]$ScriptPath,
  [Parameter(Mandatory = $true)][string]$ClientId,
  [Parameter(Mandatory = $true)][string]$TenantId,
  [Parameter(Mandatory = $true)][string]$ClientSecret,
  [Parameter()][bool]$FederatedCredential = $false
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ManifestPath)) {
  Write-Host "No app-registration.json at $ManifestPath; skipping App Registrations."
  exit 0
}

function Get-VariableValue {
  param([string]$Name)
  $val = [Environment]::GetEnvironmentVariable($Name, 'Process')
  if ($null -ne $val -and $val -ne '') { return $val }
  $val = [Environment]::GetEnvironmentVariable($Name.ToUpperInvariant(), 'Process')
  if ($null -ne $val -and $val -ne '') { return $val }
  $alt = $Name.ToUpperInvariant().Replace('.', '_')
  $val = [Environment]::GetEnvironmentVariable($alt, 'Process')
  if ($null -ne $val) { return $val }
  return ''
}

$content = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8
$pattern = [regex]::Escape('#{{') + '\s*([\w\.]+)\s*' + [regex]::Escape('}}')
$replaced = [regex]::Replace($content, $pattern, {
  param($m)
  return (Get-VariableValue -Name $m.Groups[1].Value)
})

$workingCopy = Join-Path ([System.IO.Path]::GetTempPath()) ("app-registration-" + [guid]::NewGuid().ToString() + ".json")
[System.IO.File]::WriteAllText($workingCopy, $replaced, [System.Text.UTF8Encoding]::new($false))
Write-Host "Processed manifest written to $workingCopy"

Write-Host "Authenticating to Microsoft Graph using SPN credentials (same identity as Create-AADGroups)..."
$tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
$tokenBody = @{
  client_id     = $ClientId
  client_secret = $ClientSecret
  grant_type    = 'client_credentials'
  scope         = 'https://graph.microsoft.com/.default'
}
try {
  $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenUrl -Body $tokenBody -ContentType 'application/x-www-form-urlencoded'
}
catch {
  $detail = $_.ErrorDetails.Message
  if (-not $detail) { $detail = $_.Exception.Message }
  throw "Graph client-secret auth failed for ClientId $ClientId : $detail"
}
$env:PLAT_GRAPH_ACCESS_TOKEN = $tokenResponse.access_token
$env:PLAT_GRAPH_CLIENT_ID = $ClientId
Write-Host "Graph token acquired for ClientId $ClientId"

& $ScriptPath -AppRegJsonPath $workingCopy -federatedCredential $FederatedCredential
