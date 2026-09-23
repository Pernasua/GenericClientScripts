[CmdletBinding()]
param(
    [string]$Source = (Join-Path $PSScriptRoot 'build\libs'),
    [string]$ScriptsDirectory = (Join-Path $env:USERPROFILE '.runelite\genericclient\scripts')
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Assert-Artifact([string]$File, [string]$Hash) {
    $name = Split-Path -Leaf $File
    if ($name -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*\.jar$') { throw "Invalid script JAR name: $name" }
    if (!(Test-Path -LiteralPath $File -PathType Leaf) -or (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash -ne $Hash) {
        throw "Missing or changed artifact: $File"
    }
    $jar = [IO.Compression.ZipFile]::OpenRead($File)
    try {
        $entry = $jar.GetEntry('META-INF/MANIFEST.MF')
        if ($null -eq $entry) { throw "JAR has no manifest: $File" }
        $reader = [IO.StreamReader]::new($entry.Open())
        try { $manifest = $reader.ReadToEnd().Replace("`r", '') } finally { $reader.Dispose() }
        $id = [regex]::Match($manifest, '(?m)^GenericClient-Script-Id: ([a-z0-9]+(?:-[a-z0-9]+)*)$')
        if (!$id.Success -or "$($id.Groups[1].Value).jar" -cne $name) { throw "Not a single-script artifact: $File" }
    } finally { $jar.Dispose() }
}

$artifacts = @()
$fullCatalog = Test-Path -LiteralPath $Source -PathType Container
if ($fullCatalog) {
    $index = Join-Path $Source 'scripts.sha256'
    if (!(Test-Path -LiteralPath $index -PathType Leaf)) { throw 'Build the scripts first: .\gradlew.bat build' }
    $names = @{}
    foreach ($line in Get-Content -LiteralPath $index) {
        if ($line -cnotmatch '^([a-f0-9]{64})  ([a-z0-9]+(?:-[a-z0-9]+)*\.jar)$') { throw 'Invalid scripts.sha256' }
        $hash = $Matches[1]; $name = $Matches[2]
        if ($names.ContainsKey($name)) { throw "Duplicate artifact: $name" }
        $names[$name] = $true
        $file = Join-Path $Source $name
        Assert-Artifact $file $hash
        $artifacts += [pscustomobject]@{ File = $file; Name = $name; Hash = $hash }
    }
    if ($artifacts.Count -eq 0) { throw 'The script catalog is empty' }
    if (@(Get-ChildItem -LiteralPath $Source -File -Filter '*.jar').Count -ne $artifacts.Count) {
        throw 'Unlisted JARs in build output; rebuild before installing'
    }
} else {
    if (!(Test-Path -LiteralPath $Source -PathType Leaf)) { throw "Artifact not found: $Source" }
    $hash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash
    Assert-Artifact $Source $hash
    $artifacts = @([pscustomobject]@{ File = $Source; Name = (Split-Path -Leaf $Source); Hash = $hash })
}
$legacy = Join-Path $ScriptsDirectory 'GenericClientScripts.jar'
if ((Test-Path -LiteralPath $legacy -PathType Leaf) -and !$fullCatalog) {
    throw 'The old combined catalog is installed. Run the full-directory installer once before updating individual scripts.'
}
foreach ($artifact in $artifacts) {
    $target = Join-Path $ScriptsDirectory $artifact.Name
    if ((Test-Path -LiteralPath $target) -and !(Test-Path -LiteralPath $target -PathType Leaf)) {
        throw "Destination is not a regular file: $target"
    }
}

# Operator precondition: stop scripts before replacing their JARs.
New-Item -ItemType Directory -Path $ScriptsDirectory -Force | Out-Null
$token = [guid]::NewGuid().ToString('N')
$staging = Join-Path $ScriptsDirectory ".script-install-$token"
$backup = Join-Path (Split-Path -Parent $ScriptsDirectory) "backups\script-jars-$token"
New-Item -ItemType Directory -Path $staging, $backup -Force | Out-Null
$installed = @()
try {
    foreach ($artifact in $artifacts) {
        $stage = Join-Path $staging $artifact.Name
        Copy-Item -LiteralPath $artifact.File -Destination $stage
        if ((Get-FileHash -LiteralPath $stage -Algorithm SHA256).Hash -ne $artifact.Hash) { throw "Staged copy mismatch: $($artifact.Name)" }
    }
    foreach ($artifact in $artifacts) {
        $target = Join-Path $ScriptsDirectory $artifact.Name
        if (Test-Path -LiteralPath $target) { Copy-Item -LiteralPath $target -Destination (Join-Path $backup $artifact.Name) }
        $installed += $target
        Copy-Item -LiteralPath (Join-Path $staging $artifact.Name) -Destination $target -Force
        if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $artifact.Hash) { throw "Installed copy mismatch: $($artifact.Name)" }
    }
    if (Test-Path -LiteralPath $legacy -PathType Leaf) { Move-Item -LiteralPath $legacy -Destination (Join-Path $backup 'GenericClientScripts.jar') }
} catch {
    foreach ($file in $installed) { if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force } }
    foreach ($file in Get-ChildItem -LiteralPath $backup -File -Filter '*.jar') {
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $ScriptsDirectory $file.Name) -Force
    }
    throw
} finally { Remove-Item -LiteralPath $staging -Recurse -Force }
Write-Host "Installed $($artifacts.Count) script JAR(s) in $ScriptsDirectory. Backup: $backup"
Write-Host 'Use Scripts > Reload list in GenericClient.'
