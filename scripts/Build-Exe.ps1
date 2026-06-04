#Requires -Version 5.1
<#
.SYNOPSIS
    Buduje BraveBackup.exe z ikona (assets\BraveBackup.ico).
#>
param(
    [string]$Version = '2.0.0.0'
)
$ErrorActionPreference = 'Stop'

$scriptDir   = $PSScriptRoot
$projectRoot = Split-Path -Parent $scriptDir
$source      = Join-Path $scriptDir 'BraveBackupTool.ps1'
$output      = Join-Path $projectRoot 'BraveBackup.exe'
$icon        = Join-Path $projectRoot 'assets\BraveBackup.ico'

if (-not (Test-Path $source)) {
    Write-Error "Brak pliku: $source"
}

if (-not (Test-Path $icon)) {
    Write-Host 'Generowanie ikony...' -ForegroundColor Cyan
    & (Join-Path $scriptDir 'New-AppIcon.ps1')
}

function Get-Ps2ExeScript {
    $local = Join-Path $scriptDir 'ps2exe-mod\ps2exe.ps1'
    if (Test-Path $local) { return $local }
    $modDir = Join-Path $scriptDir 'ps2exe-mod'
    $zip = Join-Path $env:TEMP 'ps2exe-nuget.zip'
    New-Item -ItemType Directory -Force -Path $modDir | Out-Null
    Write-Host 'Pobieranie ps2exe...' -ForegroundColor Cyan
    Invoke-WebRequest -Uri 'https://www.powershellgallery.com/api/v2/package/ps2exe' -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $modDir -Force
    return (Get-ChildItem $modDir -Recurse -Filter 'ps2exe.ps1' | Select-Object -First 1).FullName
}

. (Get-Ps2ExeScript)

Write-Host "Budowanie: $output" -ForegroundColor Cyan
Write-Host "Ikona:     $icon" -ForegroundColor Cyan
Invoke-ps2exe -inputFile $source -outputFile $output -noConsole -iconFile $icon `
    -title 'Brave Backup Tool' -description 'Kopia zapasowa profilu Brave' `
    -company 'Brave Backup Tool' -product 'BraveBackup' -version $Version

if (Test-Path $output) {
    Write-Host ''
    Write-Host 'Gotowe:' -ForegroundColor Green
    Write-Host "  $output"
    Write-Host "  $([math]::Round((Get-Item $output).Length / 1KB, 0)) KB"
} else {
    Write-Error 'Nie utworzono pliku EXE.'
}
