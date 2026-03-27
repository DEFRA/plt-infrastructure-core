<#
.SYNOPSIS
  Replaces #{{ tokenName }} tokens in parameter files with pipeline variable values.
  Run with workingDirectory set to the repo root (e.g. $(Pipeline.Workspace)/s/self) so paths resolve correctly.
  Same pattern as qetza Replace Tokens task (custom prefix #{{ suffix }}).
  Similar logic to that avaialble in ad-pipeline-common, which cannot be used here because it uses the qetza Replace Tokens task
  which is not available in the self repository.
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$Paths,
  [string]$TokenPrefix = '#{{',
  [string]$TokenSuffix = '}}'
)

$ErrorActionPreference = 'Stop'
$pathList = $Paths -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

function Get-VariableValue {
  param([string]$Name)
  $val = [Environment]::GetEnvironmentVariable($Name, 'Process')
  if ($null -ne $val) { return $val }
  $val = [Environment]::GetEnvironmentVariable($Name.ToUpperInvariant(), 'Process')
  if ($null -ne $val) { return $val }
  $alt = $Name.ToUpperInvariant().Replace('.', '_')
  $val = [Environment]::GetEnvironmentVariable($alt, 'Process')
  if ($null -ne $val) { return $val }
  return ''
}

function Escape-JsonValue {
  param([string]$Value)
  if ($null -eq $Value) { return '' }
  $Value -replace '\\', '\\\\' -replace '"', '\"'
}

$pattern = [regex]::Escape($TokenPrefix) + '\s*([\w\.]+)\s*' + [regex]::Escape($TokenSuffix)
$totalFiles = 0

foreach ($dir in $pathList) {
  if (-not (Test-Path -LiteralPath $dir)) {
    Write-Warning "Path not found: $dir"
    continue
  }
  Get-ChildItem -Path $dir -Filter '*.parameters.json' -ErrorAction SilentlyContinue | ForEach-Object {
    $content = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
    $newContent = [regex]::Replace($content, $pattern, {
      param($m)
      $varName = $m.Groups[1].Value
      $val = Get-VariableValue -Name $varName
      Escape-JsonValue -Value $val
    })
    $outPath = Join-Path $_.DirectoryName ($_.BaseName + '.transformed.parameters.json')
    [System.IO.File]::WriteAllText($outPath, $newContent, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Wrote $outPath"
    $totalFiles++
  }
}

Write-Host "Replace-Tokens: processed $totalFiles file(s)."
