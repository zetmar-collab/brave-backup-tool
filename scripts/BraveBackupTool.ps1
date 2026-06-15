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
$Script:AppVersion = '2.2.0'
$Script:GitHubRepoUrl = 'https://github.com/zetmar-collab/brave-backup-tool'
$Script:GitHubReleasesUrl = "$Script:GitHubRepoUrl/releases/latest"

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
    RootFiles       = @('Local State', 'Last Browser', 'Last Version', 'First Run')
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

function Get-FreeSpace ([string]$path) {
    # Wolne miejsce na dysku, na ktorym lezy $path (dziala tez gdy katalog jeszcze nie istnieje)
    try {
        $probe = $path
        while ($probe -and -not (Test-Path $probe)) { $probe = Split-Path -Parent $probe }
        if (-not $probe) { return [long]::MaxValue }
        $root = [System.IO.Path]::GetPathRoot((Resolve-Path -LiteralPath $probe).Path)
        $drive = New-Object System.IO.DriveInfo($root)
        return [long]$drive.AvailableFreeSpace
    } catch {
        return [long]::MaxValue
    }
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
    $deadline = (Get-Date).AddSeconds(30)
    $procNames = @('brave', 'BraveCrashHandler', 'bravecrashhandler')
    do {
        $alive = @()
        foreach ($pn in $procNames) {
            $alive += @(Get-Process -Name $pn -ErrorAction SilentlyContinue)
        }
        if ((Get-ArrayCount $alive) -eq 0) {
            Start-Sleep -Milliseconds 800
            return $true
        }
        foreach ($p in $alive) {
            Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        }
        Start-Sleep -Milliseconds 600
    } while ((Get-Date) -lt $deadline)
    $left = 0
    foreach ($pn in $procNames) {
        $left += (Get-ArrayCount (Get-Process -Name $pn -ErrorAction SilentlyContinue))
    }
    return ($left -eq 0)
}

function Get-BraveLocalStatePath {
    return (Join-Path $Script:Config.BraveUserData 'Local State')
}

function Get-BraveProfileEntries {
    $root = $Script:Config.BraveUserData
    $entries = [System.Collections.Generic.List[object]]::new()
    $seen = @{}

    $lsPath = Get-BraveLocalStatePath
    if (Test-Path $lsPath) {
        try {
            $ls = Get-Content $lsPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $cache = $ls.profile.info_cache
            if ($null -ne $cache) {
                foreach ($prop in $cache.PSObject.Properties) {
                    $folder = [string]$prop.Name
                    if ($folder -eq 'System Profile') { continue }
                    $profilePath = Join-Path $root $folder
                    $pref = Join-Path $profilePath 'Preferences'
                    if (-not (Test-Path $pref)) { continue }
                    if ($seen.ContainsKey($folder)) { continue }
                    $seen[$folder] = $true
                    $label = ''
                    try { $label = [string]$prop.Value.name } catch { }
                    if ([string]::IsNullOrWhiteSpace($label)) { $label = $folder }
                    $entries.Add([PSCustomObject]@{
                        Folder = $folder
                        Label  = $label
                        Path   = $profilePath
                    })
                }
            }
        } catch { }
    }

    if ($entries.Count -eq 0) {
        $candidates = @('Default')
        $candidates += @(Get-ChildItem $root -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^(Profile \d+|Guest Profile)$' } |
            Select-Object -ExpandProperty Name)
        foreach ($name in ($candidates | Select-Object -Unique)) {
            if ($seen.ContainsKey($name)) { continue }
            $profilePath = Join-Path $root $name
            if (-not (Test-Path (Join-Path $profilePath 'Preferences'))) { continue }
            $seen[$name] = $true
            $entries.Add([PSCustomObject]@{
                Folder = $name
                Label  = $name
                Path   = $profilePath
            })
        }
    }

    return @($entries)
}

function Get-ProfilePaths {
    return @(Get-BraveProfileEntries | ForEach-Object { $_.Path })
}

function Get-BackupProfileEntriesFromBackup {
    param([string]$BackupPath)
    $folders = @(Get-BackupProfileNames $BackupPath)
    $labels = @{}
    $metaPath = Join-Path $BackupPath 'backup-meta.json'
    if (Test-Path $metaPath) {
        try {
            $meta = Get-Content $metaPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($meta.ProfileLabels) {
                foreach ($prop in $meta.ProfileLabels.PSObject.Properties) {
                    $labels[$prop.Name] = [string]$prop.Value
                }
            }
        } catch { }
    }
    return @($folders | ForEach-Object {
        $f = $_
        [PSCustomObject]@{
            Folder = $f
            Label  = if ($labels.ContainsKey($f)) { $labels[$f] } else { $f }
            Path   = Join-Path $BackupPath $f
        }
    })
}

function Get-BackupProfileNames([string]$BackupPath) {
    $names = [System.Collections.Generic.List[string]]::new()
    $metaPath = Join-Path $BackupPath 'backup-meta.json'
    if (Test-Path $metaPath) {
        try {
            $meta = Get-Content $metaPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($meta.Profiles) {
                foreach ($p in @($meta.Profiles)) {
                    if ($p) { $null = $names.Add([string]$p) }
                }
            }
        } catch { }
    }
    if ($names.Count -eq 0) {
        foreach ($d in @(Get-ChildItem $BackupPath -Directory -ErrorAction SilentlyContinue)) {
            if (Test-Path (Join-Path $d.FullName 'Preferences')) {
                $null = $names.Add($d.Name)
            }
        }
    }
    if ($names.Count -eq 0) { return @('Default') }
    return @($names | Select-Object -Unique)
}

function Copy-UserDataRootFiles {
    param(
        [string]$DestDir,
        [scriptblock]$OnLog
    )
    foreach ($fileName in $Script:Config.RootFiles) {
        $src = Join-Path $Script:Config.BraveUserData $fileName
        if (-not (Test-Path $src)) { continue }
        try {
            Copy-Item $src (Join-Path $DestDir $fileName) -Force -ErrorAction Stop
            if ($OnLog -and $fileName -eq 'Local State') {
                & $OnLog (T 'LogLocalState') 'ok'
            }
        } catch {
            if ($OnLog) { & $OnLog (Tf 'LogErrItem' @("$fileName : $($_.Exception.Message)")) 'warn' }
        }
    }
}

function Get-BackupList {
    if (-not (Test-Path $Script:Config.BackupRoot)) { return @() }
    return @(Get-ChildItem $Script:Config.BackupRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object CreationTime -Descending)
}

function Get-BackupSize ([string]$BackupPath) {
    # Najpierw probujemy odczytac rozmiar z metadanych (szybkie), inaczej liczymy katalog
    $metaPath = Join-Path $BackupPath 'backup-meta.json'
    if (Test-Path $metaPath) {
        try {
            $meta = Get-Content $metaPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($null -ne $meta.SizeBytes) { return [long]$meta.SizeBytes }
        } catch { }
    }
    return (Get-FolderSize $BackupPath)
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
        [string[]]$ProfileFolders = @(),
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

    $profileEntries = @(Get-BraveProfileEntries)
    if ((Get-ArrayCount $ProfileFolders) -gt 0) {
        $profileEntries = @($profileEntries | Where-Object { $_.Folder -in $ProfileFolders })
    }
    if ((Get-ArrayCount $profileEntries) -eq 0) {
        if ($OnLog) { & $OnLog (T 'MsgNoProfiles') 'err' }
        return $false
    }

    # Pelna kopia: czyscimy cache zywego profilu przed kopiowaniem (zwalnia miejsce,
    # cache i tak nie jest kopiowany). Brave jest juz zamkniety na tym etapie.
    if ($FullBackup) {
        Clear-BraveLiveCache -ProfileEntries $profileEntries -OnLog $OnLog | Out-Null
    }

    # Kontrola wolnego miejsca: szacujemy rozmiar zrodla (pelny backup) + 10% zapasu
    if ($FullBackup) {
        $estimate = 0L
        foreach ($entry in $profileEntries) { $estimate += (Get-FolderSize $entry.Path) }
        $needed = [long]($estimate * 1.1)
        $free = Get-FreeSpace $Script:Config.BackupRoot
        if ($free -lt $needed) {
            if ($OnLog) {
                & $OnLog (Tf 'MsgNotEnoughSpace' @((Format-Size $needed), (Format-Size $free))) 'err'
            }
            return $false
        }
    }

    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

    $meta = @{
        Created    = (Get-Date -Format 'o')
        Mode       = $mode
        SourcePath = $Script:Config.BraveUserData
        AppVersion = $Script:AppVersion
        Profiles   = @()
    }

    if ($OnLog) {
        $labels = ($profileEntries | ForEach-Object { "$($_.Label) [$($_.Folder)]" }) -join ', '
        & $OnLog (Tf 'LogProfilesFound' @((Get-ArrayCount $profileEntries), $labels)) 'info'
    }

    $totalCopied = 0
    $totalP = [Math]::Max((Get-ArrayCount $profileEntries), 1)
    $pIdx = 0
    foreach ($entry in $profileEntries) {
        $profilePath = $entry.Path
        $profileName = $entry.Folder
        $logName = if ($entry.Label -ne $profileName) { "$($entry.Label) ($profileName)" } else { $profileName }
        if ($OnLog) { & $OnLog (Tf 'LogCopyingProfile' @($logName)) 'info' }
        $destProfile = Join-Path $backupDir $profileName
        New-Item -ItemType Directory -Path $destProfile -Force | Out-Null

        $base = ($pIdx / $totalP) * 90
        $span = 90 / $totalP
        $result = Copy-ProfileItems -SourceProfile $profilePath -DestProfile $destProfile `
            -FullBackup $FullBackup -OnProgress $OnProgress -OnLog $OnLog `
            -ProgressBase $base -ProgressSpan $span

        if ($OnLog) {
            & $OnLog (Tf 'LogProfileDone' @($logName, $result.Copied, $result.Errors)) 'ok'
        }
        $totalCopied += $result.Copied
        $meta.Profiles += $profileName
        if (-not $meta.ProfileLabels) { $meta.ProfileLabels = @{} }
        $meta.ProfileLabels[$profileName] = $entry.Label
        $pIdx++
    }

    Copy-UserDataRootFiles -DestDir $backupDir -OnLog $OnLog

    if ($totalCopied -eq 0) {
        if ($OnLog) { & $OnLog (T 'MsgBackupNothingCopied') 'err' }
        Remove-Item $backupDir -Recurse -Force -ErrorAction SilentlyContinue
        return $false
    }

    $backupSize = Get-FolderSize $backupDir
    $meta.SizeBytes = $backupSize
    $meta | ConvertTo-Json -Depth 4 |
        Set-Content (Join-Path $backupDir 'backup-meta.json') -Encoding UTF8

    Remove-OldBackups -OnLog $OnLog
    if ($OnProgress) { & $OnProgress 100 }
    if ($OnLog) {
        & $OnLog (Tf 'LogDone' @($backupDir)) 'ok'
        & $OnLog (Tf 'LogSize' @(Format-Size $backupSize)) 'info'
    }
    return $true
}

function Clear-BraveLiveCache {
    param(
        [object[]]$ProfileEntries,
        [scriptblock]$OnLog
    )
    # Usuwa katalogi cache z ZYWEGO profilu Brave (wymaga zamknietego Brave).
    # Cache i tak nie trafia do kopii (CacheExclude) — czyszczenie zwalnia miejsce.
    $freed = 0L
    foreach ($entry in $ProfileEntries) {
        foreach ($cacheName in $Script:Config.CacheExclude) {
            $p = Join-Path $entry.Path $cacheName
            if (-not (Test-Path $p)) { continue }
            try {
                $freed += (Get-FolderSize $p)
                Remove-Item $p -Recurse -Force -ErrorAction Stop
            } catch {
                if ($OnLog) { & $OnLog (Tf 'LogErrItem' @("$cacheName : $($_.Exception.Message)")) 'warn' }
            }
        }
    }
    if ($OnLog -and $freed -gt 0) {
        & $OnLog (Tf 'LogCacheCleared' @(Format-Size $freed)) 'info'
    }
    return $freed
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
        [string[]]$ProfileFolders = @(),
        [scriptblock]$OnProgress,
        [scriptblock]$OnLog
    )
    if (-not (Test-Path $BackupPath)) {
        if ($OnLog) { & $OnLog (Tf 'MsgBackupNotFound' @($BackupPath)) 'err' }
        return $false
    }

    $allInBackup = @(Get-BackupProfileNames $BackupPath)
    if ((Get-ArrayCount $ProfileFolders) -gt 0) {
        $profileNames = @($ProfileFolders | Where-Object { $_ -in $allInBackup })
    } else {
        $profileNames = $allInBackup
    }
    if ((Get-ArrayCount $profileNames) -eq 0) {
        if ($OnLog) { & $OnLog (T 'ProfilePickNone') 'err' }
        return $false
    }

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

    # 'Local State' zawiera klucz szyfrowania (os_crypt) dla hasel i ciasteczek —
    # przywracamy go ZAWSZE, takze przy odtwarzaniu pojedynczego profilu,
    # inaczej zapisane hasla/ciasteczka nie odszyfruja sie.
    foreach ($rootFile in $Script:Config.RootFiles) {
        $src = Join-Path $BackupPath $rootFile
        if (-not (Test-Path $src)) { continue }
        Copy-Item $src (Join-Path $Script:Config.BraveUserData $rootFile) -Force -ErrorAction SilentlyContinue
        if ($OnLog -and $rootFile -eq 'Local State') { & $OnLog (T 'LogRestoredLS') 'ok' }
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

function New-ConsoleLogger {
    return {
        param($m, $t)
        switch ($t) {
            'ok'   { Write-Success $m }
            'err'  { Write-Err $m }
            'warn' { Write-Warn $m }
            default { Write-Info $m }
        }
    }
}

function Show-Backups ($backups) {
    if ((Get-ArrayCount $backups) -eq 0) { Write-Warn 'Brak kopii zapasowych.'; return }
    Write-Host ''
    Write-Host '  Nr  Nazwa                          Data              Rozmiar' -ForegroundColor DarkGray
    Write-Host '  --  -----------------------------  ----------------  -------' -ForegroundColor DarkGray
    $i = 1
    foreach ($b in $backups) {
        $size = Format-Size (Get-BackupSize $b.FullName)
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

function Pick-ConsoleProfiles {
    param([object[]]$Entries)
    if ((Get-ArrayCount $Entries) -eq 0) { return @() }
    if ((Get-ArrayCount $Entries) -eq 1) { return @([string]$Entries[0].Folder) }
    Write-Host ''
    Write-Host "  $(T 'ProfilePickHint')" -ForegroundColor Cyan
    $i = 1
    foreach ($e in $Entries) {
        $label = if ($e.Label -and $e.Label -ne $e.Folder) {
            "$($e.Label) ($($e.Folder))"
        } else {
            $e.Folder
        }
        Write-Host "    [$i] $label" -ForegroundColor White
        $i++
    }
    Write-Host "    [A] $(T 'BtnSelectAll')" -ForegroundColor Gray
    $choice = Read-Host '  Wybierz numery (np. 1,2) lub A'
    if ($choice.Trim().ToUpper() -eq 'A') {
        return @($Entries | ForEach-Object { [string]$_.Folder })
    }
    $nums = $choice -split '[,\s;]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $picked = @()
    foreach ($n in $nums) {
        $idx = 0
        if ([int]::TryParse($n, [ref]$idx) -and $idx -ge 1 -and $idx -le (Get-ArrayCount $Entries)) {
            $picked += [string]$Entries[$idx - 1].Folder
        }
    }
    return @($picked | Select-Object -Unique)
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
        $log = New-ConsoleLogger
        $entries = @(Get-BraveProfileEntries)
        if ((Get-ArrayCount $entries) -eq 0) { Write-Err (T 'MsgNoProfiles'); Pause-AndReturn; return }
        $picked = Pick-ConsoleProfiles -Entries $entries
        if ((Get-ArrayCount $picked) -eq 0) { Write-Warn (T 'ProfilePickNone'); Pause-AndReturn; return }
        Invoke-BraveBackupCore -FullBackup $fullBackup -ProfileFolders $picked -OnLog $log | Out-Null
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
        $log = New-ConsoleLogger
        $entries = @(Get-BackupProfileEntriesFromBackup -BackupPath $selected.FullName)
        $picked = Pick-ConsoleProfiles -Entries $entries
        if ((Get-ArrayCount $picked) -eq 0) { Write-Warn (T 'ProfilePickNone'); Pause-AndReturn; return }
        Invoke-BraveRestoreCore -BackupPath $selected.FullName -ReplaceProfile $replaceProfile `
            -ProfileFolders $picked -OnLog $log | Out-Null
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
