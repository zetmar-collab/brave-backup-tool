# GUI v2.1 — dot-source z BraveBackupTool.ps1 (wymaga T, Tf, Get-LastBackupInfo, itd.)

function Start-GuiApp {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

    $xamlText = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    x:Name="mainWindow" Height="680" Width="900"
    WindowStartupLocation="CenterScreen" ResizeMode="CanMinimize" Background="#1a1a2e">
  <Window.Resources>
    <Style x:Key="Btn" TargetType="Button">
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Padding" Value="12,7"/>
      <Setter Property="Margin" Value="3"/>
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
    <Style x:Key="BtnPrimary" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Padding" Value="20,10"/>
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
  <Grid Margin="14">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/><RowDefinition Height="Auto"/><RowDefinition Height="150"/>
    </Grid.RowDefinitions>
    <DockPanel Grid.Row="0" Margin="0,0,0,6">
      <StackPanel DockPanel.Dock="Left" Orientation="Horizontal">
        <TextBlock x:Name="txtTitle" Foreground="#e25c1e" FontSize="20" FontWeight="Bold"/>
        <TextBlock x:Name="txtBusy" Foreground="#fa0" Margin="10,0,0,0" Visibility="Collapsed"/>
      </StackPanel>
      <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" HorizontalAlignment="Right">
        <Button x:Name="btnLang" Content="EN" Background="#3a3a5e" Style="{StaticResource Btn}" MinWidth="44"/>
        <Button x:Name="btnHelp" Background="#2d2d4e" Style="{StaticResource Btn}"/>
        <Button x:Name="btnSecurity" Background="#2d2d4e" Style="{StaticResource Btn}"/>
        <Button x:Name="btnSettings" Background="#2d2d4e" Style="{StaticResource Btn}"/>
      </StackPanel>
    </DockPanel>
    <StackPanel Grid.Row="1" Margin="0,0,0,8">
      <TextBlock x:Name="txtStatusBrave" Foreground="#9ab" FontSize="11"/>
      <TextBlock x:Name="txtStatusFolder" Foreground="#9ab" FontSize="11"/>
      <TextBlock x:Name="txtStatusLast" Foreground="#9ab" FontSize="11"/>
      <TextBlock x:Name="txtStatusCount" Foreground="#788" FontSize="10" Margin="0,2,0,0"/>
    </StackPanel>
    <StackPanel Grid.Row="2" Margin="0,0,0,8">
      <Button x:Name="btnCreate" Style="{StaticResource BtnPrimary}" Background="#e25c1e" HorizontalAlignment="Left"/>
      <WrapPanel Margin="0,6,0,0">
        <Button x:Name="btnKey" Background="#c0631e" Style="{StaticResource Btn}"/>
        <Button x:Name="btnFull" Background="#a04a18" Style="{StaticResource Btn}"/>
        <Button x:Name="btnRestore" Background="#2d5a8e" Style="{StaticResource Btn}"/>
        <Button x:Name="btnDelete" Background="#7a1a1a" Style="{StaticResource Btn}"/>
        <Button x:Name="btnRefresh" Background="#2d2d4e" Style="{StaticResource Btn}"/>
        <Button x:Name="btnFolder" Background="#2d2d4e" Style="{StaticResource Btn}"/>
      </WrapPanel>
      <TextBlock x:Name="txtHintKey" Foreground="#666" FontSize="10" Margin="4,4,0,0"/>
      <TextBlock x:Name="txtHintFreeze" Foreground="#555" FontSize="9" Margin="4,2,0,0" FontStyle="Italic"/>
    </StackPanel>
    <Grid Grid.Row="3">
      <Border Background="#12122a" CornerRadius="8">
        <ListBox x:Name="lstBackups" Background="Transparent" BorderThickness="0">
          <ListBox.ItemTemplate>
            <DataTemplate>
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="*"/><ColumnDefinition Width="150"/><ColumnDefinition Width="80"/>
                </Grid.ColumnDefinitions>
                <TextBlock Text="{Binding BackupName}" Foreground="White"/>
                <TextBlock Grid.Column="1" Text="{Binding DateStr}" Foreground="#aaa"/>
                <TextBlock Grid.Column="2" Text="{Binding SizeStr}" Foreground="#6af"/>
              </Grid>
            </DataTemplate>
          </ListBox.ItemTemplate>
        </ListBox>
      </Border>
      <TextBlock x:Name="txtEmpty" Foreground="#666" FontSize="13" TextWrapping="Wrap"
        HorizontalAlignment="Center" VerticalAlignment="Center" TextAlignment="Center" Margin="24" Visibility="Collapsed"/>
    </Grid>
    <Grid Grid.Row="4" Margin="0,8,0,4">
      <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="40"/></Grid.ColumnDefinitions>
      <ProgressBar x:Name="progress" Height="7" Maximum="100"/>
      <TextBlock x:Name="txtPct" Grid.Column="1" Text="0%" Foreground="#aaa" Margin="6,0,0,0"/>
    </Grid>
    <Border Grid.Row="5" Background="#0d0d1e" CornerRadius="8" Padding="8">
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
        btnCreate = $window.FindName('btnCreate'); btnKey = $window.FindName('btnKey')
        btnFull = $window.FindName('btnFull'); btnRestore = $window.FindName('btnRestore')
        btnDelete = $window.FindName('btnDelete'); btnRefresh = $window.FindName('btnRefresh')
        btnFolder = $window.FindName('btnFolder'); btnLang = $window.FindName('btnLang')
        btnHelp = $window.FindName('btnHelp'); btnSecurity = $window.FindName('btnSecurity')
        btnSettings = $window.FindName('btnSettings')
        lst = $window.FindName('lstBackups'); txtLog = $window.FindName('txtLog')
        logScroll = $window.FindName('logScroll')
        txtTitle = $window.FindName('txtTitle'); txtBusy = $window.FindName('txtBusy')
        txtStatusBrave = $window.FindName('txtStatusBrave')
        txtStatusFolder = $window.FindName('txtStatusFolder')
        txtStatusLast = $window.FindName('txtStatusLast')
        txtStatusCount = $window.FindName('txtStatusCount')
        txtHintKey = $window.FindName('txtHintKey'); txtHintFreeze = $window.FindName('txtHintFreeze')
        txtEmpty = $window.FindName('txtEmpty')
        progress = $window.FindName('progress'); txtPct = $window.FindName('txtPct')
    }

    function Invoke-OnUi([scriptblock]$action) {
        if ($window.Dispatcher.CheckAccess()) { & $action }
        else { $window.Dispatcher.Invoke($action) }
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
            $c.txtBusy.Text = T 'Busy'
            $c.txtBusy.Visibility = if ($on) { 'Visible' } else { 'Collapsed' }
            foreach ($b in @($c.btnCreate, $c.btnKey, $c.btnFull, $c.btnRestore, $c.btnDelete)) {
                $b.IsEnabled = -not $on
            }
        }
    }

    function Apply-GuiLanguage {
        $window.Title = "$(T 'AppTitle') $(T 'AppVersion')"
        $c.txtTitle.Text = "$(T 'AppTitle') $(T 'AppVersion')"
        $c.txtBusy.Text = T 'Busy'
        $c.btnCreate.Content = T 'BtnCreateBackup'
        $c.btnKey.Content = T 'BtnKeyData'
        $c.btnFull.Content = T 'BtnFullBackup'
        $c.btnRestore.Content = T 'BtnRestore'
        $c.btnDelete.Content = T 'BtnDelete'
        $c.btnRefresh.Content = T 'BtnRefresh'
        $c.btnFolder.Content = T 'BtnFolder'
        $c.btnSettings.Content = T 'BtnSettings'
        $c.btnSecurity.Content = T 'BtnSecurity'
        $c.btnHelp.Content = T 'BtnHelp'
        $c.btnLang.Content = Get-GuiLangToggleLabel
        $c.txtHintKey.Text = T 'HintKeyData'
        $c.txtHintFreeze.Text = T 'HintFreeze'
        $c.txtEmpty.Text = T 'EmptyState' -replace '\{0\}', [Environment]::NewLine
    }

    function Gui-Refresh {
        $backups = @(Get-BackupList)
        $rows = foreach ($b in $backups) {
            [PSCustomObject]@{
                BackupName = [string]$b.Name
                DateStr    = Format-BackupDateTime $b.CreationTime
                SizeStr    = Format-Size (Get-BackupSize $b.FullName)
                FullPath   = [string]$b.FullName
            }
        }
        $procCount = Get-ArrayCount (Get-BraveProcesses)
        $backupCount = Get-ArrayCount $backups
        $braveLine = if ($procCount -eq 0) { T 'BraveClosed' } else { Tf 'BraveRunning' @($procCount) }
        $folderLine = if (Test-Path $Script:Config.BackupRoot) { T 'FolderOk' } else { T 'FolderMissing' }
        $last = Get-LastBackupInfo
        $lastLine = if ($last) { Tf 'LastBackupDate' @($last.Date) } else { T 'LastBackupNone' }
        $countLine = Tf 'BackupsCount' @($backupCount, $Script:Config.MaxBackups)
        $hasItems = $backupCount -gt 0

        Invoke-OnUi {
            $c.lst.ItemsSource = $null
            $c.lst.ItemsSource = @($rows)
            $c.txtStatusBrave.Text = $braveLine
            $c.txtStatusFolder.Text = "$folderLine — $($Script:Config.BackupRoot)"
            $c.txtStatusLast.Text = $lastLine
            $c.txtStatusCount.Text = $countLine
            $c.txtEmpty.Visibility = if ($hasItems) { 'Collapsed' } else { 'Visible' }
            $c.lst.Visibility = if ($hasItems) { 'Visible' } else { 'Collapsed' }
        }
    }

    function Select-BackupFolder {
        Add-Type -AssemblyName System.Windows.Forms
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = T 'FolderDlgDesc'
        $dlg.ShowNewFolderButton = $true
        if (Test-Path $Script:Config.BackupRoot) { $dlg.SelectedPath = $Script:Config.BackupRoot }
        if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return $false }
        $Script:Config.BackupRoot = $dlg.SelectedPath
        Ensure-BackupRootExists
        Save-BackupSettings
        return $true
    }

    function Show-Onboarding {
        $step = 1
        do {
            $title = T 'OnboardingTitle'
            $body = switch ($step) {
                1 { "$(T 'Onboarding1Title')`n`n$(T 'Onboarding1Text')" }
                2 { "$(T 'Onboarding2Title')`n`n$(T 'Onboarding2Text')" }
                3 { "$(T 'Onboarding3Title')`n`n$(T 'Onboarding3Text')" }
            }
            if ($step -lt 3) {
                $r = [System.Windows.MessageBox]::Show($body, $title, 'OKCancel', 'Information')
                if ($r -eq 'Cancel') { return }
                if ($step -eq 1) {
                    $r2 = [System.Windows.MessageBox]::Show(
                        (T 'OnboardingSetFolder'), $title, 'YesNo', 'Question')
                    if ($r2 -eq 'Yes') { [void](Select-BackupFolder) }
                }
                $step++
            } else {
                $r = [System.Windows.MessageBox]::Show($body, $title, 'OK', 'Information')
                $Script:OnboardingCompleted = $true
                Save-BackupSettings
                return
            }
        } while ($true)
    }

    function Show-SecurityDialog {
        [System.Windows.MessageBox]::Show(
            (T 'SecurityBody' -replace '\{0\}', [Environment]::NewLine),
            (T 'SecurityTitle'), 'OK', 'Information') | Out-Null
    }

    function Get-BackupDisplayName([object]$row) {
        if (-not $row) { return '' }
        $bn = $row.PSObject.Properties['BackupName'].Value
        if ($bn) { return [string]$bn }
        $fp = $row.PSObject.Properties['FullPath'].Value
        if ($fp) { return [string](Split-Path $fp -Leaf) }
        return ''
    }

    function Get-SelectedBackupRow {
        $idx = $c.lst.SelectedIndex
        if ($idx -lt 0) { return $null }
        return $c.lst.Items[$idx]
    }

    function Show-SettingsDialog {
        Add-Type -AssemblyName PresentationFramework
        $dlgXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
  xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
  Title="Settings" Height="380" Width="480" WindowStartupLocation="CenterOwner"
  ResizeMode="NoResize" Background="#1a1a2e">
  <StackPanel Margin="22,20,22,24">
    <TextBlock x:Name="lblMax" Foreground="#e8e8f0" Margin="0,0,0,8" FontSize="13"/>
    <WrapPanel x:Name="pnlMax" Margin="0,0,0,4">
      <RadioButton x:Name="rbMax5" GroupName="maxBackups" Margin="0,0,20,8" Foreground="#ffffff" FontSize="13"/>
      <RadioButton x:Name="rbMax10" GroupName="maxBackups" Margin="0,0,20,8" Foreground="#ffffff" FontSize="13"/>
      <RadioButton x:Name="rbMax15" GroupName="maxBackups" Margin="0,0,20,8" Foreground="#ffffff" FontSize="13"/>
      <RadioButton x:Name="rbMax20" GroupName="maxBackups" Margin="0,0,0,8" Foreground="#ffffff" FontSize="13"/>
    </WrapPanel>
    <TextBlock x:Name="lblLang" Foreground="#e8e8f0" Margin="0,12,0,8" FontSize="13"/>
    <RadioButton x:Name="rbLangPl" GroupName="appLang" Margin="0,0,0,6" Foreground="#ffffff" FontSize="13"/>
    <RadioButton x:Name="rbLangEn" GroupName="appLang" Margin="0,0,0,4" Foreground="#ffffff" FontSize="13"/>
    <Button x:Name="btnUpdates" Margin="0,16,0,0" Padding="12,9" Background="#2d5a8e" Foreground="White" BorderThickness="0" Cursor="Hand" HorizontalAlignment="Left"/>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,24,0,0">
      <Button x:Name="btnSave" MinWidth="110" Margin="0,0,12,0" Padding="18,11" Background="#e25c1e" Foreground="White" BorderThickness="0" Cursor="Hand" FontWeight="SemiBold"/>
      <Button x:Name="btnCancel" MinWidth="110" Padding="18,11" Background="#4a4a5e" Foreground="White" BorderThickness="0" Cursor="Hand"/>
    </StackPanel>
  </StackPanel>
</Window>
'@
        $dlg = [Windows.Markup.XamlReader]::Parse($dlgXaml)
        $dlg.Title = T 'SettingsTitle'
        $dlg.Owner = $window
        $maxOptions = @(5, 10, 15, 20)
        $rbMax = @(
            $dlg.FindName('rbMax5'), $dlg.FindName('rbMax10'),
            $dlg.FindName('rbMax15'), $dlg.FindName('rbMax20')
        )
        $dlg.FindName('lblMax').Text = T 'SettingsMaxBackups'
        $dlg.FindName('lblLang').Text = T 'SettingsLanguage'
        for ($i = 0; $i -lt $maxOptions.Count; $i++) {
            $rbMax[$i].Content = [string]$maxOptions[$i]
        }
        $currentMax = Get-AllowedMaxBackups ([int]$Script:Config.MaxBackups)
        $maxIdx = [array]::IndexOf($maxOptions, $currentMax)
        if ($maxIdx -lt 0) { $maxIdx = 1 }
        $rbMax[$maxIdx].IsChecked = $true
        $dlg.FindName('rbLangPl').Content = 'Polski (PL)'
        $dlg.FindName('rbLangEn').Content = 'English (EN)'
        if ($Script:Lang -eq 'en') {
            $dlg.FindName('rbLangEn').IsChecked = $true
        } else {
            $dlg.FindName('rbLangPl').IsChecked = $true
        }
        $btnUpd = $dlg.FindName('btnUpdates')
        $btnSave = $dlg.FindName('btnSave')
        $btnCancel = $dlg.FindName('btnCancel')
        $btnUpd.Content = T 'SettingsCheckUpdates'
        $btnSave.Content = T 'SettingsSave'
        $btnCancel.Content = T 'BtnCancel'
        $btnUpd.Add_Click({ Start-Process $Script:GitHubReleasesUrl })
        $btnCancel.Add_Click({ $dlg.DialogResult = $false; $dlg.Close() })
        $btnSave.Add_Click({
            $picked = -1
            for ($i = 0; $i -lt $rbMax.Count; $i++) {
                if ($rbMax[$i].IsChecked) { $picked = $i; break }
            }
            if ($picked -lt 0) { return }
            $Script:Config.MaxBackups = $maxOptions[$picked]
            $Script:Lang = if ($dlg.FindName('rbLangEn').IsChecked) { 'en' } else { 'pl' }
            Save-BackupSettings
            Apply-GuiLanguage
            Gui-Refresh
            $dlg.DialogResult = $true
            $dlg.Close()
        })
        $null = $dlg.ShowDialog()
        if ($dlg.DialogResult) {
            Gui-Log (T 'SettingsSaved') 'ok'
        }
    }

    function Show-ProfilePickerDialog {
        param(
            [string]$Title,
            [string]$Hint,
            [object[]]$Entries
        )
        if ((Get-ArrayCount $Entries) -eq 0) { return @() }
        if ((Get-ArrayCount $Entries) -eq 1) {
            return @([string]$Entries[0].Folder)
        }

        $dlgXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
  xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
  Height="340" Width="460" WindowStartupLocation="CenterOwner"
  ResizeMode="NoResize" Background="#1a1a2e">
  <StackPanel Margin="20">
    <TextBlock x:Name="txtHint" TextWrapping="Wrap" Foreground="#e0e0e8" FontSize="13" Margin="0,0,0,8"/>
    <WrapPanel Margin="0,0,0,8">
      <Button x:Name="btnAll" Padding="10,6" Margin="0,0,8,0" Background="#2d5a8e" Foreground="White" BorderThickness="0" Cursor="Hand"/>
      <Button x:Name="btnNone" Padding="10,6" Background="#4a4a5e" Foreground="White" BorderThickness="0" Cursor="Hand"/>
    </WrapPanel>
    <ScrollViewer MaxHeight="180" VerticalScrollBarVisibility="Auto">
      <StackPanel x:Name="pnlChecks"/>
    </ScrollViewer>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,18,0,0">
      <Button x:Name="btnOk" MinWidth="100" Margin="0,0,10,0" Padding="14,9" Background="#e25c1e" Foreground="White" BorderThickness="0" Cursor="Hand"/>
      <Button x:Name="btnCancel" MinWidth="100" Padding="14,9" Background="#4a4a5e" Foreground="White" BorderThickness="0" Cursor="Hand"/>
    </StackPanel>
  </StackPanel>
</Window>
'@
        $dlg = [Windows.Markup.XamlReader]::Parse($dlgXaml)
        $dlg.Title = $Title
        $dlg.Owner = $window
        $dlg.FindName('txtHint').Text = $Hint
        $dlg.FindName('btnAll').Content = T 'BtnSelectAll'
        $dlg.FindName('btnNone').Content = T 'BtnSelectNone'
        $dlg.FindName('btnOk').Content = T 'BtnYes'
        $dlg.FindName('btnCancel').Content = T 'BtnCancel'
        $pnl = $dlg.FindName('pnlChecks')
        $checks = [System.Collections.Generic.List[object]]::new()
        foreach ($e in $Entries) {
            $cb = New-Object System.Windows.Controls.CheckBox
            $label = if ($e.Label -and $e.Label -ne $e.Folder) {
                "$($e.Label) ($($e.Folder))"
            } else {
                [string]$e.Folder
            }
            $cb.Content = $label
            $cb.IsChecked = $true
            $cb.Foreground = [System.Windows.Media.Brushes]::White
            $cb.Margin = '0,5,0,5'
            $cb.FontSize = 13
            $cb.Tag = [string]$e.Folder
            $null = $pnl.Children.Add($cb)
            $checks.Add($cb)
        }
        $dlg.FindName('btnAll').Add_Click({
            foreach ($c in $checks) { $c.IsChecked = $true }
        })
        $dlg.FindName('btnNone').Add_Click({
            foreach ($c in $checks) { $c.IsChecked = $false }
        })
        $dlg.FindName('btnCancel').Add_Click({ $dlg.DialogResult = $false; $dlg.Close() })
        $dlg.FindName('btnOk').Add_Click({
            $picked = @($checks | Where-Object { $_.IsChecked } | ForEach-Object { [string]$_.Tag })
            if ((Get-ArrayCount $picked) -eq 0) {
                [System.Windows.MessageBox]::Show((T 'ProfilePickNone'), $Title, 'OK', 'Warning') | Out-Null
                return
            }
            $dlg.Tag = $picked
            $dlg.DialogResult = $true
            $dlg.Close()
        })
        if ($dlg.ShowDialog() -ne $true) { return $null }
        return @($dlg.Tag)
    }

    function Start-BackupWithProfilePick {
        param([bool]$Full)
        $entries = @(Get-BraveProfileEntries)
        if ((Get-ArrayCount $entries) -eq 0) {
            [System.Windows.MessageBox]::Show((T 'MsgNoProfiles'), (T 'AppTitle')) | Out-Null
            return
        }
        $picked = Show-ProfilePickerDialog -Title (T 'ProfilePickBackupTitle') -Hint (T 'ProfilePickHint') -Entries $entries
        if ($null -eq $picked) { return }
        if ($Full) { Gui-Log (T 'LogFullStart') } else { Gui-Log (T 'LogKeyStart') }
        Start-GuiWorker -Restore:$false -Full:$Full -ProfileFolders $picked
    }

    function Show-DeleteConfirmDialog {
        param([string]$BackupName)
        $dlgXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
  xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
  Height="220" Width="500" WindowStartupLocation="CenterOwner"
  ResizeMode="NoResize" Background="#1a1a2e">
  <StackPanel Margin="22,20,22,22">
    <TextBlock x:Name="txtPrompt" TextWrapping="Wrap" Foreground="#e0e0e8" FontSize="13"/>
    <TextBlock x:Name="txtBackupName" Margin="0,14,0,0" TextWrapping="Wrap"
      Foreground="#7af" FontSize="15" FontWeight="Bold"/>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,22,0,0">
      <Button x:Name="btnYes" MinWidth="100" Margin="0,0,12,0" Padding="16,10"
        Background="#7a1a1a" Foreground="White" BorderThickness="0" Cursor="Hand"/>
      <Button x:Name="btnNo" MinWidth="100" Padding="16,10"
        Background="#4a4a5e" Foreground="White" BorderThickness="0" Cursor="Hand"/>
    </StackPanel>
  </StackPanel>
</Window>
'@
        $dlg = [Windows.Markup.XamlReader]::Parse($dlgXaml)
        $dlg.Title = T 'MsgDeleteTitle'
        $dlg.Owner = $window
        $dlg.FindName('txtPrompt').Text = T 'MsgDeletePrompt'
        $dlg.FindName('txtBackupName').Text = $BackupName
        $dlg.FindName('btnYes').Content = T 'BtnYes'
        $dlg.FindName('btnNo').Content = T 'BtnNo'
        $dlg.FindName('btnYes').Add_Click({ $dlg.DialogResult = $true; $dlg.Close() })
        $dlg.FindName('btnNo').Add_Click({ $dlg.DialogResult = $false; $dlg.Close() })
        return ($dlg.ShowDialog() -eq $true)
    }

    function Show-RestoreDialog {
        param([object]$Sel)
        $warn = Tf 'MsgRestoreWarn' @([Environment]::NewLine, (Get-BackupDisplayName $Sel))
        $dlgXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
  xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
  Height="320" Width="480" WindowStartupLocation="CenterOwner" ResizeMode="NoResize" Background="#1a1a2e">
  <StackPanel Margin="16">
    <TextBlock x:Name="txtWarn" Foreground="#faa" TextWrapping="Wrap" Margin="0,0,0,12"/>
    <CheckBox x:Name="chkUnderstand" Foreground="#ddd"/>
    <CheckBox x:Name="chkPreBackup" Foreground="#ddd" Margin="0,8,0,0" IsChecked="True"/>
    <TextBlock x:Name="lblMode" Foreground="#ccc" Margin="0,12,0,4"/>
    <RadioButton x:Name="rbMerge" Foreground="#ddd" GroupName="mode" IsChecked="True"/>
    <RadioButton x:Name="rbFull" Foreground="#ddd" GroupName="mode" Margin="0,4,0,0"/>
    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,16,0,0">
      <Button x:Name="btnOk" Margin="0,0,8,0" Padding="12,6" Background="#2d5a8e" Foreground="White" BorderThickness="0"/>
      <Button x:Name="btnNo" Padding="12,6" Background="#444" Foreground="White" BorderThickness="0"/>
    </StackPanel>
  </StackPanel>
</Window>
'@
        $dlg = [Windows.Markup.XamlReader]::Parse($dlgXaml)
        $dlg.Title = T 'MsgRestoreModeTitle'
        $dlg.Owner = $window
        $dlg.FindName('txtWarn').Text = $warn
        $dlg.FindName('chkUnderstand').Content = T 'MsgRestoreUnderstand'
        $dlg.FindName('chkPreBackup').Content = T 'MsgRestorePreBackup'
        $dlg.FindName('lblMode').Text = T 'MsgRestoreModeTitle'
        $dlg.FindName('rbMerge').Content = T 'MsgRestoreMerge'
        $dlg.FindName('rbFull').Content = T 'MsgRestoreFull'
        $dlg.FindName('btnOk').Content = T 'BtnRestoreConfirm'
        $dlg.FindName('btnNo').Content = T 'BtnCancel'
        $dlg.FindName('btnNo').Add_Click({ $dlg.DialogResult = $false; $dlg.Close() })
        $dlg.FindName('btnOk').Add_Click({
            if (-not $dlg.FindName('chkUnderstand').IsChecked) {
                [System.Windows.MessageBox]::Show(
                    (T 'MsgRestoreUnderstand'), (T 'AppTitle'), 'OK', 'Warning') | Out-Null
                return
            }
            $dlg.Tag = @{
                PreBackup      = $dlg.FindName('chkPreBackup').IsChecked
                ReplaceProfile = $dlg.FindName('rbFull').IsChecked
            }
            $dlg.DialogResult = $true
            $dlg.Close()
        })
        if ($dlg.ShowDialog() -ne $true) { return $null }
        return $dlg.Tag
    }

    function Start-GuiWorker {
        param(
            [object]$Restore,
            [object]$Full = $false,
            [string]$Path = '',
            [object]$Replace = $false,
            [object]$PreRestoreBackup = $false,
            [string[]]$ProfileFolders = @()
        )
        $Restore = Convert-ToBoolParam $Restore
        $Full = Convert-ToBoolParam $Full
        $Replace = Convert-ToBoolParam $Replace
        $PreRestoreBackup = Convert-ToBoolParam $PreRestoreBackup
        try {
            if (-not (Ensure-BraveClosedForOperation)) {
                Gui-Log (T 'LogCanceledBrave') 'warn'
                return
            }
            Gui-Busy $true
            $script:PendingGuiWork = @{
                DoRestore        = [bool]$Restore
                FullBackup       = [bool]$Full
                BackupPath       = [string]$Path
                ReplaceProfile   = [bool]$Replace
                PreRestoreBackup = [bool]$PreRestoreBackup
                ProfileFolders   = @($ProfileFolders)
            }
            $null = $window.Dispatcher.BeginInvoke(
                [System.Windows.Threading.DispatcherPriority]::Background,
                [action]{
                    $w = $script:PendingGuiWork
                    $prevEA = $ErrorActionPreference
                    $ErrorActionPreference = 'Continue'
                    try {
                        if (-not (Stop-AllBraveProcesses)) {
                            Gui-Log (T 'LogBraveCloseFail') 'err'
                            return
                        }
                        $onLog = { param($m, $t) Gui-Log $m $t }
                        $onPct = { param($v) Gui-Pct $v }
                        if ($w.PreRestoreBackup) {
                            [void](Invoke-PreRestoreBackup -OnLog $onLog -OnProgress $onPct)
                        }
                        if ($w.DoRestore) {
                            [void](Invoke-BraveRestoreCore -BackupPath $w.BackupPath `
                                -ReplaceProfile $w.ReplaceProfile -ProfileFolders $w.ProfileFolders `
                                -OnProgress $onPct -OnLog $onLog)
                        } elseif ($w.FullBackup) {
                            [void](Invoke-BraveBackupCore -FullBackup $true -ProfileFolders $w.ProfileFolders `
                                -OnProgress $onPct -OnLog $onLog)
                        } else {
                            [void](Invoke-BraveBackupCore -FullBackup $false -ProfileFolders $w.ProfileFolders `
                                -OnProgress $onPct -OnLog $onLog)
                        }
                    } catch {
                        Gui-Log (Tf 'LogErrPrefix' @($_.Exception.Message)) 'err'
                    } finally {
                        $ErrorActionPreference = $prevEA
                        Invoke-OnUi { $c.progress.Value = 0; $c.txtPct.Text = '0%' }
                        Gui-Busy $false
                        Gui-Refresh
                    }
                })
        } catch {
            Gui-Log (Tf 'LogErrPrefix' @($_.Exception.Message)) 'err'
            Gui-Busy $false
        }
    }

    $c.btnCreate.Add_Click({
        try { Start-BackupWithProfilePick -Full $false }
        catch { Gui-Log (Tf 'LogErrPrefix' -FormatValues @($_.Exception.Message)) 'err'; Gui-Busy $false }
    })
    $c.btnFull.Add_Click({
        try { Start-BackupWithProfilePick -Full $true }
        catch { Gui-Log (Tf 'LogErrPrefix' -FormatValues @($_.Exception.Message)) 'err'; Gui-Busy $false }
    })
    $c.btnKey.Add_Click({
        try { Start-BackupWithProfilePick -Full $false }
        catch { Gui-Log (Tf 'LogErrPrefix' -FormatValues @($_.Exception.Message)) 'err'; Gui-Busy $false }
    })
    $c.btnRestore.Add_Click({
        $sel = Get-SelectedBackupRow
        if (-not $sel) {
            [System.Windows.MessageBox]::Show((T 'MsgSelectBackup'), (T 'MsgNoSelection')) | Out-Null
            return
        }
        $opts = Show-RestoreDialog -Sel $sel
        if (-not $opts) { return }
        $backupEntries = @(Get-BackupProfileEntriesFromBackup -BackupPath $sel.FullPath)
        $picked = Show-ProfilePickerDialog -Title (T 'ProfilePickRestoreTitle') -Hint (T 'ProfilePickHint') -Entries $backupEntries
        if ($null -eq $picked) { return }
        Gui-Log (Tf 'LogRestoreStart' -FormatValues @(Get-BackupDisplayName $sel))
        Start-GuiWorker -Restore:$true -Path $sel.FullPath -Replace:$opts.ReplaceProfile `
            -PreRestoreBackup:$opts.PreBackup -ProfileFolders $picked
    })
    $c.btnDelete.Add_Click({
        $sel = Get-SelectedBackupRow
        if (-not $sel) {
            [System.Windows.MessageBox]::Show((T 'MsgSelectBackup'), (T 'MsgNoSelection')) | Out-Null
            return
        }
        $backupName = Get-BackupDisplayName $sel
        if (-not (Show-DeleteConfirmDialog -BackupName $backupName)) { return }
        Remove-Item $sel.FullPath -Recurse -Force -ErrorAction SilentlyContinue
        Gui-Log (Tf 'LogDeleted' @($backupName)) 'warn'
        Gui-Refresh
    })
    $c.btnRefresh.Add_Click({ Gui-Refresh; Gui-Log (T 'LogListRefreshed') 'info' })
    $c.btnFolder.Add_Click({
        if (Select-BackupFolder) {
            Gui-Refresh
            Gui-Log (Tf 'LogFolderSet' @($Script:Config.BackupRoot)) 'ok'
        }
    })
    $c.btnLang.Add_Click({
        $Script:Lang = if ($Script:Lang -eq 'pl') { 'en' } else { 'pl' }
        Save-BackupSettings
        Apply-GuiLanguage
        Gui-Refresh
    })
    $c.btnHelp.Add_Click({ Start-Process $Script:GitHubRepoUrl })
    $c.btnSecurity.Add_Click({ Show-SecurityDialog })
    $c.btnSettings.Add_Click({ Show-SettingsDialog })

    Apply-GuiLanguage
    Gui-Refresh
    Gui-Log (Tf 'LogStarted' @(T 'AppVersion'))
    Gui-Log (Tf 'LogFolderSet' @($Script:Config.BackupRoot)) 'info'

    if (-not $Script:OnboardingCompleted) { Show-Onboarding }

    $null = $window.ShowDialog()
}

function Invoke-BraveBackupApplication {
    if ($Script:UseConsole) {
        Start-ConsoleApp
    } else {
        Start-GuiApp
    }
}

Invoke-BraveBackupApplication
