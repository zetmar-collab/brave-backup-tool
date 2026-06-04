#Requires -Version 5.1
<#
.SYNOPSIS
    Brave Backup Tool — jeden plik: GUI (domyslnie) lub konsola (-Console).
.NOTES
    Zbuduj EXE: scripts\Build-Exe.ps1
#>
param(
    # [object] zamiast [switch] — ps2exe/EXE czesto przekazuje string do parametrow bool
    [Parameter()][object]$Console = $null,
    [ValidateSet('pl', 'en', '')]
    [string]$Lang = ''
)

# StrictMode Latest + pojedynczy obiekt zamiast tablicy psuje .Count w skompilowanym EXE
Set-StrictMode -Off
$ErrorActionPreference = 'Stop'

function Test-FlagOn([object]$value) {
    if ($null -eq $value) { return $false }
    if ($value -is [switch]) { return $value.IsPresent }
    if ($value -is [bool]) { return $value }
    $s = [string]$value
    if ([string]::IsNullOrWhiteSpace($s)) { return $false }
    return ($s -match '^(?i)(true|1|yes|y|console|on)$')
}

function Convert-ToBoolParam([object]$value, [bool]$default = $false) {
    if ($null -eq $value) { return $default }
    if ($value -is [bool]) { return $value }
    if ($value -is [switch]) { return $value.IsPresent }
    $s = [string]$value
    if ([string]::IsNullOrWhiteSpace($s)) { return $default }
    if ($s -match '^(?i)(false|0|no|n|off)$') { return $false }
    return ($s -match '^(?i)(true|1|yes|y|on)$')
}

$Script:UseConsole = Test-FlagOn $Console

$__toolDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$__i18nPath = Join-Path $__toolDir 'BraveBackup.I18n.ps1'
if (Test-Path $__i18nPath) { . $__i18nPath }

$Script:Lang = 'pl'
$Script:OnboardingCompleted = $false
$Script:GitHubReleasesUrl = 'https://github.com/zetmar-collab/brave-backup-tool/releases/latest'

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

function Get-AllowedMaxBackups([int]$value) {
    $allowed = @(5, 10, 15, 20)
    if ($value -in $allowed) { return $value }
    if ($value -le 7) { return 5 }
    if ($value -le 12) { return 10 }
    if ($value -le 17) { return 15 }
    return 20
}

function Load-BackupSettings {
    $path = Get-SettingsPath
    if (-not (Test-Path $path)) { return }
    try {
        $json = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($json.BackupRoot) {
            $Script:Config.BackupRoot = [string]$json.BackupRoot
        }
        if ($json.Language -eq 'pl' -or $json.Language -eq 'en') {
            $Script:Lang = [string]$json.Language
        }
        if ($null -ne $json.OnboardingCompleted) {
            $Script:OnboardingCompleted = [bool]$json.OnboardingCompleted
        }
        if ($json.MaxBackups) {
            $Script:Config.MaxBackups = Get-AllowedMaxBackups ([int]$json.MaxBackups)
        }
    } catch { }
}

function Save-BackupSettings {
    $path = Get-SettingsPath
    @{
        BackupRoot           = $Script:Config.BackupRoot
        Language             = $Script:Lang
        OnboardingCompleted  = $Script:OnboardingCompleted
        MaxBackups           = $Script:Config.MaxBackups
        SavedAt              = (Get-Date -Format 'o')
    } | ConvertTo-Json | Set-Content $path -Encoding UTF8
}

function Get-LastBackupInfo {
    $list = @(Get-BackupList)
    if ((Get-ArrayCount $list) -eq 0) { return $null }
    $b = $list | Select-Object -First 1
    return @{
        Name = $b.Name
        Date = Format-BackupDateTime $b.CreationTime
        Path = $b.FullName
    }
}

function Ensure-BackupRootExists {
    if (-not (Test-Path $Script:Config.BackupRoot)) {
        New-Item -ItemType Directory -Path $Script:Config.BackupRoot -Force | Out-Null
    }
}

Load-BackupSettings
if ($Lang -eq 'pl' -or $Lang -eq 'en') { $Script:Lang = $Lang }
Initialize-I18n
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
        if ($OnLog) { & $OnLog (Tf 'LogOldRemoved' @($old.Name)) 'warn' }
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
        if ($OnLog) { & $OnLog (Tf 'LogCopyingItem' @($item.Name)) 'info' }
        if ($OnProgress) {
            $pct = [int]($ProgressBase + ($i / $total) * $ProgressSpan)
            & $OnProgress $pct
        }
    }

    if ($errors.Count -gt 0 -and $OnLog) {
        foreach ($e in $errors) { & $OnLog (Tf 'LogErrItem' @($e)) 'err' }
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
        if ($OnLog) { & $OnLog (Tf 'MsgNoBraveData' @($Script:Config.BraveUserData)) 'err' }
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
        AppVersion = '2.1'
        Profiles   = @()
    }

    $profiles = Get-ProfilePaths
    if ((Get-ArrayCount $profiles) -eq 0) {
        if ($OnLog) { & $OnLog (T 'MsgNoProfiles') 'err' }
        return $false
    }

    $totalP = [Math]::Max((Get-ArrayCount $profiles), 1)
    $pIdx = 0
    foreach ($profilePath in $profiles) {
        $profileName = Split-Path $profilePath -Leaf
        if ($OnLog) { & $OnLog (Tf 'LogCopyingProfile' @($profileName)) 'info' }
        $destProfile = Join-Path $backupDir $profileName
        New-Item -ItemType Directory -Path $destProfile -Force | Out-Null

        $base = ($pIdx / $totalP) * 90
        $span = 90 / $totalP
        $result = Copy-ProfileItems -SourceProfile $profilePath -DestProfile $destProfile `
            -FullBackup $FullBackup -OnProgress $OnProgress -OnLog $OnLog `
            -ProgressBase $base -ProgressSpan $span

        if ($OnLog) {
            & $OnLog (Tf 'LogProfileDone' @($profileName, $result.Copied, $result.Errors)) 'ok'
        }
        $meta.Profiles += $profileName
        $pIdx++
    }

    $localState = Join-Path $Script:Config.BraveUserData 'Local State'
    if (Test-Path $localState) {
        Copy-Item $localState (Join-Path $backupDir 'Local State') -Force -ErrorAction SilentlyContinue
        if ($OnLog) { & $OnLog (T 'LogLocalState') 'ok' }
    }

    $meta | ConvertTo-Json -Depth 4 |
        Set-Content (Join-Path $backupDir 'backup-meta.json') -Encoding UTF8

    Remove-OldBackups -OnLog $OnLog
    if ($OnProgress) { & $OnProgress 100 }
    if ($OnLog) {
        & $OnLog (Tf 'LogDone' @($backupDir)) 'ok'
        & $OnLog (Tf 'LogSize' @(Format-Size (Get-FolderSize $backupDir))) 'info'
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
        if ($OnLog) { & $OnLog (Tf 'MsgBackupNotFound' @($BackupPath)) 'err' }
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

        if ($OnLog) { & $OnLog (Tf 'LogRestoreProfile' @($profileName)) 'info' }
        if (-not (Test-Path $destProfile)) {
            New-Item -ItemType Directory -Path $destProfile -Force | Out-Null
        }
        if ($ReplaceProfile) {
            if ($OnLog) { & $OnLog (T 'LogClearProfile') 'warn' }
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
            foreach ($e in $errors) { & $OnLog (Tf 'LogErrItem' @($e)) 'err' }
        }
        if ($OnLog) {
            & $OnLog (Tf 'LogRestoreProfileDone' @($profileName, $copied, $errors.Count)) 'ok'
        }
        $pIdx++
    }

    $srcLS = Join-Path $BackupPath 'Local State'
    if (Test-Path $srcLS) {
        Copy-Item $srcLS (Join-Path $Script:Config.BraveUserData 'Local State') -Force -ErrorAction SilentlyContinue
        if ($OnLog) { & $OnLog (T 'LogRestoredLS') 'ok' }
    }

    if ($OnProgress) { & $OnProgress 100 }
    if ($OnLog) { & $OnLog (T 'LogRestoreDone') 'ok' }
    return $true
}

function Invoke-PreRestoreBackup {
    param(
        [scriptblock]$OnLog,
        [scriptblock]$OnProgress
    )
    if ($OnLog) { & $OnLog (T 'LogPreRestore') 'info' }
    return Invoke-BraveBackupCore -FullBackup $false -OnLog $OnLog -OnProgress $OnProgress
}

function Request-BraveCloseConfirmation {
    param(
        [bool]$UseConsolePrompt = $false,
        [string]$PromptMessage = ''
    )
    if (-not $PromptMessage) { $PromptMessage = T 'MsgCloseBrave' }
    $procs = Get-BraveProcesses
    if ((Get-ArrayCount $procs) -eq 0) { return $true }

    if ($UseConsolePrompt) {
        Write-Warn "Brave: $(Get-ArrayCount $procs) proces(ow)."
        $answer = Read-Host '  Zamknac Brave automatycznie? [T/n]'
        return ($answer -ne 'n' -and $answer -ne 'N')
    }

    Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
    $result = [System.Windows.MessageBox]::Show(
        "$PromptMessage`n`n$(Tf 'MsgCloseBraveProcs' @(Get-ArrayCount $procs))",
        (T 'AppTitle'), 'YesNo', 'Warning')
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
    Write-Host "   $(T 'AppTitle') $(T 'AppVersion')" -ForegroundColor Cyan
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
            Write-Warn (T 'LogOpCanceled')
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
        Write-Host "  $(T 'ConsoleMenu')" -ForegroundColor White
        $key = Read-Host '  >'
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

$__guiPath = Join-Path $__toolDir 'BraveBackup.Gui.ps1'
if (-not (Test-Path $__guiPath)) {
    throw "Brak pliku GUI: $__guiPath"
}
. $__guiPath
