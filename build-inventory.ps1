$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding($false)
$source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'src/inventory/engine.lua')) -replace "`r`n", "`n"
if ($source.Contains(']========]')) { throw 'Inventory bundle delimiter collision' }
$bundle = "-- Generated from src/inventory/engine.lua; isolated Luau chunk.`nlocal UIWInventorySource = [========[`n" + $source + "`n]========]`n"
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'src/inventory/bundle.lua'), $bundle, $utf8)
