@echo off
setlocal
set "PSModulePath="
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Play.ps1" -PreferBuild %*
set "launchExit=%errorlevel%"
if not "%launchExit%"=="0" (
    echo Please extract the complete game folder, then try Play.cmd again.
    pause
)
exit /b %launchExit%
