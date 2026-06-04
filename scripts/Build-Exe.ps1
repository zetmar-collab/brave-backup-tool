#Requires -Version 5.1
<#
.SYNOPSIS
    Buduje BraveBackup.exe z ikona (assets\BraveBackup.ico).
#>
param(
    [string]$Version = '2.1.0.0'
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

$i18nFile = Join-Path $scriptDir 'BraveBackup.I18n.ps1'
$guiFile  = Join-Path $scriptDir 'BraveBackup.Gui.ps1'
$bundle   = Join-Path $scriptDir 'BraveBackupTool.bundle.ps1'

if (-not (Test-Path $i18nFile)) { Write-Error "Brak: $i18nFile" }
if (-not (Test-Path $guiFile))  { Write-Error "Brak: $guiFile" }

$mainRaw = Get-Content $source -Raw -Encoding UTF8
$mainRaw = $mainRaw -replace '(?ms)\r?\n\$__toolDir = if \(\$PSScriptRoot\).*?\r?\nif \(Test-Path \$__i18nPath\) \{ \. \$__i18nPath \}\r?\n', "`n"
$mainRaw = $mainRaw -replace '(?ms)\r?\n\$__guiPath = Join-Path \$__toolDir.*?\. \$__guiPath\r?\n', "`n"

# Usun sekcje dot-source GUI — plik GUI (z uruchomieniem na koncu) dolaczamy na koniec bundla
$guiDotSource = 'BraveBackup.Gui.ps1'
$idxGui = $mainRaw.IndexOf($guiDotSource)
if ($idxGui -ge 0) {
    $lineStart = $mainRaw.LastIndexOf("`n", [Math]::Max(0, $idxGui - 200))
    if ($lineStart -lt 0) { $lineStart = 0 } else { $lineStart++ }
    $mainRaw = $mainRaw.Substring(0, $lineStart).TrimEnd()
}
# Usun naglowek sekcji GUI jesli zostal
if ($mainRaw -match '(?ms)(# ── GUI \(WPF\)[\s\S]*)$') {
    $tail = $Matches[1]
    if ($tail.Trim().Length -lt 80) {
        $mainRaw = $mainRaw.Substring(0, $mainRaw.Length - $tail.Length).TrimEnd()
    }
}

# i18n MUSI byc po bloku param() — inaczej EXE rzuca: "param is not recognized"
$i18nRaw = (Get-Content $i18nFile -Raw -Encoding UTF8).TrimEnd()
$guiRaw  = (Get-Content $guiFile -Raw -Encoding UTF8).TrimEnd()
$insertAt = $mainRaw.IndexOf('$Script:Lang = ''pl''')
if ($insertAt -lt 0) {
    Write-Error 'Nie znaleziono punktu wstawienia i18n w BraveBackupTool.ps1'
}
$mainHead = $mainRaw.Substring(0, $insertAt).TrimEnd()
$mainTail = $mainRaw.Substring($insertAt).TrimStart()
$bundleContent = @($mainHead, $i18nRaw, $mainTail, $guiRaw) -join "`n`n"
Set-Content -Path $bundle -Value $bundleContent -Encoding UTF8
$compileSource = $bundle

Write-Host "Bundle:    $bundle" -ForegroundColor DarkGray
Write-Host "Budowanie: $output" -ForegroundColor Cyan
Write-Host "Ikona:     $icon" -ForegroundColor Cyan
Invoke-ps2exe -inputFile $compileSource -outputFile $output -noConsole -iconFile $icon `
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
