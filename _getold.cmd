@echo off
set "G=C:\Users\User\AppData\Local\GitHubDesktop\app-3.6.6\resources\app\git\cmd\git.exe"
cd /d C:\Users\User\Documents\GitHub\UIW
"%G%" log --oneline -12
echo ---- extracting c1fe8fc dist ----
"%G%" show c1fe8fc:dist/UIW.lua > "C:\Users\User\AppData\Local\Volt\workspace\UIW\UIW_c1fe8fc.lua"
for %%A in ("C:\Users\User\AppData\Local\Volt\workspace\UIW\UIW_c1fe8fc.lua") do echo size %%~zA
echo EXITCODE=%errorlevel%
