#requires -Version 5.1
[CmdletBinding()]
param([switch]$SelfTest)

$Profiles = @('full', 'minimal', 'work')
$ReleasesUrl = 'https://github.com/Heoooooon/lazy-starter-kit/releases/latest'
$CanonicalRepositoryUrl = 'https://github.com/Heoooooon/lazy-starter-kit.git'
$BundledInstallerPath = Join-Path $PSScriptRoot 'bootstrap-install.ps1'
$BundledCleanupLibraryPath = Join-Path $PSScriptRoot 'cleanup-lib.ps1'
$CleanupScriptPath = Join-Path $PSScriptRoot 'cleanup-installer-clone.ps1'
$BundledVersionPath = Join-Path $PSScriptRoot 'VERSION'
$BundledCommitPath = Join-Path $PSScriptRoot 'RELEASE_COMMIT'
$EmbeddedInstallerSHA256 = '__BOOTSTRAP_SHA256__'
if ((Test-Path -LiteralPath $BundledInstallerPath) -and
    (Test-Path -LiteralPath $BundledCleanupLibraryPath) -and
    (Test-Path -LiteralPath $CleanupScriptPath) -and
    (Test-Path -LiteralPath $BundledVersionPath) -and
    (Test-Path -LiteralPath $BundledCommitPath)) {
  $AppVersion = (Get-Content -LiteralPath $BundledVersionPath -Raw).Trim()
  $ReleaseRef = "v$AppVersion"
  $ReleaseCommit = (Get-Content -LiteralPath $BundledCommitPath -Raw).Trim()
  $DefaultInstallerPath = $BundledInstallerPath
  $InstallerSource = 'bundled'
  $DeveloperMode = $false
  if ($ReleaseCommit -notmatch '^[0-9a-f]{40}$') {
    throw 'Packaged GUI RELEASE_COMMIT is invalid.'
  }
  if ($EmbeddedInstallerSHA256 -notmatch '^[0-9a-f]{64}$') {
    throw 'Packaged GUI bootstrap digest was not embedded.'
  }
  $InstallerSHA256 = $EmbeddedInstallerSHA256
} else {
  $AppVersion = 'dev'
  $ReleaseRef = 'main'
  $ReleaseCommit = $null
  $DefaultInstallerPath =
    [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\windows\install.ps1'))
  $InstallerSource = 'repo'
  $DeveloperMode = $true
  if (-not (Test-Path -LiteralPath $DefaultInstallerPath)) {
    throw "Development bootstrap not found: $DefaultInstallerPath"
  }
  $InstallerSHA256 =
    (Get-FileHash -LiteralPath $DefaultInstallerPath -Algorithm SHA256).Hash.ToLowerInvariant()
}

if ($SelfTest) {
  [ordered]@{
    appVersion = $AppVersion
    actionTitlesTrackPreviewState = $true
    developerMode = $DeveloperMode
    installActionTitle = '설치 시작'
    installerSHA256 = $InstallerSHA256
    installerSource = $InstallerSource
    previewActionTitle = '미리보기 시작'
    profiles = $Profiles
    releaseRef = $ReleaseRef
    releaseCommit = $ReleaseCommit
    releasesURL = $ReleasesUrl
    supportsCancellation = $true
    supportsDryRun = $true
  } | ConvertTo-Json -Compress
  return
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = "Lazy Starter Kit Installer - $AppVersion"
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
$installButton.Text = '미리보기 시작'
$installButton.Size = New-Object System.Drawing.Size(120, 34)
$installButton.Location = New-Object System.Drawing.Point(605, 100)
$installButton.Anchor = 'Top,Right'

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = '설치 취소'
$cancelButton.Size = New-Object System.Drawing.Size(95, 34)
$cancelButton.Location = New-Object System.Drawing.Point(500, 100)
$cancelButton.Anchor = 'Top,Right'
$cancelButton.Visible = $false

$status = New-Object System.Windows.Forms.Label
$status.Text = '준비됨'
$status.AutoSize = $true
$status.ForeColor = [System.Drawing.Color]::DimGray
$status.Location = New-Object System.Drawing.Point(31, 151)

$versionLink = New-Object System.Windows.Forms.LinkLabel
$versionLink.Text = if ($AppVersion -eq 'dev') {
  '개발 빌드 · 새 버전 확인'
} else {
  "v$AppVersion · 새 버전 확인"
}
$versionLink.AutoSize = $true
$versionLink.Location = New-Object System.Drawing.Point(565, 151)
$versionLink.Anchor = 'Top,Right'
$versionLink.Add_LinkClicked({
  [System.Diagnostics.Process]::Start($ReleasesUrl)
})

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
  $cancelButton, $installButton, $status, $versionLink, $log
))
$form.AcceptButton = $installButton

$script:InstallerProcess = $null
$script:InstallerPayload = $null
$script:InstallerLog = $null
$script:InstallerCloneDir = $null
$script:InstallerPayloadOwned = $false
$script:LogLength = 0
$script:WasDryRun = $false
$script:CancelRequested = $false

function Remove-InstallerArtifacts {
  if ($script:InstallerPayloadOwned -and $script:InstallerPayload -and
      (Test-Path -LiteralPath $script:InstallerPayload)) {
    Remove-Item -LiteralPath $script:InstallerPayload -Force -ErrorAction SilentlyContinue
  }
  if ($script:InstallerLog -and (Test-Path -LiteralPath $script:InstallerLog)) {
    Remove-Item -LiteralPath $script:InstallerLog -Force -ErrorAction SilentlyContinue
  }
  if ($script:InstallerCloneDir) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass `
      -File $CleanupScriptPath `
      -AllowedRoot $env:TEMP `
      -Path $script:InstallerCloneDir
    if ($LASTEXITCODE -ne 0) {
      throw "임시 설치 폴더를 정리하지 못했습니다: $($script:InstallerCloneDir)"
    }
  }
  $script:InstallerPayload = $null
  $script:InstallerLog = $null
  $script:InstallerCloneDir = $null
  $script:InstallerPayloadOwned = $false
}

function Stop-InstallerTree {
  param([System.Diagnostics.Process]$Process)
  if (-not $Process) { return }
  try {
    if ($Process.HasExited) { return }
  } catch [System.InvalidOperationException] {
    return
  }
  $killer = Start-Process -FilePath 'taskkill.exe' `
    -ArgumentList @('/PID', "$($Process.Id)", '/T', '/F') `
    -NoNewWindow -Wait -PassThru
  try {
    if ($killer.ExitCode -ne 0 -and -not $Process.HasExited) {
      throw "설치 프로세스 트리를 종료하지 못했습니다 (taskkill $($killer.ExitCode))."
    }
    if (-not $Process.HasExited) {
      $Process.WaitForExit(5000) | Out-Null
    }
    if (-not $Process.HasExited) {
      throw '설치 프로세스 트리가 제한 시간 안에 종료되지 않았습니다.'
    }
  } catch [System.InvalidOperationException] {
    return
  }
}

$dryRun.Add_CheckedChanged({
  if (-not $script:InstallerProcess) {
    $installButton.Text = if ($dryRun.Checked) { '미리보기 시작' } else { '설치 시작' }
  }
})

$cancelButton.Add_Click({
  if (-not $script:InstallerProcess) { return }
  $cancelButton.Enabled = $false
  $status.Text = '설치를 안전하게 취소하는 중...'
  try {
    $script:CancelRequested = $true
    Stop-InstallerTree -Process $script:InstallerProcess
  } catch {
    $script:CancelRequested = $false
    $cancelButton.Enabled = $true
    $status.Text = "설치를 취소하지 못했습니다: $($_.Exception.Message)"
    $status.ForeColor = [System.Drawing.Color]::Firebrick
  }
})

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
    if ($script:CancelRequested) {
      $status.Text = '설치가 취소되었습니다.'
      $status.ForeColor = [System.Drawing.Color]::DimGray
      $installButton.Text = if ($dryRun.Checked) { '미리보기 시작' } else { '설치 시작' }
    } elseif ($code -eq 0) {
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
    $cancelButton.Visible = $false
    $cancelButton.Enabled = $true
    $profile.Enabled = $true
    $dryRun.Enabled = $true
    $script:CancelRequested = $false
    Remove-InstallerArtifacts
  }
})

$installButton.Add_Click({
  if ($script:InstallerProcess) { return }
  $installButton.Enabled = $false
  $cancelButton.Visible = $true
  $cancelButton.Enabled = $true
  $profile.Enabled = $false
  $dryRun.Enabled = $false
  $status.Text = '설치 파일을 내려받는 중...'
  $status.ForeColor = [System.Drawing.Color]::DimGray
  $log.Clear()

  try {
    Remove-InstallerArtifacts
    $id = [Guid]::NewGuid().ToString('N')
    $script:InstallerLog = Join-Path $env:TEMP "lazy-starter-kit-$id.log"
    $script:LogLength = 0
    if ($env:STARTER_KIT_INSTALL_URL) {
      if (-not $DeveloperMode) {
        throw 'Release builds do not permit installer URL overrides.'
      }
      if (-not $env:STARTER_KIT_INSTALL_SHA256) {
        throw 'STARTER_KIT_INSTALL_URL에는 STARTER_KIT_INSTALL_SHA256이 필요합니다.'
      }
      $url = $env:STARTER_KIT_INSTALL_URL
      $expectedSHA256 = $env:STARTER_KIT_INSTALL_SHA256.ToLowerInvariant()
      $script:InstallerPayload = Join-Path $env:TEMP "lazy-starter-kit-$id.ps1"
      $script:InstallerPayloadOwned = $true
      [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
      $client = New-Object System.Net.WebClient
      try {
        $client.DownloadFile($url, $script:InstallerPayload)
      } finally {
        $client.Dispose()
      }
    } else {
      $expectedSHA256 = $InstallerSHA256
      $script:InstallerPayload = $DefaultInstallerPath
      $script:InstallerPayloadOwned = $false
    }
    if ($expectedSHA256 -notmatch '^[0-9a-f]{64}$') {
      throw '설치 파일 SHA-256 형식이 올바르지 않습니다.'
    }
    $actualSHA256 =
      (Get-FileHash -LiteralPath $script:InstallerPayload -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualSHA256 -ne $expectedSHA256) {
      throw '설치 파일의 무결성 확인에 실패했습니다.'
    }
    $installerText = Get-Content -LiteralPath $script:InstallerPayload -Raw
    if ($installerText -notmatch '\[CmdletBinding\(\)\]') {
      throw '설치 파일 형식이 올바르지 않습니다.'
    }

    $profileName = $Profiles[$profile.SelectedIndex]
    $script:WasDryRun = $dryRun.Checked
    $payloadQuoted = $script:InstallerPayload.Replace("'", "''")
    $logQuoted = $script:InstallerLog.Replace("'", "''")
    $switches = "-Yes -Profile '$profileName'"
    if ($script:WasDryRun) { $switches += ' -DryRun' }
    $command =
      "trap { `$_ | Out-File -FilePath '$logQuoted' -Encoding utf8 -Append; exit 1 }; " +
      "& '$payloadQuoted' $switches *>&1 | Out-File -FilePath '$logQuoted' -Encoding utf8; " +
      "exit `$LASTEXITCODE"

    $start = New-Object System.Diagnostics.ProcessStartInfo
    $start.FileName = 'powershell.exe'
    $start.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"$command`""
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    if (-not $DeveloperMode) {
      @($start.EnvironmentVariables.Keys) |
        Where-Object { $_ -like 'STARTER_KIT_*' } |
        ForEach-Object { $start.EnvironmentVariables.Remove($_) }
    }
    $start.EnvironmentVariables['STARTER_KIT_REPO'] = $CanonicalRepositoryUrl
    $cloneDirectory =
      (Join-Path $env:TEMP "lazy-starter-kit-$([Guid]::NewGuid().ToString('N'))")
    $script:InstallerCloneDir = $cloneDirectory
    $start.EnvironmentVariables['STARTER_KIT_DIR'] = $cloneDirectory
    $start.EnvironmentVariables['STARTER_KIT_EPHEMERAL_ROOT'] = $cloneDirectory
    $start.EnvironmentVariables['STARTER_KIT_BRANCH'] = $ReleaseRef
    if ($ReleaseCommit) {
      $start.EnvironmentVariables['STARTER_KIT_COMMIT'] = $ReleaseCommit
    }
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
    $cancelButton.Visible = $false
    $profile.Enabled = $true
    $dryRun.Enabled = $true
    if ($script:InstallerProcess) {
      $script:InstallerProcess.Dispose()
      $script:InstallerProcess = $null
    }
    Remove-InstallerArtifacts
  }
})

$form.Add_FormClosing({
  param($sender, $eventArgs)
  if ($script:InstallerProcess -and -not $script:InstallerProcess.HasExited) {
    $choice = [System.Windows.Forms.MessageBox]::Show(
      '설치가 진행 중입니다. 설치를 취소하고 창을 닫을까요?',
      'Lazy Starter Kit Installer',
      [System.Windows.Forms.MessageBoxButtons]::YesNo,
      [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($choice -ne [System.Windows.Forms.DialogResult]::Yes) {
      $eventArgs.Cancel = $true
      return
    }
    try {
      $script:CancelRequested = $true
      Stop-InstallerTree -Process $script:InstallerProcess
    } catch {
      $eventArgs.Cancel = $true
      $script:CancelRequested = $false
      $status.Text = "설치를 취소하지 못했습니다: $($_.Exception.Message)"
      $status.ForeColor = [System.Drawing.Color]::Firebrick
      return
    }
  }
})

$form.Add_FormClosed({
  $timer.Stop()
  $timer.Dispose()
  if ($script:InstallerProcess) { $script:InstallerProcess.Dispose() }
  Remove-InstallerArtifacts
})

[void]$form.ShowDialog()
