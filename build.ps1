# Joins the parts listed in manifest.txt into dist\UIW.lua.
#   .\build.cmd            build only
#   .\build.cmd -Volt      also copy to Volt\workspace\UIW\UIW.lua
#   .\build.cmd -AutoExec  also copy over the auto-execute file (UIW_Aura_Mage_v13.lua)
param(
    [switch]$Volt,
    [switch]$AutoExec
)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding($false)
$builder = New-Object System.Text.StringBuilder
$count = 0

foreach ($line in [System.IO.File]::ReadAllLines((Join-Path $root "manifest.txt"), $utf8)) {
    $part = $line.Trim()
    if ($part -eq "" -or $part.StartsWith("#")) { continue }
    $file = Join-Path $root $part
    if (-not (Test-Path -LiteralPath $file)) { throw "Missing part: $part" }
    $text = [System.IO.File]::ReadAllText($file, $utf8) -replace "`r`n", "`n"
    [void]$builder.Append($text)
    $count++
}

$dist = Join-Path $root "dist"
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$out = Join-Path $dist "UIW.lua"
[System.IO.File]::WriteAllText($out, $builder.ToString(), $utf8)
Write-Host ("Built dist\UIW.lua ({0} bytes, {1} parts)" -f (Get-Item $out).Length, $count)

$voltUIW = Join-Path $env:LOCALAPPDATA "Volt\workspace\UIW"
if ($Volt -or $AutoExec) {
    New-Item -ItemType Directory -Force -Path $voltUIW | Out-Null
    Copy-Item -LiteralPath $out -Destination (Join-Path $voltUIW "UIW.lua") -Force
    Write-Host "Copied to Volt\workspace\UIW\UIW.lua"
}
if ($AutoExec) {
    Copy-Item -LiteralPath $out -Destination (Join-Path $voltUIW "UIW_Aura_Mage_v13.lua") -Force
    Write-Host "Copied to Volt\workspace\UIW\UIW_Aura_Mage_v13.lua (auto-execute)"
}
