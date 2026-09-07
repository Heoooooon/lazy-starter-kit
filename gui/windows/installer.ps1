#requires -Version 5.1
[CmdletBinding()]
param([switch]$SelfTest)

$Profiles = @('ai', 'recommended', 'full', 'minimal', 'work')
$DefaultProfileIndex = 0
$PreviewByDefault = $false
$ProfileTitles = @('AI 코딩 시작 — 추천', '개발 도구 추천', '전체 단계', '최소 설치', '회사 PC용')
$ProfileDescriptions = @{
  ai = 'AI 코딩 시작: Git, Node.js LTS/npm, Claude Code, Codex, 안전장치와 최소 PATH만 설치합니다. 추가 런타임, Docker, 셸 꾸미기는 제외합니다.'
  recommended = '권장: 기본 도구, 런타임, PowerShell, Git, Codex + Claude Code. Docker/WSL 제외.'
  full = '전체 단계: 권장 구성 + Docker/WSL 단계. GUI는 -Yes로 실행하므로 신규 Docker/WSL 설치는 건너뜁니다. 기존 Ubuntu는 초기화하거나 Linux 설치기를 실행할 수 있습니다. 미리보기 로그를 확인하세요.'
  minimal = '최소: 기본 도구, 런타임, PowerShell, Git. AI 에이전트와 Docker/WSL 제외.'
  work = '회사 PC용: 기본 도구, 런타임, PowerShell, Git, Codex + Claude Code. Docker/WSL 제외. 회사 정책을 먼저 확인하세요.'
}
$VerificationCommands = @('codex --version', 'claude --version')
$ProjectCommand = 'codex'

function Get-InstallerSwitches([string]$ProfileName, [bool]$Preview) {
  $switches = "-Yes -Profile '$ProfileName'"
  if ($Preview) { $switches += ' -DryRun' }
  return $switches
}

function Get-InstallerCompletion([int]$ExitCode, [bool]$Preview, [bool]$Cancelled, [bool]$Verified = $false) {
  if ($Cancelled) {
    return @{ State = 'cancelled'; Status = '설치가 취소되었습니다.'; Guidance = '' }
  }
  if ($ExitCode -ne 0) {
    return @{ State = 'failed'; Status = '설치가 완료되지 않았습니다. 아래 로그를 확인해 주세요.'; Guidance = '' }
  }
  if ($Preview) {
    return @{ State = 'preview'; Status = '미리보기가 끝났습니다.'; Guidance = '아직 설치하지 않았습니다. 로그와 선택 범위를 확인한 뒤 실제 설치를 시작하세요.' }
  }
  if ($Verified) {
    return @{ State = 'ready'; Status = '도구 실행 확인 완료. 이제 AI를 고르고 직접 로그인하세요.'; Guidance = '' }
  }
  return @{
    State = 'finished-unverified'
    Status = '설치 단계가 끝났습니다. 새 PowerShell에서 도구를 확인하세요.'
    Guidance = @"
프로세스 종료 코드 0은 모든 도구의 설치/로그인 확인을 뜻하지 않습니다. 경고와 건너뛴 항목을 로그에서 확인하세요.
1) 새 PowerShell 창을 여세요. 현재 창에는 새 PATH와 프로필이 반영되지 않을 수 있습니다.
2) AI 에이전트를 선택했다면 다음 명령으로 확인하세요 (최소 설치에는 포함되지 않습니다):
   $($VerificationCommands -join ([Environment]::NewLine + '   '))
   실패하면 로그에서 실패한 단계를 확인하고 같은 설치 범위로 다시 실행하세요.
3) 프로젝트 폴더로 이동: cd path\to\your-project
   $ProjectCommand 또는 claude를 실행하고 안내에 따라 로그인하세요.
"@
  }
}
$StarterPrompt = '이 폴더에서 작은 자기소개 웹페이지를 만들어 보고 싶어요. 먼저 어떤 파일을 만들지 설명하고, 제 확인을 받은 뒤 진행해 주세요. 삭제, 계정 연결, 유료 서비스 사용은 하지 마세요.'

function Test-OnboardingReady {
  param([int]$ExitCode, [bool]$Preview, [bool]$Cancelled, [string]$Profile, [string]$Log)
  return ($ExitCode -eq 0 -and -not $Preview -and -not $Cancelled -and
    $Profile -eq 'ai' -and $Log -match '(?m)^\[starter-kit:ai-ready\]\s*$')
}

function New-PracticeDirectory {
  param([Parameter(Mandatory)][string]$Parent)
  # No Force: a collision or inaccessible parent fails instead of reusing files.
  $path = Join-Path $Parent ('AI-practice-' + [Guid]::NewGuid().ToString('N'))
  $null = New-Item -ItemType Directory -Path $path -ErrorAction Stop
  return $path
}

function Get-AgentLaunchCommand {
  param([ValidateSet('claude','codex')][string]$Agent, [string]$Directory)
  $quoted = $Directory.Replace("'", "''")
  $command = @'
$ErrorActionPreference = 'Stop'
# A GUI started before installation has a stale environment. Read persisted
# paths in this new terminal; keep portable/process entries too.
$paths = @(@([Environment]::GetEnvironmentVariable('Path','Machine'), [Environment]::GetEnvironmentVariable('Path','User')) | Where-Object { $_ })
if ($paths.Count -gt 0) { $env:Path = (($paths + @($env:Path)) -join ';') }
foreach ($tool in @('git','node','npm','claude','codex')) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "Action needed: $tool missing. Run install.ps1 -Doctor -Profile ai." }
  $global:LASTEXITCODE = 0
  & $tool --version
  if (-not $? -or $LASTEXITCODE -ne 0) { throw "Action needed: $tool --version failed. No agent was launched." }
}
'@
  $command += "`nSet-Location -LiteralPath '$quoted'`n& $Agent`n"
  return [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
}
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
    separatePreviewAction = $true
    requiresVerifiedReadiness = $true
    profileTitles = $ProfileTitles
    profiles = $Profiles
    defaultProfile = $Profiles[$DefaultProfileIndex]
    previewByDefault = $PreviewByDefault
    previewSwitches = Get-InstallerSwitches $Profiles[$DefaultProfileIndex] $true
    installSwitches = Get-InstallerSwitches $Profiles[$DefaultProfileIndex] $false
    verificationCommands = $VerificationCommands
    projectCommand = $ProjectCommand
    completionStates = @{
      preview = (Get-InstallerCompletion 0 $true $false).State
      success = (Get-InstallerCompletion 0 $false $false).State
      failure = (Get-InstallerCompletion 1 $false $false).State
      cancelled = (Get-InstallerCompletion 0 $false $true).State
    }
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
$form.ClientSize = New-Object System.Drawing.Size(760, 800)
$form.MinimumSize = New-Object System.Drawing.Size(700, 750)
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)

$title = New-Object System.Windows.Forms.Label
$title.Text = 'AI 코딩 환경을 쉽게 설치하세요'
$title.Font = New-Object System.Drawing.Font('Segoe UI', 20, [System.Drawing.FontStyle]::Bold)
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(28, 24)

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = 'Git · Node.js LTS/npm · Claude Code · Codex · 안전장치를 함께 준비합니다.'
$subtitle.ForeColor = [System.Drawing.Color]::DimGray
$subtitle.AutoSize = $true
$subtitle.Location = New-Object System.Drawing.Point(31, 67)

$profileLabel = New-Object System.Windows.Forms.Label
$profileLabel.Text = '설치 범위'
$profileLabel.AutoSize = $true
$profileLabel.Location = New-Object System.Drawing.Point(31, 109)

$profile = New-Object System.Windows.Forms.ComboBox
$profile.DropDownStyle = 'DropDownList'
$null = $profile.Items.AddRange($ProfileTitles)
$profile.SelectedIndex = $DefaultProfileIndex
$profile.Location = New-Object System.Drawing.Point(105, 105)
$profile.Size = New-Object System.Drawing.Size(310, 28)
$profile.Anchor = 'Top,Left,Right'

$previewButton = New-Object System.Windows.Forms.Button
$previewButton.Text = '미리보기'
$previewButton.Size = New-Object System.Drawing.Size(100, 34)
$previewButton.Location = New-Object System.Drawing.Point(495, 100)
$previewButton.Anchor = 'Top,Right'

$installButton = New-Object System.Windows.Forms.Button
$installButton.Text = '설치 시작'
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
$status.Text = '설치할 준비가 되었습니다. 계정 로그인은 설치 후 직접 진행합니다.'
$status.Size = New-Object System.Drawing.Size(510, 48)
$status.Anchor = 'Top,Left,Right'
$status.ForeColor = [System.Drawing.Color]::DimGray
$status.Location = New-Object System.Drawing.Point(31, 290)

$profileDescription = New-Object System.Windows.Forms.Label
$profileDescription.Text = $ProfileDescriptions[$Profiles[$profile.SelectedIndex]]
$profileDescription.Location = New-Object System.Drawing.Point(31, 146)
$profileDescription.Size = New-Object System.Drawing.Size(694, 70)
$profileDescription.Anchor = 'Top,Left,Right'

$accountNote = New-Object System.Windows.Forms.Label
$accountNote.Text = 'Claude: Anthropic 계정과 지원 요금제 또는 API 결제가 필요합니다. Codex: ChatGPT 계정의 이용 권한 또는 API 결제가 필요합니다. 서비스별 요금이 적용될 수 있습니다. 자동 로그인이나 질문 전송은 하지 않습니다.'
$accountNote.Location = New-Object System.Drawing.Point(31, 220)
$accountNote.Size = New-Object System.Drawing.Size(694, 64)
$accountNote.Anchor = 'Top,Left,Right'

$details = New-Object System.Windows.Forms.CheckBox
$details.Text = '자세한 실행 로그 보기'
$details.AutoSize = $true
$details.Location = New-Object System.Drawing.Point(31, 520)

$firstRun = New-Object System.Windows.Forms.GroupBox
$firstRun.Text = '설치 확인 후 첫 AI 코딩 시작'
$firstRun.Location = New-Object System.Drawing.Point(31, 346)
$firstRun.Size = New-Object System.Drawing.Size(694, 162)
$firstRun.Anchor = 'Top,Left,Right'
$firstRun.Enabled = $false

$agentChoice = New-Object System.Windows.Forms.ComboBox
$agentChoice.DropDownStyle = 'DropDownList'
$null = $agentChoice.Items.AddRange(@('Claude Code', 'Codex'))
$agentChoice.SelectedIndex = 0
$agentChoice.AccessibleName = '시작할 AI 도구'
$agentChoice.Location = New-Object System.Drawing.Point(16, 28)
$agentChoice.Size = New-Object System.Drawing.Size(148, 28)

$launchButton = New-Object System.Windows.Forms.Button
$launchButton.Text = '새 연습 폴더에서 시작'
$launchButton.Location = New-Object System.Drawing.Point(176, 24)
$launchButton.Size = New-Object System.Drawing.Size(220, 36)

$copyButton = New-Object System.Windows.Forms.Button
$copyButton.Text = '첫 질문 복사'
$copyButton.Location = New-Object System.Drawing.Point(408, 24)
$copyButton.Size = New-Object System.Drawing.Size(148, 36)

$prompt = New-Object System.Windows.Forms.TextBox
$prompt.Multiline = $true
$prompt.ReadOnly = $true
$prompt.Text = $StarterPrompt
$prompt.Location = New-Object System.Drawing.Point(16, 76)
$prompt.Size = New-Object System.Drawing.Size(662, 68)
$prompt.Anchor = 'Top,Left,Right'
$prompt.ScrollBars = 'Vertical'
$firstRun.Controls.AddRange(@($agentChoice, $launchButton, $copyButton, $prompt))

$versionLink = New-Object System.Windows.Forms.LinkLabel
$versionLink.Text = if ($AppVersion -eq 'dev') {
  '개발 빌드 · 새 버전 확인'
} else {
  "v$AppVersion · 새 버전 확인"
}
$versionLink.AutoSize = $true
$versionLink.Location = New-Object System.Drawing.Point(565, 290)
$versionLink.Anchor = 'Top,Right'
$versionLink.Add_LinkClicked({
  [System.Diagnostics.Process]::Start($ReleasesUrl)
})

$log = New-Object System.Windows.Forms.TextBox
$log.Multiline = $true
$log.ReadOnly = $true
$log.ScrollBars = 'Vertical'
$log.WordWrap = $true
$log.Font = New-Object System.Drawing.Font('Consolas', 9)
$log.BackColor = [System.Drawing.SystemColors]::Window
$log.ForeColor = [System.Drawing.SystemColors]::WindowText
$log.Location = New-Object System.Drawing.Point(31, 552)
$log.Size = New-Object System.Drawing.Size(694, 213)
$log.Anchor = 'Top,Bottom,Left,Right'
$log.Visible = $false
$details.Add_CheckedChanged({ $log.Visible = $details.Checked })

$form.Controls.AddRange(@(
  $title, $subtitle, $profileLabel, $profile, $previewButton,
  $cancelButton, $installButton, $status, $versionLink, $log,
  $accountNote, $profileDescription, $details, $firstRun
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
$script:RunProfile = 'ai'
$script:OnboardingReady = $false

$profile.Add_SelectedIndexChanged({
  $profileDescription.Text = $ProfileDescriptions[$Profiles[$profile.SelectedIndex]]
  $script:OnboardingReady = $false
  $firstRun.Enabled = $false
})
$copyButton.Add_Click({
  if (-not $script:OnboardingReady -or $script:InstallerProcess) { return }
  try {
    [System.Windows.Forms.Clipboard]::SetText($StarterPrompt)
    $status.Text = '첫 질문을 복사했습니다. 로그인 후 직접 붙여 넣고 전송하세요.'
  } catch {
    $status.Text = "복사하지 못했습니다: $($_.Exception.Message)"
    $status.ForeColor = [System.Drawing.Color]::Firebrick
  }
})
$launchButton.Add_Click({
  if (-not $script:OnboardingReady -or $script:InstallerProcess) { return }
  try {
    $parent = [Environment]::GetFolderPath('MyDocuments')
    if (-not $parent) { $parent = $env:USERPROFILE }
    $directory = New-PracticeDirectory -Parent $parent
    $agent = @('claude','codex')[$agentChoice.SelectedIndex]
    $encoded = Get-AgentLaunchCommand -Agent $agent -Directory $directory
    Start-Process -FilePath 'powershell.exe' -WorkingDirectory $directory `
      -ArgumentList @('-NoProfile','-NoExit','-EncodedCommand',$encoded) -ErrorAction Stop | Out-Null
    $status.Text = '새 터미널을 열었습니다. 계정 로그인과 폴더 신뢰 승인을 직접 진행하세요.'
  } catch {
    $status.Text = "AI를 시작하지 못했습니다: $($_.Exception.Message)"
    $status.ForeColor = [System.Drawing.Color]::Firebrick
    $script:OnboardingReady = $false
    $firstRun.Enabled = $false
  }
})

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
      $stages = [regex]::Matches($text, '\[starter-kit:stage:(\w+)\]')
      if ($stages.Count -gt 0 -and -not $script:CancelRequested) {
        $stageTitles = @{ prereqs='설치 조건 확인'; packages='Git과 선택한 도구 준비'; runtimes='Node.js와 선택한 실행 환경 준비'; shell='새 터미널 연결'; docker='Docker 준비'; git='Git 설정'; agents='AI 도구와 안전장치 준비'; wsl='Linux 환경 준비' }
        $prefix = if ($script:WasDryRun) { '미리보기: ' } else { '설치 중: ' }
        $status.Text = $prefix + $stageTitles[$stages[$stages.Count - 1].Groups[1].Value]
      }
    }
  }
  if ($script:InstallerProcess -and $script:InstallerProcess.HasExited) {
    $timer.Stop()
    $code = $script:InstallerProcess.ExitCode
    $script:InstallerProcess.Dispose()
    $script:InstallerProcess = $null
    # Read once more after exit so the final readiness line cannot race the timer.
    if ($script:InstallerLog -and (Test-Path -LiteralPath $script:InstallerLog)) {
      $log.Text = [System.IO.File]::ReadAllText($script:InstallerLog)
    }
    $script:OnboardingReady = Test-OnboardingReady -ExitCode $code -Preview $script:WasDryRun `
      -Cancelled $script:CancelRequested -Profile $script:RunProfile -Log $log.Text
    $firstRun.Enabled = $script:OnboardingReady
    $completion = Get-InstallerCompletion $code $script:WasDryRun $script:CancelRequested $script:OnboardingReady
    $status.Text = $completion.Status
    if ($completion.Guidance) {
      $log.AppendText([Environment]::NewLine + [Environment]::NewLine + $completion.Guidance + [Environment]::NewLine)
    }
    if ($completion.State -eq 'cancelled') {
      $status.ForeColor = [System.Drawing.SystemColors]::GrayText
    } elseif ($completion.State -in @('ready', 'preview', 'finished-unverified')) {
      $status.ForeColor = [System.Drawing.Color]::ForestGreen
    } else {
      $status.ForeColor = [System.Drawing.Color]::Firebrick
    }
    if ($completion.State -eq 'finished-unverified' -and $script:RunProfile -eq 'ai') {
      $status.Text = '확인이 필요합니다. 실행 준비를 검증하지 못했습니다. 로그를 확인하세요.'
    }
    $installButton.Text = '설치 시작'
    $installButton.Enabled = $true
    $cancelButton.Visible = $false
    $cancelButton.Enabled = $true
    $profile.Enabled = $true
    $previewButton.Enabled = $true
    $previewButton.Visible = $true
    if (-not $script:WasDryRun -and -not $script:CancelRequested -and
        ($code -ne 0 -or ($script:RunProfile -eq 'ai' -and -not $script:OnboardingReady))) {
      $details.Checked = $true
      $status.ForeColor = [System.Drawing.Color]::Firebrick
    }
    $script:CancelRequested = $false
    Remove-InstallerArtifacts
  }
})

function Start-InstallerRun {
  param([bool]$Preview)
  if ($script:InstallerProcess) { return }
  $script:WasDryRun = $Preview
  if ($Preview) { $details.Checked = $true }
  $script:OnboardingReady = $false
  $firstRun.Enabled = $false
  $installButton.Enabled = $false
  $cancelButton.Visible = $true
  $cancelButton.Enabled = $true
  $profile.Enabled = $false
  $previewButton.Enabled = $false
  $previewButton.Visible = $false
  $status.Text = '설치 파일을 내려받는 중...'
  $status.ForeColor = [System.Drawing.Color]::DimGray
  $log.Text = $ProfileDescriptions[$Profiles[$profile.SelectedIndex]] + [Environment]::NewLine + [Environment]::NewLine

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
    $script:RunProfile = $profileName
    $payloadQuoted = $script:InstallerPayload.Replace("'", "''")
    $logQuoted = $script:InstallerLog.Replace("'", "''")
    $switches = Get-InstallerSwitches $profileName $script:WasDryRun
    $command =
      "trap { `$_ | Out-File -FilePath '$logQuoted' -Encoding utf8 -Append; exit 1 }; " +
      "& '$payloadQuoted' $switches *>&1 | Out-File -FilePath '$logQuoted' -Encoding utf8; " +
      "exit `$LASTEXITCODE"

    $start = New-Object System.Diagnostics.ProcessStartInfo
    $start.FileName = 'powershell.exe'
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    $start.Arguments = "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded"
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
    $details.Checked = $true
    $status.Text = "설치기를 시작하지 못했습니다: $($_.Exception.Message)"
    $status.ForeColor = [System.Drawing.Color]::Firebrick
    $installButton.Enabled = $true
    $cancelButton.Visible = $false
    $profile.Enabled = $true
    $previewButton.Enabled = $true
    $previewButton.Visible = $true
    if ($script:InstallerProcess) {
      $script:InstallerProcess.Dispose()
      $script:InstallerProcess = $null
    }
    Remove-InstallerArtifacts
  }
}
$installButton.Add_Click({ Start-InstallerRun -Preview $false })
$previewButton.Add_Click({ Start-InstallerRun -Preview $true })

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
