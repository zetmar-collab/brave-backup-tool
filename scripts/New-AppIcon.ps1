#Requires -Version 5.1
# Generuje assets\BraveBackup.ico (pomaranczowe B na ciemnym tle)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$outDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets'
$outFile = Join-Path $outDir 'BraveBackup.ico'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function New-IconBitmap ([int]$size) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::FromArgb(255, 26, 26, 46))
    $orange = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 226, 92, 30))
    $margin = [int]($size * 0.12)
    $d = $size - (2 * $margin)
    $g.FillEllipse($orange, $margin, $margin, $d, $d)
    $fontSize = [int]($size * 0.42)
    $font = New-Object System.Drawing.Font 'Segoe UI', $fontSize, ([System.Drawing.FontStyle]::Bold)
    $text = 'B'
    $sz = $g.MeasureString($text, $font)
    $x = ($size - $sz.Width) / 2
    $y = ($size - $sz.Height) / 2 - ($size * 0.04)
    $g.DrawString($text, $font, [System.Drawing.Brushes]::White, $x, $y)
    $g.Dispose()
    return $bmp
}

# Najwiekszy rozmiar jako podstawa pliku .ico
$bmp256 = New-IconBitmap 256
$hIcon = $bmp256.GetHicon()
$icon = [System.Drawing.Icon]::FromHandle($hIcon)
$stream = [System.IO.File]::Open($outFile, [System.IO.FileMode]::Create)
try {
    $icon.Save($stream)
} finally {
    $stream.Close()
    $icon.Dispose()
    $bmp256.Dispose()
}

Write-Host "Ikona: $outFile" -ForegroundColor Green
