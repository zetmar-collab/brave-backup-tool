@echo off
set "ROOT=%~dp0"
if exist "%ROOT%BraveBackup.exe" (
    "%ROOT%BraveBackup.exe" -end -Console
    exit /b 0
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\BraveBackupTool.ps1" -Console
pause
