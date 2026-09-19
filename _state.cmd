@echo off
set "G=C:\Users\User\AppData\Local\GitHubDesktop\app-3.6.6\resources\app\git\cmd\git.exe"
cd /d C:\Users\User\Documents\GitHub\UIW
"%G%" fetch origin
echo ---- local log ----
"%G%" log --oneline -6
echo ---- status ----
"%G%" status --short
echo ---- files changed vs origin ----
"%G%" diff --stat origin/main
