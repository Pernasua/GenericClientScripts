[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$source = Join-Path $PSScriptRoot "scripts"
$target = Join-Path $env:USERPROFILE ".runelite\genericclient\scripts"

if (-not (Test-Path (Join-Path $source "manifest.json")))
{
    throw "The scripts manifest is missing from $source."
}

New-Item -ItemType Directory -Path $target -Force | Out-Null
Copy-Item -Path (Join-Path $source "*") -Destination $target -Recurse -Force

Write-Host "GenericClient scripts installed. Reload the manifest in GenericClient."
