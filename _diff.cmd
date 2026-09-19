@echo off
set "G=C:\Users\User\AppData\Local\GitHubDesktop\app-3.6.6\resources\app\git\cmd\git.exe"
cd /d C:\Users\User\Documents\GitHub\UIW
"%G%" diff --stat -- manifest.txt build.py src/ui/hud.lua src/dungeons src/experiments/bob_feedback.lua
echo ==== manifest ====
"%G%" diff -- manifest.txt
echo ==== build.py ====
"%G%" diff -- build.py
echo ==== hud ====
"%G%" diff -- src/ui/hud.lua
echo ==== inventory folder ====
dir /b src\inventory
