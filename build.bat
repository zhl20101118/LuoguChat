@echo off
chcp 65001 >nul
title LuoguChat v7.0 编译打包
echo ================================================
echo   LuoguChat v7.0 - 编译打包脚本
echo ================================================
echo.

REM Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo [错误] 未找到 Python，请先安装 Python 3.8+
    pause
    exit /b 1
)

echo [1/4] 安装运行依赖...
pip install -r requirements.txt -i https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple
if errorlevel 1 (
    echo [警告] 部分依赖安装失败，继续...
)

echo [2/4] 清理旧构建...
if exist "build" rmdir /s /q "build"
if exist "dist" rmdir /s /q "dist"
del /f /q "*.spec" 2>nul

echo [3/4] 开始编译...
pyinstaller --noconfirm --onefile --windowed ^
    --name "LuoguChat" ^
    --add-data "main.qml;." ^
    --hidden-import PySide6.QtQml ^
    --hidden-import PySide6.QtQuick ^
    --hidden-import PySide6.QtQuickControls2 ^
    --hidden-import PySide6.QtMultimedia ^
    --hidden-import PySide6.QtCore ^
    --hidden-import PySide6.QtGui ^
    --hidden-import PySide6.QtWidgets ^
    --hidden-import PySide6.QtNetwork ^
    --hidden-import websocket ^
    --hidden-import requests ^
    --collect-all PySide6 ^
    --add-data "zhl_super_allow.txt;." ^
    main.py

if errorlevel 1 (
    echo [错误] 编译失败！
    pause
    exit /b 1
)

echo.
echo ================================================
echo   编译成功！
echo   输出文件: dist\LuoguChat.exe
echo   使用时确保同目录有: config.json, zhl_super_allow.txt
echo ================================================
echo.
pause
