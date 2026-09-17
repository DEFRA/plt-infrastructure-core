<#
.SYNOPSIS
  Invokes Add-AdAppRegistrations when an instance manifest exists.

.DESCRIPTION
  Skips when app-registration.json is absent (same optional-manifest pattern as AAD groups).
  Replaces #{{ token }} placeholders with pipeline variables. If appRegNameSuffix is not
  already set, non-release branches get a suffix of -<branch> (e.g. -alz-dev).
#>
param(
  [Parameter(Mandatory = $true)][string]$ManifestPath,
  [Parameter(Mandatory = $true)][string]$ScriptPath,
  [Parameter()][string]$SourceBranchName = $env:BUILD_SOURCEBRANCHNAME,
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

function Get-AppRegNameSuffix {
  param([string]$BranchName)

  $configured = Get-VariableValue -Name 'appRegNameSuffix'
  if (-not [string]::IsNullOrWhiteSpace($configured)) {
    return $configured
  }

  $branch = if ($null -eq $BranchName) { '' } else { $BranchName.ToString().Trim() }
  if ([string]::IsNullOrWhiteSpace($branch) -or $branch -eq 'main' -or $branch -match '^\d+\.\d+\.\d+$') {
    return ''
  }

  $safe = $branch -replace '[^A-Za-z0-9._-]', '-'
  return "-$safe"
}

$script:appRegNameSuffixValue = Get-AppRegNameSuffix -BranchName $SourceBranchName
[Environment]::SetEnvironmentVariable('appRegNameSuffix', $script:appRegNameSuffixValue, 'Process')
[Environment]::SetEnvironmentVariable('APPREGNAMESUFFIX', $script:appRegNameSuffixValue, 'Process')
Write-Host "##vso[task.setvariable variable=appRegNameSuffix]$($script:appRegNameSuffixValue)"
Write-Host "appRegNameSuffix='$($script:appRegNameSuffixValue)' (branch '$SourceBranchName')"

$content = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8
$pattern = [regex]::Escape('#{{') + '\s*([\w\.]+)\s*' + [regex]::Escape('}}')
$replaced = [regex]::Replace($content, $pattern, {
  param($m)
  $varName = $m.Groups[1].Value
  if ($varName -eq 'appRegNameSuffix') {
    return $script:appRegNameSuffixValue
  }
  return (Get-VariableValue -Name $varName)
})

$workingCopy = Join-Path ([System.IO.Path]::GetTempPath()) ("app-registration-" + [guid]::NewGuid().ToString() + ".json")
[System.IO.File]::WriteAllText($workingCopy, $replaced, [System.Text.UTF8Encoding]::new($false))
Write-Host "Processed manifest written to $workingCopy"

& $ScriptPath -AppRegJsonPath $workingCopy -federatedCredential $FederatedCredential
