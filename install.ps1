#!/usr/bin/env pwsh
# Links the app into Assetto Corsa with a directory junction, so edits in this repo
# show up in game without copying. Use -Uninstall to remove the link.
param(
    [string]$AcRoot = "D:\SteamLibrary\steamapps\common\assettocorsa",
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"
$Source = Join-Path $PSScriptRoot "apps\lua\LmccFlags"
$Target = Join-Path $AcRoot "apps\lua\LmccFlags"

if (-not (Test-Path (Join-Path $AcRoot "acs.exe"))) {
    throw "Assetto Corsa not found at '$AcRoot'. Pass -AcRoot <path>."
}

$existing = Get-Item $Target -ErrorAction SilentlyContinue
if ($existing -and $existing.LinkType -ne "Junction") {
    throw "'$Target' exists and is not a junction. Move it away first."
}

if ($Uninstall) {
    if ($existing) {
        # Removes the link only; the repo folder is untouched.
        $existing.Delete()
        Write-Host "Removed $Target"
    } else {
        Write-Host "Not installed"
    }
    return
}

if ($existing) {
    Write-Host "Already linked: $Target -> $($existing.Target)"
    return
}

New-Item -ItemType Junction -Path $Target -Target $Source | Out-Null
Write-Host "Linked $Target -> $Source"
