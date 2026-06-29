@echo off
REM ============================================================
REM  Shifty desktop widget - release build
REM  Produces a standalone .exe + installer (no console window).
REM  Uses the VS 2022 BuildTools toolchain, same as dev.bat.
REM  Output: src-tauri\target\release\bundle\
REM ============================================================
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64
set "PATH=%USERPROFILE%\.cargo\bin;%PATH%"
cd /d "%~dp0"
npm run tauri build
echo.
echo ============================================================
echo  Done. Installer is in: src-tauri\target\release\bundle\
echo ============================================================
pause
