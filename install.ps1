[CmdletBinding()]
param(
    [string]$CatalogJar = (Join-Path $PSScriptRoot "build\libs\GenericClientScripts.jar"),
    [string]$ScriptsDirectory = (Join-Path $env:USERPROFILE ".runelite\genericclient\scripts")
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $CatalogJar -PathType Leaf)) {
    throw "Build the catalog first: .\gradlew.bat jar -PgenericClientDir=..\GenericClient"
}
New-Item -ItemType Directory -Path $ScriptsDirectory -Force | Out-Null
$installed = Join-Path $ScriptsDirectory "GenericClientScripts.jar"
Copy-Item -LiteralPath $CatalogJar -Destination $installed -Force
if ((Get-FileHash -LiteralPath $CatalogJar -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $installed -Algorithm SHA256).Hash) {
    throw "Installed catalog does not match the built JAR."
}
Get-ChildItem -LiteralPath $ScriptsDirectory -Filter "*.lua" -Recurse -File -Force | Remove-Item -Force
$oldManifest = Join-Path $ScriptsDirectory "manifest.json"
if (Test-Path -LiteralPath $oldManifest -PathType Leaf) { Remove-Item -LiteralPath $oldManifest -Force }
Write-Host "Installed $installed. Reload the script catalog in GenericClient."
