# Isolated Northern Lands test; leaves normal/stable/flat outputs untouched.
param([switch]$Volt)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'build-inventory.ps1')
$utf8 = New-Object System.Text.UTF8Encoding($false)
$builder = New-Object System.Text.StringBuilder
foreach ($line in [IO.File]::ReadAllLines((Join-Path $PSScriptRoot 'manifest.txt'))) {
    $part = $line.Trim()
    if (!$part -or $part.StartsWith('#')) { continue }
    $source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot $part))
    if ($part -eq 'src/99_start.lua') {
        $setup = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'src/experiments/northern_openmap.lua'))
        $setup += "`n" + [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'src/experiments/bob_feedback.lua'))
        $source = $source.Replace('Controller:Start()', $setup + "`nController:Start()")
    }
    [void]$builder.AppendLine($source)
}
$out = Join-Path $PSScriptRoot 'dist/UIW_openmap.lua'
[IO.File]::WriteAllText($out, ($builder.ToString() -replace "`r`n", "`n"), $utf8)
if ($Volt) {
    # NOT $volt: PowerShell is case-insensitive, so $volt IS the -Volt switch
    # parameter, and assigning a path to it fails with a SwitchParameter cast
    # error before anything is copied.
    $voltDir = Join-Path $env:LOCALAPPDATA 'Volt/workspace/UIW'
    Copy-Item -LiteralPath $out -Destination (Join-Path $voltDir 'UIW_openmap.lua') -Force
    # The boss probe is the instrument every change in this repo is judged by,
    # and until 2026-09-27 it existed only inside the Volt workspace: not in
    # git, not built, not copied. Ship it with the build so the measurement
    # tool and the thing it measures cannot drift apart.
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'tools/bossprobe.lua') -Destination (Join-Path $voltDir 'bossprobe.lua') -Force
    Write-Output "Copied to Volt workspace (UIW_openmap.lua, bossprobe.lua)"
}
Write-Output "Built $out"
