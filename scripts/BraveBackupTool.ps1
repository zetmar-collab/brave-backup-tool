#Requires -Version 5.1
<#
.SYNOPSIS
    Brave Backup Tool — jeden plik: GUI (domyslnie) lub konsola (-Console).
.NOTES
    Zbuduj EXE: scripts\Build-Exe.ps1
#>
param(
    [switch]$Console
)

# StrictMode Latest + pojedynczy obiekt zamiast tablicy psuje .Count w skompilowanym EXE
Set-StrictMode -Off
$ErrorActionPreference = 'Stop'

# ── Sciezki (dziala jako .ps1 i jako skompilowane .exe) ─────────────────────

function Get-AppRoot {
    if ($PSScriptRoot) { return $PSScriptRoot }
    $exe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    if ($exe) { return (Split-Path -Parent $exe) }
    return (Get-Location).Path
}

function Get-AppIconPath {
    $root = Get-AppRoot
    $parent = Split-Path -Parent $root
    foreach ($p in @(
        (Join-Path $root 'assets\BraveBackup.ico'),
        (Join-Path $parent 'assets\BraveBackup.ico')
    )) {
        if (Test-Path $p) { return (Resolve-Path -LiteralPath $p).Path }
    }
    return $null
}

$AppRoot = Get-AppRoot
# Kopie w katalogu projektu (Brave-kopia\backups), nie w scripts\ gdy uruchomiono .ps1
$BackupParent = if ((Split-Path -Leaf $AppRoot) -eq 'scripts') {
    Split-Path -Parent $AppRoot
} else {
    $AppRoot
}

$Script:Config = @{
    BraveUserData   = Join-Path $env:LOCALAPPDATA 'BraveSoftware\Brave-Browser\User Data'
    BackupRoot      = Join-Path $BackupParent 'backups'
    MaxBackups      = 10
    CacheExclude    = @('Cache', 'Code Cache', 'GPUCache', 'DawnGraphiteCache', 'DawnWebGPUCache', 'ShaderCache', 'GrShaderCache', 'blob_storage')
    ImportantItems  = @(
        'Bookmarks', 'Bookmarks.bak', 'Cookies', 'Login Data', 'Login Data For Account',
        'History', 'Favicons', 'Preferences', 'Secure Preferences', 'Web Data',
        'Extension State', 'Extensions', 'Local Extension Settings', 'Sync Data',
        'BraveWallet', 'AdBlock Custom Resources',
        'Sessions', 'Session Storage', 'Last Session', 'Last Tabs',
        'Current Session', 'Current Tabs', 'Network', 'Top Sites', 'Visited Links'
    )
}

function Get-SettingsPath {
    return (Join-Path $BackupParent 'backup-settings.json')
}

function Load-BackupSettings {
    $path = Get-SettingsPath
    if (-not (Test-Path $path)) { return }
    try {
        $json = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($json.BackupRoot) {
            $Script:Config.BackupRoot = [string]$json.BackupRoot
        }
    } catch { }
}

function Save-BackupSettings {
    $path = Get-SettingsPath
    @{
        BackupRoot = $Script:Config.BackupRoot
        SavedAt    = (Get-Date -Format 'o')
    } | ConvertTo-Json | Set-Content $path -Encoding UTF8
}

function Ensure-BackupRootExists {
    if (-not (Test-Path $Script:Config.BackupRoot)) {
        New-Item -ItemType Directory -Path $Script:Config.BackupRoot -Force | Out-Null
    }
}

Load-BackupSettings
Ensure-BackupRootExists

# ── Logika wspolna ───────────────────────────────────────────────────────────

function Format-BackupDateTime ($value) {
    try {
        $dt = [DateTime]$value
        return ('{0:yyyy-MM-dd HH:mm}' -f $dt)
    } catch {
        return [string]$value
    }
}

function Format-Size ($bytes) {
    # Literaly zamiast 1GB/1MB — w skompilowanym EXE skroty bywaja niedostepne
    $n = 0.0
    try { $n = [double][long]$bytes } catch { $n = 0.0 }
    $gb = 1073741824.0
    $mb = 1048576.0
    $kb = 1024.0
    if ($n -ge $gb) { return ('{0:N2} GB' -f ($n / $gb)) }
    if ($n -ge $mb) { return ('{0:N2} MB' -f ($n / $mb)) }
    if ($n -ge $kb) { return ('{0:N2} KB' -f ($n / $kb)) }
    return ('{0} B' -f [long]$n)
}

function Get-FolderSize ([string]$path) {
    if (-not (Test-Path $path)) { return 0L }
    $sum = (Get-ChildItem $path -Recurse -File -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum).Sum
    if ($null -eq $sum) { return 0L }
    return [long]$sum
}

function Get-ArrayCount($items) {
    if ($null -eq $items) { return 0 }
    return @($items).Count
}

function Get-BraveProcesses {
    $p = Get-Process -Name 'brave' -ErrorAction SilentlyContinue
    if ($null -eq $p) { return @() }
    return @($p)
}

function Stop-AllBraveProcesses {
    $deadline = (Get-Date).AddSeconds(20)
    do {
        $procs = Get-BraveProcesses
        if ((Get-ArrayCount $procs) -eq 0) { return $true }
        foreach ($p in $procs) {
            Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)
    return ((Get-ArrayCount (Get-BraveProcesses)) -eq 0)
}

function Get-ProfilePaths {
    $root = $Script:Config.BraveUserData
    $dirs = @()
    $default = Join-Path $root 'Default'
    if (Test-Path $default) { $dirs += $default }
    $dirs += @(Get-ChildItem $root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^(Profile \d+|Guest Profile)$' } |
        Select-Object -ExpandProperty FullName)
    return @($dirs | Select-Object -Unique)
}

function Get-BackupList {
    if (-not (Test-Path $Script:Config.BackupRoot)) { return @() }
    return @(Get-ChildItem $Script:Config.BackupRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object CreationTime -Descending)
}

function Remove-OldBackups ([scriptblock]$OnLog) {
    $all = @(Get-BackupList)
    if ((Get-ArrayCount $all) -le $Script:Config.MaxBackups) { return }
    $toDelete = $all | Select-Object -Last ((Get-ArrayCount $all) - $Script:Config.MaxBackups)
    foreach ($old in $toDelete) {
        Remove-Item $old.FullName -Recurse -Force -ErrorAction SilentlyContinue
        if ($OnLog) { & $OnLog "Usunieto stara kopie: $($old.Name)" 'warn' }
    }
}

function Copy-ProfileItems {
    param(
        [string]$SourceProfile,
        [string]$DestProfile,
        [bool]$FullBackup,
        [scriptblock]$OnProgress,
        [scriptblock]$OnLog,
        [double]$ProgressBase = 0,
        [double]$ProgressSpan = 90
    )
    $copied = 0
    $errors = [System.Collections.Generic.List[string]]::new()

    if ($FullBackup) {
        $items = @(Get-ChildItem $SourceProfile -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notin $Script:Config.CacheExclude })
    } else {
        $items = @($Script:Config.ImportantItems | ForEach-Object {
            Get-Item (Join-Path $SourceProfile $_) -ErrorAction SilentlyContinue
        } | Where-Object { $null -ne $_ })
    }

    $total = [Math]::Max((Get-ArrayCount $items), 1)
    $i = 0
    foreach ($item in @($items)) {
        try {
            $dest = Join-Path $DestProfile $item.Name
            if ($item.PSIsContainer) {
                Copy-Item $item.FullName $dest -Recurse -Force -ErrorAction Stop
            } else {
                Copy-Item $item.FullName $dest -Force -ErrorAction Stop
            }
            $copied++
        } catch {
            $errors.Add("$($item.Name): $($_.Exception.Message)")
        }
        $i++
        if ($OnProgress) {
            $pct = [int]($ProgressBase + ($i / $total) * $ProgressSpan)
            & $OnProgress $pct
        }
    }

    if ($errors.Count -gt 0 -and $OnLog) {
        foreach ($e in $errors) { & $OnLog "  Blad: $e" 'err' }
    }
    return @{ Copied = $copied; Errors = $errors.Count }
}

function Invoke-BraveBackupCore {
    param(
        [bool]$FullBackup,
        [scriptblock]$OnProgress,
        [scriptblock]$OnLog
    )
    if (-not (Test-Path $Script:Config.BraveUserData)) {
        if ($OnLog) { & $OnLog "Nie znaleziono danych Brave: $($Script:Config.BraveUserData)" 'err' }
        return $false
    }

    $mode = if ($FullBackup) { 'pelna' } else { 'wybrane' }
    $stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $backupDir = Join-Path $Script:Config.BackupRoot "${stamp}_${mode}"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

    $meta = @{
        Created    = (Get-Date -Format 'o')
        Mode       = $mode
        SourcePath = $Script:Config.BraveUserData
        AppVersion = '2.0'
        Profiles   = @()
    }

    $profiles = Get-ProfilePaths
    if ((Get-ArrayCount $profiles) -eq 0) {
        if ($OnLog) { & $OnLog 'Brak profili Brave do skopiowania.' 'err' }
        return $false
    }

    $totalP = [Math]::Max((Get-ArrayCount $profiles), 1)
    $pIdx = 0
    foreach ($profilePath in $profiles) {
        $profileName = Split-Path $profilePath -Leaf
        if ($OnLog) { & $OnLog "Kopiuje profil: $profileName" 'info' }
        $destProfile = Join-Path $backupDir $profileName
        New-Item -ItemType Directory -Path $destProfile -Force | Out-Null

        $base = ($pIdx / $totalP) * 90
        $span = 90 / $totalP
        $result = Copy-ProfileItems -SourceProfile $profilePath -DestProfile $destProfile `
            -FullBackup $FullBackup -OnProgress $OnProgress -OnLog $OnLog `
            -ProgressBase $base -ProgressSpan $span

        if ($OnLog) {
            & $OnLog ("{0}: skopiowano {1} elementow, bledy: {2}" -f $profileName, $result.Copied, $result.Errors) 'ok'
        }
        $meta.Profiles += $profileName
        $pIdx++
    }

    $localState = Join-Path $Script:Config.BraveUserData 'Local State'
    if (Test-Path $localState) {
        Copy-Item $localState (Join-Path $backupDir 'Local State') -Force -ErrorAction SilentlyContinue
        if ($OnLog) { & $OnLog 'Skopiowano Local State.' 'ok' }
    }

    $meta | ConvertTo-Json -Depth 4 |
        Set-Content (Join-Path $backupDir 'backup-meta.json') -Encoding UTF8

    Remove-OldBackups -OnLog $OnLog
    if ($OnProgress) { & $OnProgress 100 }
    if ($OnLog) {
        & $OnLog ("Kopia gotowa: $backupDir") 'ok'
        & $OnLog ("Rozmiar: $(Format-Size (Get-FolderSize $backupDir))") 'info'
    }
    return $true
}

function Clear-ProfileDirectory ([string]$ProfilePath) {
    if (-not (Test-Path $ProfilePath)) { return }
    Get-ChildItem $ProfilePath -Force -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-BraveRestoreCore {
    param(
        [string]$BackupPath,
        [bool]$ReplaceProfile,
        [scriptblock]$OnProgress,
        [scriptblock]$OnLog
    )
    if (-not (Test-Path $BackupPath)) {
        if ($OnLog) { & $OnLog "Nie znaleziono kopii: $BackupPath" 'err' }
        return $false
    }

    $profileNames = @('Default')
    $profileNames += @(Get-ChildItem $BackupPath -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^(Profile \d+|Guest Profile)$' } |
        Select-Object -ExpandProperty Name)
    $profileNames = @($profileNames | Select-Object -Unique)

    $totalP = [Math]::Max((Get-ArrayCount $profileNames), 1)
    $pIdx = 0

    foreach ($profileName in $profileNames) {
        $srcProfile = Join-Path $BackupPath $profileName
        $destProfile = Join-Path $Script:Config.BraveUserData $profileName
        if (-not (Test-Path $srcProfile)) { $pIdx++; continue }

        if ($OnLog) { & $OnLog "Przywracam profil: $profileName" 'info' }
        if (-not (Test-Path $destProfile)) {
            New-Item -ItemType Directory -Path $destProfile -Force | Out-Null
        }
        if ($ReplaceProfile) {
            if ($OnLog) { & $OnLog "  Czyszczenie profilu przed przywroceniem..." 'warn' }
            Clear-ProfileDirectory $destProfile
        }

        $items = @(Get-ChildItem $srcProfile -ErrorAction SilentlyContinue)
        $total = [Math]::Max((Get-ArrayCount $items), 1)
        $copied = 0
        $errors = [System.Collections.Generic.List[string]]::new()
        $i = 0

        foreach ($item in @($items)) {
            try {
                $dest = Join-Path $destProfile $item.Name
                if ($item.PSIsContainer) {
                    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue }
                    Copy-Item $item.FullName $dest -Recurse -Force -ErrorAction Stop
                } else {
                    Copy-Item $item.FullName $dest -Force -ErrorAction Stop
                }
                $copied++
            } catch {
                $errors.Add("$($item.Name): $($_.Exception.Message)")
            }
            $i++
            if ($OnProgress) {
                $pct = [int](($pIdx / $totalP + $i / $total / $totalP) * 90)
                & $OnProgress $pct
            }
        }

        if ($errors.Count -gt 0 -and $OnLog) {
            foreach ($e in $errors) { & $OnLog "  Blad: $e" 'err' }
        }
        if ($OnLog) {
            & $OnLog ("{0}: przywrocono {1} elementow, bledy: {2}" -f $profileName, $copied, $errors.Count) 'ok'
        }
        $pIdx++
    }

    $srcLS = Join-Path $BackupPath 'Local State'
    if (Test-Path $srcLS) {
        Copy-Item $srcLS (Join-Path $Script:Config.BraveUserData 'Local State') -Force -ErrorAction SilentlyContinue
        if ($OnLog) { & $OnLog 'Przywrocono Local State.' 'ok' }
    }

    if ($OnProgress) { & $OnProgress 100 }
    if ($OnLog) { & $OnLog 'Przywracanie zakonczone. Mozesz uruchomic Brave.' 'ok' }
    return $true
}

function Request-BraveCloseConfirmation {
    param(
        [bool]$UseConsolePrompt = $false,
        [string]$PromptMessage = 'Brave jest uruchomiony. Zamknac wszystkie procesy Brave?'
    )
    $procs = Get-BraveProcesses
    if ((Get-ArrayCount $procs) -eq 0) { return $true }

    if ($UseConsolePrompt) {
        Write-Warn "Brave: $(Get-ArrayCount $procs) proces(ow)."
        $answer = Read-Host '  Zamknac Brave automatycznie? [T/n]'
        return ($answer -ne 'n' -and $answer -ne 'N')
    }

    Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
    $result = [System.Windows.MessageBox]::Show(
        "$PromptMessage`n`nAktywnych procesow: $(Get-ArrayCount $procs)",
        'Brave Backup Tool', 'YesNo', 'Warning')
    return ($result -eq 'Yes')
}

function Ensure-BraveClosedForOperation {
    param(
        [bool]$SkipPrompt = $false,
        [bool]$UseConsolePrompt = $false
    )
    if (-not $SkipPrompt) {
        if (-not (Request-BraveCloseConfirmation -UseConsolePrompt $UseConsolePrompt)) {
            return $false
        }
    }
    if ((Get-ArrayCount (Get-BraveProcesses)) -eq 0) { return $true }
    if ($UseConsolePrompt) { Write-Info 'Zamykam wszystkie procesy Brave...' }
    if (-not (Stop-AllBraveProcesses)) {
        if ($UseConsolePrompt) { Write-Err 'Nie udalo sie zamknac Brave. Zamknij go recznie.' }
        return $false
    }
    if ($UseConsolePrompt) { Write-Success 'Brave zamkniety.' }
    return $true
}

# ── Konsola ──────────────────────────────────────────────────────────────────

function Write-Header {
    Clear-Host
    Write-Host ('=' * 60) -ForegroundColor Cyan
    Write-Host '   BRAVE BACKUP TOOL v2' -ForegroundColor Cyan
    Write-Host ('=' * 60) -ForegroundColor Cyan
    Write-Host ''
}
function Write-Status ([string]$msg, [string]$color = 'White') { Write-Host "  $msg" -ForegroundColor $color }
function Write-Success ([string]$msg) { Write-Status "OK  $msg" 'Green' }
function Write-Warn ([string]$msg) { Write-Status "!   $msg" 'Yellow' }
function Write-Err ([string]$msg) { Write-Status "X   $msg" 'Red' }
function Write-Info ([string]$msg) { Write-Status ">>  $msg" 'Cyan' }

function Show-Backups ($backups) {
    if ((Get-ArrayCount $backups) -eq 0) { Write-Warn 'Brak kopii zapasowych.'; return }
    Write-Host ''
    Write-Host '  Nr  Nazwa                          Data              Rozmiar' -ForegroundColor DarkGray
    Write-Host '  --  -----------------------------  ----------------  -------' -ForegroundColor DarkGray
    $i = 1
    foreach ($b in $backups) {
        $size = Format-Size (Get-FolderSize $b.FullName)
        $date = Format-BackupDateTime $b.CreationTime
        Write-Host ("  {0,-2}  {1,-29}  {2}  {3,8}" -f $i, $b.Name, $date, $size) -ForegroundColor $(if ($i -eq 1) { 'White' } else { 'Gray' })
        $i++
    }
    Write-Host ''
}

function Pause-AndReturn {
    Write-Host ''
    Read-Host '  [Enter] aby kontynuowac'
}

function Start-ConsoleApp {
    function Invoke-BackupMenu ([bool]$fullBackup) {
        Write-Header
        Write-Info 'TWORZENIE KOPII ZAPASOWEJ'
        Write-Host ''
        if (-not (Ensure-BraveClosedForOperation -UseConsolePrompt $true)) {
            Write-Warn 'Anulowano (Brave nadal dziala).'
            Pause-AndReturn
            return
        }
        $log = { param($m, $t)
            switch ($t) {
                'ok'   { Write-Success $m }
                'err'  { Write-Err $m }
                'warn' { Write-Warn $m }
                default { Write-Info $m }
            }
        }
        Invoke-BraveBackupCore -FullBackup $fullBackup -OnLog $log | Out-Null
        Pause-AndReturn
    }

    function Invoke-RestoreMenu {
        Write-Header
        Write-Info 'PRZYWRACANIE'
        $backups = @(Get-BackupList)
        Show-Backups $backups
        if ((Get-ArrayCount $backups) -eq 0) { Pause-AndReturn; return }
        $choice = Read-Host '  Numer kopii (Enter = anuluj)'
        if ([string]::IsNullOrWhiteSpace($choice)) { return }
        $idx = 0
        if (-not [int]::TryParse($choice, [ref]$idx) -or $idx -lt 1 -or $idx -gt (Get-ArrayCount $backups)) {
            Write-Err 'Nieprawidlowy numer.'; Pause-AndReturn; return
        }
        $selected = $backups[$idx - 1]
        Write-Warn "Wybrano: $($selected.Name)"
        Write-Warn 'Przywrocenie NADPISZE dane Brave!'
        $confirm = Read-Host '  Potwierdz wpisujac: tak'
        if ($confirm -ne 'tak') { Write-Info 'Anulowano.'; Pause-AndReturn; return }
        $replace = Read-Host '  Pelne przywrocenie (usun pliki spoza kopii)? [T/n]'
        $replaceProfile = ($replace -ne 'n' -and $replace -ne 'N')
        if (-not (Ensure-BraveClosedForOperation -UseConsolePrompt $true)) { Pause-AndReturn; return }
        $log = { param($m, $t)
            switch ($t) {
                'ok'   { Write-Success $m }
                'err'  { Write-Err $m }
                'warn' { Write-Warn $m }
                default { Write-Info $m }
            }
        }
        Invoke-BraveRestoreCore -BackupPath $selected.FullName -ReplaceProfile $replaceProfile -OnLog $log | Out-Null
        Pause-AndReturn
    }

    function Invoke-DeleteMenu {
        Write-Header
        $backups = @(Get-BackupList)
        Show-Backups $backups
        if ((Get-ArrayCount $backups) -eq 0) { Pause-AndReturn; return }
        $choice = Read-Host '  Numer do usuniecia'
        if ([string]::IsNullOrWhiteSpace($choice)) { return }
        $idx = 0
        if (-not [int]::TryParse($choice, [ref]$idx) -or $idx -lt 1 -or $idx -gt (Get-ArrayCount $backups)) {
            Write-Err 'Nieprawidlowy numer.'; Pause-AndReturn; return
        }
        $selected = $backups[$idx - 1]
        $confirm = Read-Host "  Usunac '$($selected.Name)'? [T/n]"
        if ($confirm -eq 'n' -or $confirm -eq 'N') { return }
        Remove-Item $selected.FullName -Recurse -Force
        Write-Success "Usunieto: $($selected.Name)"
        Pause-AndReturn
    }

    do {
        Write-Header
        $braveOk = Test-Path $Script:Config.BraveUserData
        $procs = Get-BraveProcesses
        $backups = @(Get-BackupList)
        Write-Host '  Status:' -ForegroundColor DarkGray
        Write-Host "    Dane Brave:  $(if ($braveOk) { 'OK' } else { 'BRAK' })" -ForegroundColor $(if ($braveOk) { 'Green' } else { 'Red' })
        Write-Host "    Procesy:     $(Get-ArrayCount $procs)" -ForegroundColor Gray
        Write-Host "    Kopie:       $(Get-ArrayCount $backups) / $($Script:Config.MaxBackups)" -ForegroundColor Gray
        Write-Host "    Folder:      $($Script:Config.BackupRoot)" -ForegroundColor Gray
        Write-Host ''
        Write-Host '  [1] Pelna kopia  [2] Kluczowe dane  [3] Przywroc  [4] Usun  [Q] Wyjdz' -ForegroundColor White
        $key = Read-Host '  Wybor'
        switch ($key.Trim().ToUpper()) {
            '1' { Invoke-BackupMenu -fullBackup $true }
            '2' { Invoke-BackupMenu -fullBackup $false }
            '3' { Invoke-RestoreMenu }
            '4' { Invoke-DeleteMenu }
            'Q' { break }
            default { Write-Warn 'Nieznana opcja.'; Pause-AndReturn }
        }
    } while ($key.Trim().ToUpper() -ne 'Q')
}

# ── GUI (WPF) ────────────────────────────────────────────────────────────────

function Start-GuiApp {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

    $xamlText = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Brave Backup Tool" Height="620" Width="840"
    WindowStartupLocation="CenterScreen" ResizeMode="CanMinimize" Background="#1a1a2e">
  <Window.Resources>
    <Style x:Key="Btn" TargetType="Button">
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Padding" Value="14,8"/>
      <Setter Property="Margin" Value="4"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="6" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Opacity" Value="0.85"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="bd" Property="Background" Value="#444"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="ListBoxItem">
      <Setter Property="Foreground" Value="#ddd"/>
      <Setter Property="Padding" Value="8,6"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ListBoxItem">
            <Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="#333" BorderThickness="0,0,0,1" Padding="{TemplateBinding Padding}">
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsSelected" Value="True"><Setter TargetName="bd" Property="Background" Value="#2a3a5e"/></Trigger>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="#22304a"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>
  <Grid Margin="16">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/><RowDefinition Height="160"/>
    </Grid.RowDefinitions>
    <DockPanel Grid.Row="0" Margin="0,0,0,10">
      <TextBlock Text="BRAVE BACKUP TOOL v2" Foreground="#e25c1e" FontSize="20" FontWeight="Bold"/>
      <TextBlock x:Name="txtBusy" Text="  [pracuje...]" Foreground="#fa0" Margin="12,0,0,0" Visibility="Collapsed"/>
      <TextBlock x:Name="txtStatus" Foreground="#888" FontSize="10" Margin="16,4,0,0" TextWrapping="Wrap"/>
    </DockPanel>
    <WrapPanel Grid.Row="1">
      <Button x:Name="btnFull" Content="Pelna kopia" Background="#e25c1e" Style="{StaticResource Btn}"/>
      <Button x:Name="btnKey" Content="Kluczowe dane" Background="#c0631e" Style="{StaticResource Btn}"/>
      <Button x:Name="btnRestore" Content="Przywroc" Background="#2d5a8e" Style="{StaticResource Btn}"/>
      <Button x:Name="btnDelete" Content="Usun" Background="#7a1a1a" Style="{StaticResource Btn}"/>
      <Button x:Name="btnRefresh" Content="Odswiez" Background="#2d2d4e" Style="{StaticResource Btn}"/>
      <Button x:Name="btnFolder" Content="Ustaw folder kopii" Background="#2d2d4e" Style="{StaticResource Btn}"/>
    </WrapPanel>
    <Border Grid.Row="2" Background="#12122a" CornerRadius="8">
      <ListBox x:Name="lstBackups" Background="Transparent" BorderThickness="0">
        <ListBox.ItemTemplate>
          <DataTemplate>
            <Grid>
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/><ColumnDefinition Width="150"/><ColumnDefinition Width="80"/>
              </Grid.ColumnDefinitions>
              <TextBlock Text="{Binding Name}" Foreground="White"/>
              <TextBlock Grid.Column="1" Text="{Binding DateStr}" Foreground="#aaa"/>
              <TextBlock Grid.Column="2" Text="{Binding SizeStr}" Foreground="#6af"/>
            </Grid>
          </DataTemplate>
        </ListBox.ItemTemplate>
      </ListBox>
    </Border>
    <Grid Grid.Row="3" Margin="0,8,0,4">
      <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="40"/></Grid.ColumnDefinitions>
      <ProgressBar x:Name="progress" Height="7" Maximum="100"/>
      <TextBlock x:Name="txtPct" Grid.Column="1" Text="0%" Foreground="#aaa" Margin="6,0,0,0"/>
    </Grid>
    <Border Grid.Row="4" Background="#0d0d1e" CornerRadius="8" Padding="8">
      <ScrollViewer x:Name="logScroll" VerticalScrollBarVisibility="Auto">
        <TextBlock x:Name="txtLog" Foreground="#7af" FontFamily="Consolas" FontSize="11" TextWrapping="Wrap"/>
      </ScrollViewer>
    </Border>
  </Grid>
</Window>
'@

    $window = [Windows.Markup.XamlReader]::Parse($xamlText)
    $iconPath = Get-AppIconPath
    if ($iconPath) {
        $window.Icon = [System.Windows.Media.Imaging.BitmapFrame]::Create(
            [Uri]::new($iconPath, [UriKind]::Absolute))
    }
    $c = @{
        btnFull = $window.FindName('btnFull'); btnKey = $window.FindName('btnKey')
        btnRestore = $window.FindName('btnRestore'); btnDelete = $window.FindName('btnDelete')
        btnRefresh = $window.FindName('btnRefresh'); btnFolder = $window.FindName('btnFolder')
        lst = $window.FindName('lstBackups'); txtLog = $window.FindName('txtLog')
        logScroll = $window.FindName('logScroll'); txtStatus = $window.FindName('txtStatus')
        progress = $window.FindName('progress'); txtPct = $window.FindName('txtPct')
        txtBusy = $window.FindName('txtBusy')
    }

    function Invoke-OnUi([scriptblock]$action) {
        if ($window.Dispatcher.CheckAccess()) {
            & $action
        } else {
            $window.Dispatcher.Invoke($action)
        }
    }

    function Gui-Log ([string]$msg, [string]$type = 'info') {
        $p = switch ($type) { 'ok' { '[OK]  ' } 'err' { '[ERR] ' } 'warn' { '[!]   ' } default { '[>>]  ' } }
        $line = "[$(Get-Date -Format 'HH:mm:ss')] $p$msg`n"
        Invoke-OnUi { $c.txtLog.Text += $line; $c.logScroll.ScrollToEnd() }
    }
    function Gui-Pct ([int]$v) {
        Invoke-OnUi { $c.progress.Value = $v; $c.txtPct.Text = "$v%" }
    }
    function Gui-Busy ([bool]$on) {
        Invoke-OnUi {
            $c.txtBusy.Visibility = if ($on) { 'Visible' } else { 'Collapsed' }
            foreach ($b in @($c.btnFull, $c.btnKey, $c.btnRestore, $c.btnDelete)) { $b.IsEnabled = -not $on }
        }
    }
    function Gui-Refresh {
        $backups = @(Get-BackupList)
        $rows = foreach ($b in $backups) {
            [PSCustomObject]@{
                Name     = $b.Name
                DateStr  = Format-BackupDateTime $b.CreationTime
                SizeStr  = Format-Size (Get-FolderSize $b.FullName)
                FullPath = $b.FullName
            }
        }
        $procCount = Get-ArrayCount (Get-BraveProcesses)
        $backupCount = Get-ArrayCount $backups
        $status = "Brave: $procCount proces(ow) | Kopie: $backupCount/$($Script:Config.MaxBackups) | $($Script:Config.BackupRoot)"
        Invoke-OnUi {
            $c.lst.ItemsSource = $null
            $c.lst.ItemsSource = @($rows)
            $c.txtStatus.Text = $status
        }
    }

    function Start-GuiWorker {
        param([bool]$Restore, [bool]$Full = $false, [string]$Path = '', [bool]$Replace = $false)

        try {
            if (-not (Ensure-BraveClosedForOperation)) {
                Gui-Log 'Anulowano — zamknij Brave lub potwierdz zamkniecie.' 'warn'
                return
            }
            Gui-Busy $true

            # Jawne bool + $script: — w EXE zmienne z closure bywaja "" zamiast $false
            $script:PendingGuiWork = @{
                DoRestore        = [bool]$Restore
                FullBackup       = [bool]$Full
                BackupPath       = [string]$Path
                ReplaceProfile   = [bool]$Replace
            }

            $null = $window.Dispatcher.BeginInvoke(
                [System.Windows.Threading.DispatcherPriority]::Background,
                [action]{
                    $w = $script:PendingGuiWork
                    $prevEA = $ErrorActionPreference
                    $ErrorActionPreference = 'Continue'
                    try {
                        if (-not (Stop-AllBraveProcesses)) {
                            Gui-Log 'Nie udalo sie zamknac wszystkich procesow Brave.' 'err'
                            return
                        }
                        $onLog = { param($m, $t) Gui-Log $m $t }
                        $onPct = { param($v) Gui-Pct $v }
                        if ($w.DoRestore) {
                            if ($w.ReplaceProfile) {
                                [void](Invoke-BraveRestoreCore -BackupPath $w.BackupPath -ReplaceProfile $true -OnProgress $onPct -OnLog $onLog)
                            } else {
                                [void](Invoke-BraveRestoreCore -BackupPath $w.BackupPath -ReplaceProfile $false -OnProgress $onPct -OnLog $onLog)
                            }
                        } elseif ($w.FullBackup) {
                            [void](Invoke-BraveBackupCore -FullBackup $true -OnProgress $onPct -OnLog $onLog)
                        } else {
                            [void](Invoke-BraveBackupCore -FullBackup $false -OnProgress $onPct -OnLog $onLog)
                        }
                    } catch {
                        Gui-Log "BLAD: $($_.Exception.Message)" 'err'
                    } finally {
                        $ErrorActionPreference = $prevEA
                        Invoke-OnUi { $c.progress.Value = 0; $c.txtPct.Text = '0%' }
                        Gui-Busy $false
                        Gui-Refresh
                    }
                })
        } catch {
            Gui-Log "BLAD uruchomienia: $($_.Exception.Message)" 'err'
            Gui-Busy $false
        }
    }

    function Select-BackupFolder {
        Add-Type -AssemblyName System.Windows.Forms
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = 'Wybierz folder, w ktorym maja byc zapisywane kopie Brave'
        $dlg.ShowNewFolderButton = $true
        if (Test-Path $Script:Config.BackupRoot) {
            $dlg.SelectedPath = $Script:Config.BackupRoot
        }
        if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return $false }
        $Script:Config.BackupRoot = $dlg.SelectedPath
        Ensure-BackupRootExists
        Save-BackupSettings
        return $true
    }

    $c.btnFull.Add_Click({
        try { Gui-Log 'Pelna kopia...'; Start-GuiWorker -Restore $false -Full $true }
        catch { Gui-Log "BLAD: $($_.Exception.Message)" 'err'; Gui-Busy $false }
    })
    $c.btnKey.Add_Click({
        try { Gui-Log 'Kopia kluczowych danych...'; Start-GuiWorker -Restore $false -Full $false }
        catch { Gui-Log "BLAD: $($_.Exception.Message)" 'err'; Gui-Busy $false }
    })
    $c.btnRestore.Add_Click({
        $sel = $c.lst.SelectedItem
        if (-not $sel) {
            [System.Windows.MessageBox]::Show('Zaznacz kopie na liscie.', 'Brak wyboru') | Out-Null
            return
        }
        $ans = [System.Windows.MessageBox]::Show(
            "Przywrocic:`n$($sel.Name)`n`nBiezacy profil zostanie nadpisany.",
            'Potwierdzenie', 'YesNo', 'Warning')
        if ($ans -ne 'Yes') { return }
        $ans2 = [System.Windows.MessageBox]::Show(
            "Pelne przywrocenie profilu?`n`nTAK = usunie pliki spoza kopii przed przywroceniem`nNIE = tylko nadpisze pliki z kopii",
            'Tryb przywrocenia', 'YesNoCancel', 'Question')
        if ($ans2 -eq 'Cancel') { return }
        $replace = ($ans2 -eq 'Yes')
        Gui-Log "Przywracam: $($sel.Name) (pelne=$replace)..."
        Start-GuiWorker -Restore $true -Path $sel.FullPath -Replace $replace
    })
    $c.btnDelete.Add_Click({
        $sel = $c.lst.SelectedItem
        if (-not $sel) { return }
        if ([System.Windows.MessageBox]::Show("Usunac:`n$($sel.Name)?", 'Usuwanie', 'YesNo') -ne 'Yes') { return }
        Remove-Item $sel.FullPath -Recurse -Force -ErrorAction SilentlyContinue
        Gui-Log "Usunieto: $($sel.Name)" 'warn'
        Gui-Refresh
    })
    $c.btnRefresh.Add_Click({
        Gui-Refresh
        Gui-Log 'Lista odswiezona.' 'info'
    })
    $c.btnFolder.Add_Click({
        if (Select-BackupFolder) {
            Gui-Refresh
            Gui-Log "Folder kopii: $($Script:Config.BackupRoot)" 'ok'
        }
    })

    Gui-Refresh
    Gui-Log 'Uruchomiono Brave Backup Tool v2'
    Gui-Log "Kopie: $($Script:Config.BackupRoot)"
    $null = $window.ShowDialog()
}

# ── Start ────────────────────────────────────────────────────────────────────

if ($Console) {
    Start-ConsoleApp
} else {
    Start-GuiApp
}
