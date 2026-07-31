@echo off
setlocal
cd /d "%~dp0"
call "%~dp0scripts\dev.cmd" %*
exit /b %errorlevel%
