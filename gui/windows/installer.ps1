#requires -Version 5.1
[CmdletBinding()]
param([switch]$SelfTest)

$Profiles = @('full', 'minimal', 'work')
$DefaultInstallerUrl =
  'https://raw.githubusercontent.com/Heoooooon/lazy-starter-kit/main/windows/install.ps1'

if ($SelfTest) {
  [ordered]@{
    profiles = $Profiles
    supportsDryRun = $true
    installerURL = $DefaultInstallerUrl
  } | ConvertTo-Json -Compress
  return
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Lazy Starter Kit Installer'
$form.StartPosition = 'CenterScreen'
$form.ClientSize = New-Object System.Drawing.Size(760, 610)
$form.MinimumSize = New-Object System.Drawing.Size(700, 560)
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)

$title = New-Object System.Windows.Forms.Label
$title.Text = 'AI 코딩 환경을 쉽게 설치하세요'
$title.Font = New-Object System.Drawing.Font('Segoe UI', 20, [System.Drawing.FontStyle]::Bold)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(28, 24)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = 'PowerShell 명령어를 입력할 필요가 없습니다. 설치 범위를 고른 뒤 버튼만 누르세요.'
$subtitle.ForeColor = [System.Drawing.Color]::DimGray
$subtitle.AutoSize = $true
$subtitle.Location = New-Object System.Drawing.Point(31, 67)

$profileLabel = New-Object System.Windows.Forms.Label
$profileLabel.Text = '설치 범위'
$profileLabel.AutoSize = $true
$profileLabel.Location = New-Object System.Drawing.Point(31, 109)

$profile = New-Object System.Windows.Forms.ComboBox
$profile.DropDownStyle = 'DropDownList'
$null = $profile.Items.AddRange(@('전체 설치', '최소 설치', '회사 PC용'))
$profile.SelectedIndex = 0
$profile.Location = New-Object System.Drawing.Point(105, 105)
$profile.Size = New-Object System.Drawing.Size(170, 28)

$dryRun = New-Object System.Windows.Forms.CheckBox
$dryRun.Text = '설치 전 변경 내용을 미리 보기'
$dryRun.Checked = $true
$dryRun.AutoSize = $true
$dryRun.Location = New-Object System.Drawing.Point(295, 108)

$installButton = New-Object System.Windows.Forms.Button
$installButton.Text = '설치 시작'
$installButton.Size = New-Object System.Drawing.Size(120, 34)
$installButton.Location = New-Object System.Drawing.Point(605, 100)
$installButton.Anchor = 'Top,Right'

$status = New-Object System.Windows.Forms.Label
$status.Text = '준비됨'
$status.AutoSize = $true
$status.ForeColor = [System.Drawing.Color]::DimGray
$status.Location = New-Object System.Drawing.Point(31, 151)

$log = New-Object System.Windows.Forms.TextBox
$log.Multiline = $true
$log.ReadOnly = $true
$log.ScrollBars = 'Vertical'
$log.WordWrap = $false
$log.Font = New-Object System.Drawing.Font('Consolas', 9)
$log.BackColor = [System.Drawing.Color]::White
$log.Location = New-Object System.Drawing.Point(31, 180)
$log.Size = New-Object System.Drawing.Size(694, 395)
$log.Anchor = 'Top,Bottom,Left,Right'
$log.Text = @'
준비가 되었습니다.

처음이라면 '설치 전 변경 내용을 미리 보기'를 켠 채 시작하세요.
미리보기가 끝나면 체크를 끄고 다시 눌러 실제 설치를 진행할 수 있습니다.
'@

$form.Controls.AddRange(@(
  $title, $subtitle, $profileLabel, $profile, $dryRun,
  $installButton, $status, $log
))
$form.AcceptButton = $installButton

$script:InstallerProcess = $null
$script:InstallerPayload = $null
$script:InstallerLog = $null
$script:LogLength = 0
$script:WasDryRun = $false

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 250
$timer.Add_Tick({
  if ($script:InstallerLog -and (Test-Path -LiteralPath $script:InstallerLog)) {
    $text = [System.IO.File]::ReadAllText($script:InstallerLog)
    if ($text.Length -gt $script:LogLength) {
      $log.AppendText($text.Substring($script:LogLength))
      $script:LogLength = $text.Length
      $log.SelectionStart = $log.TextLength
      $log.ScrollToCaret()
    }
  }
  if ($script:InstallerProcess -and $script:InstallerProcess.HasExited) {
    $timer.Stop()
    $code = $script:InstallerProcess.ExitCode
    $script:InstallerProcess.Dispose()
    $script:InstallerProcess = $null
    if ($code -eq 0) {
      $status.Text = if ($script:WasDryRun) { '미리보기가 끝났습니다.' } else { '설치가 끝났습니다.' }
      $status.ForeColor = [System.Drawing.Color]::ForestGreen
      if ($script:WasDryRun) {
        $dryRun.Checked = $false
        $installButton.Text = '실제 설치 시작'
      } else {
        $installButton.Text = '다시 실행'
      }
    } else {
      $status.Text = '설치가 완료되지 않았습니다. 아래 로그를 확인해 주세요.'
      $status.ForeColor = [System.Drawing.Color]::Firebrick
      $installButton.Text = '다시 실행'
    }
    $installButton.Enabled = $true
    $profile.Enabled = $true
    $dryRun.Enabled = $true
  }
})

$installButton.Add_Click({
  if ($script:InstallerProcess) { return }
  $installButton.Enabled = $false
  $profile.Enabled = $false
  $dryRun.Enabled = $false
  $status.Text = '설치 파일을 내려받는 중...'
  $status.ForeColor = [System.Drawing.Color]::DimGray
  $log.Clear()

  try {
    $url = if ($env:STARTER_KIT_INSTALL_URL) {
      $env:STARTER_KIT_INSTALL_URL
    } else {
      $DefaultInstallerUrl
    }
    $id = [Guid]::NewGuid().ToString('N')
    $script:InstallerPayload = Join-Path $env:TEMP "lazy-starter-kit-$id.ps1"
    $script:InstallerLog = Join-Path $env:TEMP "lazy-starter-kit-$id.log"
    $script:LogLength = 0
    $client = New-Object System.Net.WebClient
    try {
      $client.DownloadFile($url, $script:InstallerPayload)
    } finally {
      $client.Dispose()
    }

    $profileName = $Profiles[$profile.SelectedIndex]
    $script:WasDryRun = $dryRun.Checked
    $payloadQuoted = $script:InstallerPayload.Replace("'", "''")
    $logQuoted = $script:InstallerLog.Replace("'", "''")
    $switches = "-Yes -Profile '$profileName'"
    if ($script:WasDryRun) { $switches += ' -DryRun' }
    $command = "& '$payloadQuoted' $switches *>&1 | Out-File -FilePath '$logQuoted' -Encoding utf8; exit `$LASTEXITCODE"

    $start = New-Object System.Diagnostics.ProcessStartInfo
    $start.FileName = 'powershell.exe'
    $start.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"$command`""
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $script:InstallerProcess = New-Object System.Diagnostics.Process
    $script:InstallerProcess.StartInfo = $start
    if (-not $script:InstallerProcess.Start()) {
      throw 'PowerShell 설치 프로세스를 시작하지 못했습니다.'
    }
    $status.Text = if ($script:WasDryRun) { '변경 내용을 미리 보는 중...' } else { '설치 중... 창을 닫지 마세요.' }
    $timer.Start()
  } catch {
    $status.Text = "설치기를 시작하지 못했습니다: $($_.Exception.Message)"
    $status.ForeColor = [System.Drawing.Color]::Firebrick
    $installButton.Enabled = $true
    $profile.Enabled = $true
    $dryRun.Enabled = $true
    if ($script:InstallerProcess) {
      $script:InstallerProcess.Dispose()
      $script:InstallerProcess = $null
    }
  }
})

$form.Add_FormClosing({
  if ($script:InstallerProcess -and -not $script:InstallerProcess.HasExited) {
    $choice = [System.Windows.Forms.MessageBox]::Show(
      '설치가 진행 중입니다. 정말 창을 닫을까요?',
      'Lazy Starter Kit Installer',
      [System.Windows.Forms.MessageBoxButtons]::YesNo,
      [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($choice -ne [System.Windows.Forms.DialogResult]::Yes) {
      $_.Cancel = $true
      return
    }
    $script:InstallerProcess.Kill()
  }
})

$form.Add_FormClosed({
  $timer.Stop()
  $timer.Dispose()
  if ($script:InstallerProcess) { $script:InstallerProcess.Dispose() }
  foreach ($path in @($script:InstallerPayload, $script:InstallerLog)) {
    if ($path -and (Test-Path -LiteralPath $path)) {
      Remove-Item -LiteralPath $path -Force
    }
  }
})

[void]$form.ShowDialog()
