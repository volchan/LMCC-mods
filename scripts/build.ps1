#!/usr/bin/env pwsh
# Packages the app into dist/LmccFlags-<version>.zip for drivers. The zip holds
# apps/lua/LmccFlags/ so it extracts into the AC root or drops into Content Manager.
# Built from the committed tree only, so local edits never leak into a release.
$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$App = "apps/lua/LmccFlags"

$dirty = git -C $Root status --porcelain -- $App
if ($dirty) {
    throw "Uncommitted changes in $App. Commit them first."
}

$manifest = Get-Content (Join-Path $Root "$App/manifest.ini")
$version = ($manifest | Select-String '^VERSION\s*=\s*(.+)$').Matches[0].Groups[1].Value.Trim()

$Dist = Join-Path $Root "dist"
New-Item -ItemType Directory -Force $Dist | Out-Null
$Zip = Join-Path $Dist "LmccFlags-$version.zip"

git -C $Root archive --format=zip --output=$Zip HEAD $App
if ($LASTEXITCODE -ne 0) { throw "git archive failed" }
Write-Host "Built $Zip"
