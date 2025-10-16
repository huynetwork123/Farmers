@echo off
:: AutoSetup.bat — run ps1 as admin
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"Start-Process -FilePath 'powershell' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0AutoSetup.ps1\"' -Verb RunAs"
