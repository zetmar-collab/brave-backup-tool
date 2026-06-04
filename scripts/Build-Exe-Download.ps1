$ErrorActionPreference = 'Stop'
$modDir = Join-Path $PSScriptRoot 'ps2exe-mod'
$zip = Join-Path $env:TEMP 'ps2exe-nuget.zip'
New-Item -ItemType Directory -Force -Path $modDir | Out-Null
Write-Host 'Pobieranie ps2exe z PowerShell Gallery...'
Invoke-WebRequest -Uri 'https://www.powershellgallery.com/api/v2/package/ps2exe' -OutFile $zip -UseBasicParsing
Expand-Archive -Path $zip -DestinationPath $modDir -Force
$ps2 = Get-ChildItem $modDir -Recurse -Filter 'ps2exe.ps1' | Select-Object -First 1
if (-not $ps2) { throw 'Nie znaleziono ps2exe.ps1 w paczce' }
Write-Host "Znaleziono: $($ps2.FullName)"

$source = Join-Path $PSScriptRoot 'BraveBackupTool.ps1'
$output = Join-Path (Split-Path -Parent $PSScriptRoot) 'BraveBackup.exe'
Write-Host "Kompilacja -> $output"
. $ps2.FullName
Invoke-ps2exe -inputFile $source -outputFile $output -noConsole -title 'Brave Backup Tool' -version '2.0.0.0.0'
if (Test-Path $output) {
    Write-Host "OK: $output ($([math]::Round((Get-Item $output).Length/1MB,2)) MB)" -ForegroundColor Green
} else {
    throw 'Brak pliku wyjsciowego'
}
