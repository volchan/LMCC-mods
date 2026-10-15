#!/usr/bin/env pwsh
# Installs the mods of apps\lua into Assetto Corsa, in one of two modes:
# - dev: a copy named <mod>_dev, so it sits next to a normal install of the same mod. Folders are
#   linked with directory junctions, so edits in this repo show up in game without copying. The
#   entry script is copied under the dev name (CSP loads <folder>\<folder>.lua) and manifest.ini
#   is copied with " (dev)" added to every NAME. Run it again after editing a manifest or a file
#   at the root of a mod.
# - normal: the committed files of the mod in apps\lua\<mod>, as drivers get them from a release.
# Both modes also remove links into this repo that point to a folder that no longer exists (a
# renamed mod). Only folders made by this script are ever replaced or removed.
# Use -Uninstall to remove the copies of the given mode, -Mod to act on one mod only.
param(
    [ValidateSet("dev", "normal")]
    [string]$Mode = "dev",
    [string]$Mod = "",
    [string]$AcRoot = "D:\SteamLibrary\steamapps\common\assettocorsa",
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

# Keep in sync with src/variant.lua of each mod.
$FolderSuffix = "_dev"
$TitleSuffix = " (dev)"
# Written in every copy this script makes, one per mode.
$Markers = @{ dev = ".dev-install"; normal = ".normal-install" }

$RepoApps = Join-Path $PSScriptRoot "apps\lua"
$AcApps = Join-Path $AcRoot "apps\lua"

if (-not (Test-Path (Join-Path $AcRoot "acs.exe"))) {
    throw "Assetto Corsa not found at '$AcRoot'. Pass -AcRoot <path>."
}

function Test-Link($Item) {
    return [bool]$Item.LinkType
}

# Unlinks junctions instead of following them, so the repo folders they point to are never touched.
function Remove-Tree([string]$Path) {
    foreach ($child in Get-ChildItem -LiteralPath $Path -Force) {
        if (Test-Link $child) {
            $child.Delete()
        } elseif ($child.PSIsContainer) {
            Remove-Tree $child.FullName
        } else {
            Remove-Item -LiteralPath $child.FullName -Force
        }
    }
    Remove-Item -LiteralPath $Path -Force
}

function Remove-Copy([string]$Path, [string]$Marker) {
    $item = Get-Item -LiteralPath $Path -Force
    if ((Test-Link $item) -or -not (Test-Path (Join-Path $Path $Marker))) {
        throw "'$Path' was not installed by install.ps1 in this mode. Move it away first."
    }
    Remove-Tree $Path
}

function Write-DevManifest([string]$Source, [string]$Target) {
    $text = [IO.File]::ReadAllText($Source)
    $text = [regex]::Replace($text, '(?m)^(NAME\s*=\s*)(.*?)(\s*)$', "`${1}`${2}$TitleSuffix`${3}")
    [IO.File]::WriteAllText($Target, $text, (New-Object Text.UTF8Encoding $false))
}

function Get-Target([IO.DirectoryInfo]$Source) {
    $name = if ($Mode -eq "dev") { $Source.Name + $FolderSuffix } else { $Source.Name }
    return Join-Path $AcApps $name
}

function Install-DevCopy([IO.DirectoryInfo]$Source, [string]$Target) {
    New-Item -ItemType Directory -Path $Target | Out-Null
    foreach ($child in Get-ChildItem -LiteralPath $Source.FullName -Force) {
        if ($child.PSIsContainer) {
            New-Item -ItemType Junction -Path (Join-Path $Target $child.Name) -Target $child.FullName | Out-Null
        } elseif ($child.Name -eq "manifest.ini") {
            Write-DevManifest $child.FullName (Join-Path $Target $child.Name)
        } elseif ($child.Name -eq "$($Source.Name).lua") {
            Copy-Item -LiteralPath $child.FullName -Destination (Join-Path $Target "$(Split-Path $Target -Leaf).lua")
        } else {
            Copy-Item -LiteralPath $child.FullName -Destination (Join-Path $Target $child.Name)
        }
    }
}

# Same files as the release zip (scripts/build.sh): the committed tree, LF line endings.
function Install-NormalCopy([IO.DirectoryInfo]$Source) {
    $path = "apps/lua/$($Source.Name)"
    if (git -C $PSScriptRoot status --porcelain -- $path) {
        Write-Warning "Uncommitted changes in $path are not installed: commit them first."
    }
    $zip = Join-Path ([IO.Path]::GetTempPath()) "$($Source.Name)-$([guid]::NewGuid()).zip"
    git -C $PSScriptRoot -c core.autocrlf=false archive --format=zip --output=$zip HEAD $path
    if ($LASTEXITCODE -ne 0) { throw "git archive failed for $path." }
    try {
        Expand-Archive -LiteralPath $zip -DestinationPath $AcRoot
    } finally {
        Remove-Item -LiteralPath $zip
    }
}

function Install-Copy([IO.DirectoryInfo]$Source) {
    $target = Get-Target $Source
    if (Test-Path $target) { Remove-Copy $target $Markers[$Mode] }
    if ($Mode -eq "dev") { Install-DevCopy $Source $target } else { Install-NormalCopy $Source }
    New-Item -ItemType File -Path (Join-Path $target $Markers[$Mode]) | Out-Null
    Write-Host "Installed $target ($Mode)"
}

function Uninstall-Copy([IO.DirectoryInfo]$Source) {
    $target = Get-Target $Source
    if (Test-Path $target) {
        Remove-Copy $target $Markers[$Mode]
        Write-Host "Removed $target ($Mode)"
    } else {
        Write-Host "Not installed: $target ($Mode)"
    }
}

# Links into this repo whose folder is gone: left behind when a mod is renamed.
function Remove-BrokenLinks {
    foreach ($item in Get-ChildItem -LiteralPath $AcApps -Force -Directory) {
        if (-not (Test-Link $item)) { continue }
        $linkTarget = [string]$item.Target
        if ($linkTarget.StartsWith($PSScriptRoot, [StringComparison]::OrdinalIgnoreCase) -and -not (Test-Path $linkTarget)) {
            $item.Delete()
            Write-Host "Removed broken link $($item.FullName)"
        }
    }
}

$mods = Get-ChildItem -LiteralPath $RepoApps -Directory
if ($Mod) {
    $mods = $mods | Where-Object Name -eq $Mod
    if (-not $mods) { throw "No mod named '$Mod' in $RepoApps." }
}

Remove-BrokenLinks
foreach ($source in $mods) {
    if ($Uninstall) { Uninstall-Copy $source } else { Install-Copy $source }
}
