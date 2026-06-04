@echo off
REM S&G Super App - I0 basic validation launcher
REM This does not change server configuration.
powershell.exe -ExecutionPolicy Bypass -File "%~dp0Collect-SGServerInfo.ps1" -OutputRoot "%CD%"
pause
