<#
.SYNOPSIS
  Validates that additionalDnsConfig is valid JSON when Document Intelligence is enabled.

.DESCRIPTION
  Empty, whitespace-only, [], JSON null, or omitted variable are all acceptable.
#>
param(
  [string]$DocumentIntelligenceSku = '',
  [string]$AdditionalDnsConfig = ''
)

$ErrorActionPreference = 'Stop'

$skuLower = $DocumentIntelligenceSku.ToLowerInvariant().Trim()
if ([string]::IsNullOrWhiteSpace($skuLower) -or $skuLower -eq 'none') {
  Write-Host "Document Intelligence not configured; skipping additionalDnsConfig validation."
  exit 0
}

$raw = ($AdditionalDnsConfig ?? '').Trim()
if ([string]::IsNullOrWhiteSpace($raw) -or $raw -eq '[]' -or $raw -eq 'null') {
  Write-Host "additionalDnsConfig empty or absent; skipping validation."
  exit 0
}

try {
  $parsed = $raw | ConvertFrom-Json
  if ($null -eq $parsed -or ($parsed -is [System.Array] -and $parsed.Count -eq 0)) {
    Write-Host "additionalDnsConfig empty after parsing; skipping validation."
    exit 0
  }
}
catch {
  throw "additionalDnsConfig is not valid JSON: $($_.Exception.Message)"
}
