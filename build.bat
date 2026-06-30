@echo off
chcp 65001 >nul
title LuoguChat v8.1 Build
set ELECTRON_RUN_AS_NODE=
set NODE_OPTIONS=
cd /d "%~dp0"

echo   === LuoguChat v8.1 Build ===
echo   Source: %CD%
echo.

echo   [1] Building app.asar...
call npx electron-builder --win
if %errorlevel% neq 0 (echo Build failed! && pause && exit /b)

echo   [2] Fixing EXE copy...
copy /Y "node_modules\electron\dist\electron.exe" "dist\win-unpacked\LuoguChat.exe" >nul
if exist "config.json" copy /Y "config.json" "dist\win-unpacked\" >nul
if exist "zhl_super_allow.txt" copy /Y "zhl_super_allow.txt" "dist\win-unpacked\" >nul

echo   Done! dist\win-unpacked\LuoguChat.exe
echo.
start "" dist\win-unpacked\LuoguChat.exe
pause
