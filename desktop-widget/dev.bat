@echo off
REM ============================================================
REM  Shifty desktop widget - dev launcher
REM  Rust auto-picks VS 18 Community, whose C++ desktop libs are
REM  incomplete (missing lib\x64\msvcrt.lib). We force the VS 2022
REM  BuildTools toolchain, which has the full set, by sourcing its
REM  developer environment before building.
REM ============================================================
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64
set "PATH=%USERPROFILE%\.cargo\bin;%PATH%"
cd /d "%~dp0"
npm run tauri dev
