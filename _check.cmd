@echo off
set "G=C:\Users\User\AppData\Local\GitHubDesktop\app-3.6.6\resources\app\git\cmd\git.exe"
cd /d C:\Users\User\Documents\GitHub\UIW
"%G%" fetch origin
"%G%" log --oneline -5 origin/main
echo ---- local dist ----
for %%A in (dist\UIW.lua) do echo %%~zA
findstr /c:"largeIceSpikes" dist\UIW.lua >nul && echo LOCAL_DIST_HAS_NEW || echo LOCAL_DIST_OLD
echo ---- remote dist ----
"%G%" show origin/main:dist/UIW.lua > _remote_dist.lua
for %%A in (_remote_dist.lua) do echo %%~zA
findstr /c:"largeIceSpikes" _remote_dist.lua >nul && echo REMOTE_DIST_HAS_NEW || echo REMOTE_DIST_OLD
del _remote_dist.lua
