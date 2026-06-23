@echo off
chcp 65001 >nul
title Shifty
cd /d "%~dp0"
echo.
echo   Shifty - starting local server...
echo   ------------------------------------
echo   Open:  http://localhost:4173
echo   (Ctrl+C to stop)
echo.
npx --yes serve -l 4173 -s .
pause
