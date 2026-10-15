#!/usr/bin/env pwsh
# Installs every mod of apps\lua as a dev copy named <mod>_dev, so it sits next to a release
# install of the same mod. Folders are linked with directory junctions, so edits in this repo
# show up in game without copying. The entry script is copied under the dev name (CSP loads
# <folder>\<folder>.lua) and manifest.ini is copied with " (dev)" added to every NAME.
# Run it again after editing a manifest or a file at the root of a mod. Also removes links into
# this repo that point to a folder that no longer exists (a renamed mod).
# Use -Uninstall to remove the dev copies.
param(
    [string]$AcRoot = "D:\SteamLibrary\steamapps\common\assettocorsa",
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

# Keep in sync with src/variant.lua of each mod.
$FolderSuffix = "_dev"
$TitleSuffix = " (dev)"
# Written in every dev copy, so only folders made by this script are ever cleared.
$Marker = ".dev-install"

$RepoApps = Join-Path $PSScriptRoot "apps\lua"
$AcApps = Join-Path $AcRoot "apps\lua"

if (-not (Test-Path (Join-Path $AcRoot "acs.exe"))) {
    throw "Assetto Corsa not found at '$AcRoot'. Pass -AcRoot <path>."
}

function Test-Junction($Item) {
    return $Item.LinkType -eq "Junction"
}

# Removes the links and copied files of a dev copy, never the repo folders the links point to.
function Clear-DevCopy([string]$Path) {
    if (-not (Test-Path (Join-Path $Path $Marker))) {
        throw "'$Path' was not made by install.ps1. Move it away first."
    }
    foreach ($child in Get-ChildItem -LiteralPath $Path -Force) {
        if (Test-Junction $child) {
            $child.Delete()
        } elseif ($child.PSIsContainer) {
            throw "'$($child.FullName)' is a real folder. Move it away first."
        } else {
            Remove-Item -LiteralPath $child.FullName -Force
        }
    }
    Remove-Item -LiteralPath $Path -Force
}

function Write-DevManifest([string]$Source, [string]$Target) {
    $text = [IO.File]::ReadAllText($Source)
    $text = [regex]::Replace($text, '(?m)^(NAME\s*=\s*)(.*?)(\s*)$', "`${1}`${2}$TitleSuffix`${3}")
    [IO.File]::WriteAllText($Target, $text, (New-Object Text.UTF8Encoding $false))
}

function Install-DevCopy([IO.DirectoryInfo]$Mod) {
    $name = $Mod.Name + $FolderSuffix
    $target = Join-Path $AcApps $name
    if (Test-Path $target) { Clear-DevCopy $target }
    New-Item -ItemType Directory -Path $target | Out-Null
    New-Item -ItemType File -Path (Join-Path $target $Marker) | Out-Null
    foreach ($child in Get-ChildItem -LiteralPath $Mod.FullName -Force) {
        if ($child.PSIsContainer) {
            New-Item -ItemType Junction -Path (Join-Path $target $child.Name) -Target $child.FullName | Out-Null
        } elseif ($child.Name -eq "manifest.ini") {
            Write-DevManifest $child.FullName (Join-Path $target $child.Name)
        } elseif ($child.Name -eq "$($Mod.Name).lua") {
            Copy-Item -LiteralPath $child.FullName -Destination (Join-Path $target "$name.lua")
        } else {
            Copy-Item -LiteralPath $child.FullName -Destination (Join-Path $target $child.Name)
        }
    }
    Write-Host "Installed $target"
}

# Links into this repo whose folder is gone: left behind when a mod is renamed.
function Remove-BrokenLinks {
    foreach ($item in Get-ChildItem -LiteralPath $AcApps -Force -Directory) {
        if (-not (Test-Junction $item)) { continue }
        $linkTarget = [string]$item.Target
        if ($linkTarget.StartsWith($PSScriptRoot, [StringComparison]::OrdinalIgnoreCase) -and -not (Test-Path $linkTarget)) {
            $item.Delete()
            Write-Host "Removed broken link $($item.FullName)"
        }
    }
}

Remove-BrokenLinks

foreach ($mod in Get-ChildItem -LiteralPath $RepoApps -Directory) {
    if ($Uninstall) {
        $target = Join-Path $AcApps ($mod.Name + $FolderSuffix)
        if (Test-Path $target) {
            Clear-DevCopy $target
            Write-Host "Removed $target"
        }
    } else {
        Install-DevCopy $mod
    }
}
