@echo off
set "ROOT=%~dp0"
if exist "%ROOT%BraveBackup.exe" (
    start "" "%ROOT%BraveBackup.exe"
    exit /b 0
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\BraveBackupTool.ps1"
