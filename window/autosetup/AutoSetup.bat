@echo off
title Auto App Installer - Windows
color 0A

echo ==========================================
echo  Auto Installer - Starting PowerShell Script
echo ==========================================
echo.

:: Kiểm tra quyền admin
net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo Vui long chay file nay bang quyen Administrator!
    pause
    exit /b
)

:: Chạy PowerShell script
echo Dang chay PowerShell...
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0install_apps.ps1'"

echo.
echo Da hoan tat cai dat phan mem!
pause
exit
