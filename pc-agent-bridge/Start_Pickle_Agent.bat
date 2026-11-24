@echo off
chcp 65001 >nul 2>&1
title Pickle Agent - GitHub Auto Sync
cd /d "%~dp0"

echo.
echo   Starting Pickle Agent...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pickle-agent.ps1"

set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
  echo.
  echo   [The agent stopped. See the message above.]
  echo   Press any key to close this window.
  pause >nul
)
