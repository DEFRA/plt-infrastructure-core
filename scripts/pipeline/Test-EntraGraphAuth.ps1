<#
.SYNOPSIS
  Prove the Graph client-secret auth step used by Create-AADGroups.ps1.

.DESCRIPTION
  Isolates the failing Connect-MgGraph -ClientSecretCredential call.
  Posts to the Entra token endpoint so the real AADSTS error is visible
  (Connect-MgGraph typically swallows it as "ClientSecretCredential authentication failed").

  Does not print the secret. Safe to run in ADO with $(entraSPClientId) / $(entraSPToken).

.EXAMPLE
  # Local (secret from Key Vault / password manager — Entra and ADO will not show it after save)
  ./Test-EntraGraphAuth.ps1 -ClientId '<app-id>' -TenantId '770a2450-0227-4c62-90c7-4e38537f1102' -ClientSecret $secret

.EXAMPLE
  # Same variables the pipeline uses (add as a temporary AzurePowerShell step)
  ./Test-EntraGraphAuth.ps1 -ClientId "$(entraSPClientId)" -TenantId "$(tenantId)" -ClientSecret "$(entraSPToken)"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ClientId,

    [Parameter(Mandatory)]
    [string]$TenantId,

    [Parameter(Mandatory)]
    [string]$ClientSecret,

    [Parameter()]
    [switch]$ConnectGraph
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Get-SecretShape {
    param([string]$Value)
    $trimmed = $Value.Trim()
    [pscustomobject]@{
        Length            = $Value.Length
        TrimmedLength     = $trimmed.Length
        HasLeadingSpace   = $Value.Length -gt 0 -and [char]::IsWhiteSpace($Value[0])
        HasTrailingSpace  = $Value.Length -gt 0 -and [char]::IsWhiteSpace($Value[-1])
        WrappedInQuotes   = ($trimmed.StartsWith('"') -and $trimmed.EndsWith('"')) -or
                            ($trimmed.StartsWith("'") -and $trimmed.EndsWith("'"))
        LooksEmpty        = [string]::IsNullOrWhiteSpace($Value)
    }
}

Write-Host "Test-EntraGraphAuth.ps1"
Write-Host "======================="
Write-Host "TenantId : $TenantId"
Write-Host "ClientId : $ClientId"
Write-Host "This is the Graph SP from variable group 'entra' (entraSPClientId / entraSPToken)."
Write-Host "It is NOT the SSV AzurePowerShell service connection that already logged in via OIDC."
Write-Host ""

$shape = Get-SecretShape -Value $ClientSecret
Write-Host "Secret shape (value not printed):"
Write-Host "  Length           : $($shape.Length)"
Write-Host "  Trimmed length   : $($shape.TrimmedLength)"
Write-Host "  Leading space    : $($shape.HasLeadingSpace)"
Write-Host "  Trailing space   : $($shape.HasTrailingSpace)"
Write-Host "  Wrapped in quotes: $($shape.WrappedInQuotes)"
Write-Host "  Empty / whitespace: $($shape.LooksEmpty)"

if ($shape.LooksEmpty) {
    throw "entraSPToken is empty. The ADO variable group secret is missing or not mapped into this job."
}

$tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
$body = @{
    client_id     = $ClientId
    client_secret = $ClientSecret
    grant_type    = 'client_credentials'
    scope         = 'https://graph.microsoft.com/.default'
}

Write-Host ""
Write-Host "Requesting Graph token from $tokenUrl ..."

try {
    $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenUrl -Body $body -ContentType 'application/x-www-form-urlencoded'
} catch {
    $status = $null
    $aadError = $null
    $aadDesc = $null
    $raw = $null

    if ($_.Exception.Response) {
        $status = [int]$_.Exception.Response.StatusCode
        try {
            $stream = $_.Exception.Response.GetResponseStream()
            if ($stream) {
                $reader = [System.IO.StreamReader]::new($stream)
                $raw = $reader.ReadToEnd()
                $reader.Dispose()
            }
        } catch { }

        if (-not $raw -and $_.ErrorDetails.Message) {
            $raw = $_.ErrorDetails.Message
        }

        if ($raw) {
            try {
                $errObj = $raw | ConvertFrom-Json
                $aadError = $errObj.error
                $aadDesc = $errObj.error_description
            } catch {
                $aadDesc = $raw
            }
        }
    }

    Write-Host ""
    Write-Host "TOKEN REQUEST FAILED"
    if ($status) { Write-Host "HTTP status : $status" }
    if ($aadError) { Write-Host "error       : $aadError" }
    if ($aadDesc) { Write-Host "description : $aadDesc" }

    switch -Regex ($aadDesc) {
        'AADSTS7000215' {
            Write-Host ""
            Write-Host "AADSTS7000215 = invalid client secret. The value in ADO does not match any active secret on this app."
            Write-Host "Typical causes: variable group 'entra'/entraSPToken was overwritten with the wrong value, extra quotes, or a secret from a different app."
        }
        'AADSTS7000222' {
            Write-Host ""
            Write-Host "AADSTS7000222 = client secret expired on the app registration. Rotate the secret in Entra and update entraSPToken."
        }
        'AADSTS700016|AADSTS7000112' {
            Write-Host ""
            Write-Host "App not found or disabled in this tenant. Confirm entraSPClientId is the Graph app in tenant $TenantId."
        }
        'AADSTS50076|AADSTS50079|AADSTS53003' {
            Write-Host ""
            Write-Host "Conditional Access is blocking this client-credentials grant. Check CA policies targeting this app."
        }
    }

    throw "Graph client-secret auth failed."
}

Write-Host ""
Write-Host "TOKEN REQUEST SUCCEEDED"
Write-Host "token_type : $($tokenResponse.token_type)"
Write-Host "expires_in : $($tokenResponse.expires_in) seconds"
Write-Host "The secret in use is valid for this ClientId/TenantId."

if (-not $ConnectGraph) {
    Write-Host ""
    Write-Host "Skipping Connect-MgGraph (default). Re-run with -ConnectGraph to also prove the Graph SDK login."
    exit 0
}

Write-Host ""
Write-Host "Connecting Microsoft Graph SDK with the same credential..."
$secure = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
$credential = [pscredential]::new($ClientId, $secure)
Connect-MgGraph -ClientSecretCredential $credential -TenantId $TenantId -NoWelcome

$context = Get-MgContext
if (-not $context) {
    throw "Connect-MgGraph returned no context."
}
Write-Host "Connected. AppId=$($context.AppId) AuthType=$($context.AuthType) Scopes=$($context.Scopes -join ', ')"
Disconnect-MgGraph | Out-Null
Write-Host "Graph SDK login succeeded."
