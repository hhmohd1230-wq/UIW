# Isolated Northern Lands test; leaves normal/stable/flat outputs untouched.
param([switch]$Volt)
$ErrorActionPreference = 'Stop'
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
    Copy-Item -LiteralPath $out -Destination (Join-Path $env:LOCALAPPDATA 'Volt/workspace/UIW/UIW_openmap.lua') -Force
}
Write-Output "Built $out"
