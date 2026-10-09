@echo off
setlocal
chcp 65001 >nul
rem Started from a PowerShell 7 terminal, cmd inherits PowerShell 7 module paths;
rem Windows PowerShell then loads incompatible modules (no Get-FileHash).
set "PSModulePath="
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0installer.ps1"
