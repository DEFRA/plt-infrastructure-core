<#
.SYNOPSIS
  Adds a managed identity or service principal to an Entra group.

.DESCRIPTION
  Intended as a post-deploy step, once the resource identity exists in the directory.
  The group must already exist; create it in the instance aad-group.json manifest.
  Graph is authenticated with the same entra SP client id/secret as Create-AADGroups.
  Skips when either the group name or the principal id is empty, so callers can pass
  optional config values straight through.
#>
param(
  [Parameter(Mandatory = $false)][string]$GroupName = '',
  [Parameter(Mandatory = $false)][string]$PrincipalId = '',
  [Parameter(Mandatory = $true)][string]$ClientId,
  [Parameter(Mandatory = $true)][string]$TenantId,
  [Parameter(Mandatory = $true)][string]$ClientSecret
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($GroupName)) {
  Write-Host "No Entra group configured; skipping group membership."
  exit 0
}

if ([string]::IsNullOrWhiteSpace($PrincipalId)) {
  Write-Host "No principal id supplied; skipping group membership."
  exit 0
}

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
$headers = @{ Authorization = "Bearer $($tokenResponse.access_token)" }

$filterName = $GroupName.Replace("'", "''")
$groupUrl = "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$filterName'&`$select=id,displayName"
$groups = @((Invoke-RestMethod -Method Get -Uri $groupUrl -Headers $headers).value)
if ($groups.Count -eq 0) {
  throw "Entra group '$GroupName' does not exist. Add it to the instance aad-group.json manifest."
}
if ($groups.Count -gt 1) {
  Write-Warning "Multiple groups matched display name '$GroupName'; using first (object id $($groups[0].id))."
}
$groupId = $groups[0].id

Write-Host "Adding principal $PrincipalId as a member of '$GroupName' ($groupId)."
$memberUrl = "https://graph.microsoft.com/v1.0/groups/$groupId/members/`$ref"
$memberBody = @{ '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$PrincipalId" } | ConvertTo-Json
try {
  Invoke-RestMethod -Method Post -Uri $memberUrl -Headers $headers -Body $memberBody -ContentType 'application/json' | Out-Null
  Write-Host "Principal added to '$GroupName'."
}
catch {
  $detail = $_.ErrorDetails.Message
  if ($detail -and $detail -match 'already exist') {
    Write-Host "Principal is already a member of '$GroupName'."
    exit 0
  }
  if (-not $detail) { $detail = $_.Exception.Message }
  throw "Could not add principal $PrincipalId to '$GroupName': $detail"
}
