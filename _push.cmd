@echo off
set "G=C:\Users\User\AppData\Local\GitHubDesktop\app-3.6.6\resources\app\git\cmd\git.exe"
cd /d C:\Users\User\Documents\GitHub\UIW
"%G%" add -A
"%G%" commit -F _commitmsg.txt
"%G%" push origin HEAD
echo EXITCODE=%errorlevel%
