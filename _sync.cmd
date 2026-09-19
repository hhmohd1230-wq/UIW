@echo off
set "G=C:\Users\User\AppData\Local\GitHubDesktop\app-3.6.6\resources\app\git\cmd\git.exe"
cd /d C:\Users\User\Documents\GitHub\UIW
"%G%" fetch origin
"%G%" log --oneline -3 origin/main
echo ---- rebasing ----
"%G%" pull --rebase origin main
echo ---- pushing ----
"%G%" push origin HEAD
echo EXITCODE=%errorlevel%
