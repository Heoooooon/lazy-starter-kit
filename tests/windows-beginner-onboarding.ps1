#requires -Version 5.1
# Portable behavior tests. All writes and child processes use a disposable HOME.
$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
$Evidence = if ($env:STARTER_KIT_TEST_EVIDENCE) { $env:STARTER_KIT_TEST_EVIDENCE } else { Join-Path ([IO.Path]::GetTempPath()) 'windows-beginner-onboarding' }
$Sandbox = Join-Path $Evidence ([Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $Sandbox -Force
$env:HOME = $Sandbox
$env:USERPROFILE = $Sandbox
$env:APPDATA = Join-Path $Sandbox 'AppData/Roaming'
$env:LOCALAPPDATA = Join-Path $Sandbox 'AppData/Local'
$env:TEMP = $Sandbox
$env:TMP = $Sandbox
$env:TMPDIR = $Sandbox
# PowerShell itself rewrites startup metrics. Keep its runtime cache outside
# the home snapshot so the no-op assertion measures product side effects.
$env:XDG_CACHE_HOME = Join-Path $Evidence ('runtime-cache-' + [Guid]::NewGuid().ToString('N'))
Set-Variable -Name HOME -Scope Script -Value $Sandbox -Force
$PowerShell = (Get-Process -Id $PID).Path
# Windows treats these names alike; portable PowerShell distinguishes them.
$env:PATH = ''
$env:Path = ''
foreach ($name in @('FAIL_TOOL', 'STARTER_KIT_REPO', 'STARTER_KIT_BRANCH', 'STARTER_KIT_COMMIT', 'STARTER_KIT_DIR', 'STARTER_KIT_EPHEMERAL_ROOT', 'STARTER_KIT_HANDOFF_CHILD')) {
  Remove-Item "Env:$name" -ErrorAction SilentlyContinue
}
$Failures = @()
function Assert-Equal($Actual, $Expected) {
  if (($Actual -join ',') -cne ($Expected -join ',')) { throw "expected [$($Expected -join ',')], got [$($Actual -join ',')]" }
}
function Test-Case([string]$Name, [scriptblock]$Body) {
  try { & $Body; Write-Host "PASS $Name" } catch { $script:Failures += "$Name : $_"; Write-Host "FAIL $Name : $_`n$($_.ScriptStackTrace)" }
  finally { $env:PATH = ''; $env:Path = '' }
}
function Import-Functions([string]$Path, [string[]]$Names) {
  $tokens = $null; $errors = $null
  $ast = [Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
  if ($errors.Count) { throw ($errors -join '; ') }
  foreach ($name in $Names) {
    $fn = $ast.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }.GetNewClosure(), $true)
    if (-not $fn) { throw "missing runtime function $name" }
    # Replace script-scope mocks even when CI invokes this as a child script.
    . ([scriptblock]::Create($fn.Extent.Text.Replace("function $name", "function script:$name")))
  }
}

# Execute the real top-level installer, replacing only platform/step effects.
$Fixture = Join-Path $Sandbox 'checkout'
$null = New-Item -ItemType Directory -Path (Join-Path $Fixture 'windows/scripts') -Force
Copy-Item (Join-Path $Repo 'windows/install.ps1') (Join-Path $Fixture 'windows/install.ps1')
Copy-Item (Join-Path $Repo 'windows/scripts/lib.ps1') (Join-Path $Fixture 'windows/scripts/lib.ps1')
@'
function Test-IsWindows { return $true }
function Update-SessionPath {}
function Update-AiPath { param([switch]$Persist) }
function Test-HasCommand { param($Name) return $Name -in @('git','node','npm','claude','codex') }
function Invoke-NativeSilently {
  param($Exe, $Arguments, [switch]$RequireSuccess)
  Write-Host "PROBE:$Exe`:$($Arguments -join ',')"
  $global:LASTEXITCODE = if ($Exe -eq $env:FAIL_TOOL) { 17 } else { 0 }
  return '1.2.3'
}
'@ | Add-Content (Join-Path $Fixture 'windows/scripts/lib.ps1')
$Ids = @('prereqs','packages','runtimes','shell','docker','git','agents','wsl')
for ($i = 0; $i -lt $Ids.Count; $i++) {
  $id = $Ids[$i]
  $name = '{0:00}-{1}.ps1' -f ($i + 1), $id
  "function Step-$id { Write-Host 'STEP:$id' }" | Set-Content (Join-Path $Fixture "windows/scripts/$name")
}
function Invoke-TestPowerShell([string]$File, [string[]]$Flags) {
  $previous = $ErrorActionPreference
  try {
    # Expected native stderr becomes ErrorRecords on WinPS 5.1. Keep it in
    # Output and assert the child's exit code instead of aborting the harness.
    $ErrorActionPreference = 'Continue'
    $output = & $PowerShell -NoProfile -File $File @Flags 2>&1 | Out-String
    $code = $LASTEXITCODE
  } finally { $ErrorActionPreference = $previous }
  [pscustomobject]@{ Code = $code; Output = $output }
}
function Invoke-Fixture([string[]]$Flags) {
  $r = Invoke-TestPowerShell (Join-Path $Fixture 'windows/install.ps1') $Flags
  $output = $r.Output
  $code = $r.Code
  [pscustomobject]@{ Code = $code; Output = $output; Steps = @([regex]::Matches($output, 'STEP:(\w+)') | ForEach-Object { $_.Groups[1].Value }); Probes = @([regex]::Matches($output, 'PROBE:(\w+):--version') | ForEach-Object { $_.Groups[1].Value }) }
}
Test-Case 'child stderr ErrorRecords preserve output and exit status' {
  # WinPS 5.1 wraps native stderr in ErrorRecords; emulate that boundary on PS7.
  $PowerShell = {
    Write-Error 'STDERR_FIXTURE'
    $global:LASTEXITCODE = 23
    'STDOUT_FIXTURE'
  }
  $r = Invoke-TestPowerShell 'unused-fixture.ps1' @()
  Assert-Equal $r.Code 23
  Assert-Equal $r.Output.Contains('STDERR_FIXTURE') $true
  Assert-Equal $r.Output.Contains('STDOUT_FIXTURE') $true
  Assert-Equal $ErrorActionPreference 'Stop'
}
Test-Case 'default AI selection and executable probes' {
  $r = Invoke-Fixture @('-Yes')
  Assert-Equal $r.Code 0
  Assert-Equal $r.Steps @('prereqs','packages','runtimes','shell','agents')
  Assert-Equal $r.Probes @('git','node','npm','claude','codex')
  if (-not $r.Output.Contains('[starter-kit:ai-ready]')) { throw 'missing readiness sentinel' }
}
Test-Case 'explicit legacy and selective semantics' {
  foreach ($p in @('recommended','full','minimal','work')) {
    $expected = switch ($p) { recommended { @('prereqs','packages','runtimes','shell','git','agents') }; full { $Ids }; minimal { @('prereqs','packages','runtimes','shell','git') }; work { @('prereqs','packages','runtimes','shell','git','agents') } }
    $r = Invoke-Fixture @('-Yes','-Profile',$p)
    Assert-Equal $r.Code 0; Assert-Equal $r.Steps $expected
  }
  $r = Invoke-Fixture @('-Yes','-Skip','docker')
  Assert-Equal $r.Steps @($Ids | Where-Object { $_ -ne 'docker' })
  $r = Invoke-Fixture @('-Yes','-Only','shell')
  Assert-Equal $r.Steps @('shell'); Assert-Equal $r.Probes @()
  $r = Invoke-Fixture @('-Yes','-Profile','ai','-Only','shell')
  if ($r.Code -eq 0) { throw 'explicit profile/only conflict accepted' }
}
Test-Case 'preview never probes readiness or reports ready' {
  $r = Invoke-Fixture @('-Yes','-DryRun','-Profile','ai')
  Assert-Equal $r.Code 0; Assert-Equal $r.Probes @()
  if ($r.Output.Contains('[starter-kit:ai-ready]')) { throw 'preview reports readiness' }
}
Test-Case 'every failing required executable is action-needed' {
  try {
    foreach ($tool in @('git','node','npm','claude','codex')) {
      $env:FAIL_TOOL = $tool
      $r = Invoke-Fixture @('-Yes','-Profile','ai')
      Assert-Equal $r.Probes @('git','node','npm','claude','codex')
      if ($r.Code -eq 0 -or $r.Output.Contains('[starter-kit:ai-ready]')) { throw "false readiness: $tool" }
    }
  } finally { Remove-Item Env:FAIL_TOOL -ErrorAction SilentlyContinue }
}
Test-Case 'AI doctor probes only selected executable dependencies' {
  $r = Invoke-Fixture @('-Doctor','-Profile','ai')
  Assert-Equal $r.Code 0; Assert-Equal $r.Probes @('git','node','npm','claude','codex')
  $r = Invoke-Fixture @('-Doctor','-Profile','ai','-Skip','agents')
  Assert-Equal $r.Code 0; Assert-Equal $r.Probes @('git','node','npm')
  $r = Invoke-Fixture @('-Yes','-Profile','ai','-Skip','agents')
  Assert-Equal $r.Probes @('git','node','npm')
  if ($r.Output.Contains('[starter-kit:ai-ready]')) { throw 'partial selection reports full readiness' }
}

. (Join-Path $Repo 'windows/scripts/lib.ps1')
$script:RunFromFile = $false
$script:DryRun = $false
$script:InstallProfile = 'ai'
function Update-SessionPath {}
function Update-AiPath { param([switch]$Persist) }
function Write-Step { param($Message) }
function Write-Info { param($Message) }
function Write-Ok { param($Message) }
function Test-HasCommand { param($Name) return $true }
function Install-WingetPackage { param($Id, $Name) $script:Packages += $Id }
function Invoke-Run { param($Exe, $Arguments, [switch]$RequireSuccess) throw "unexpected execution: $Exe $Arguments" }
function Invoke-NativeSilently { param($Exe, $Arguments, [switch]$RequireSuccess) $global:LASTEXITCODE = 0; return 'fixture-version' }
Test-Case 'AI package/runtime steps request only Git and Node LTS' {
  $script:Packages = @()
  . (Join-Path $Repo 'windows/scripts/02-packages.ps1')
  . (Join-Path $Repo 'windows/scripts/03-runtimes.ps1')
  Step-Packages; Step-Runtimes
  Assert-Equal $script:Packages @('Git.Git','OpenJS.NodeJS.LTS')
}
Test-Case 'missing tool cannot satisfy executable readiness' {
  Import-Functions (Join-Path $Repo 'windows/scripts/lib.ps1') @('Test-AiReadiness')
  function Test-HasCommand { param($Name) return $Name -ne 'npm' }
  function Invoke-NativeSilently { param($Exe, $Arguments, [switch]$RequireSuccess) $global:LASTEXITCODE = 0; '1.2.3' }
  Assert-Equal (Test-AiReadiness -Steps @('packages','runtimes','agents')) $false
}
Test-Case 'PATH merge preserves user entries without a convenience pack' {
  Assert-Equal (Merge-AiPath -Existing 'C:\custom;C:\AI\bin\' -Additional @('c:\ai\bin','C:\Users\Beginner\.local\bin','C:\Users\Beginner\AppData\Roaming\npm')) 'C:\custom;C:\AI\bin\;C:\Users\Beginner\.local\bin;C:\Users\Beginner\AppData\Roaming\npm'
  function Update-AiPath { param([switch]$Persist) $script:PersistRequested = [bool]$Persist }
  function Update-ManagedBlock { throw 'AI must not change PowerShell profiles' }
  function Install-Module { throw 'AI must not install convenience modules' }
  $script:PersistRequested = $false
  . (Join-Path $Repo 'windows/scripts/04-shell.ps1')
  Step-Shell
  Assert-Equal $script:PersistRequested $true
}
Test-Case 'agent step installs safety hooks and fails closed on hook failure' {
  $Root = Join-Path $Repo 'windows'
  $script:GuardCalls = @()
  function node {
    $script:GuardCalls += ,@($args)
    $global:LASTEXITCODE = $script:GuardExit
  }
  $script:GuardExit = 0
  . (Join-Path $Repo 'windows/scripts/07-agents.ps1')
  Step-Agents
  Assert-Equal $script:GuardCalls.Count 1
  Assert-Equal $script:GuardCalls[0] @((Join-Path $Repo 'scripts/ai/install-shell-guard.js'),'--home',$Sandbox)
  $script:GuardExit = 9
  $failed = $false
  try { Step-Agents } catch { $failed = $true }
  Assert-Equal $failed $true
}
Test-Case 'real preview steps perform no filesystem writes or external installs' {
  $preview = Join-Path $Sandbox 'preview-source'
  $null = New-Item -ItemType Directory -Path $preview
  Copy-Item (Join-Path $Repo 'windows') $preview -Recurse
  @'
function Test-IsWindows { return $true }
function winget { if (($args -join ',') -ne '--version') { throw 'Preview invoked winget installation' }; $global:LASTEXITCODE = 0; 'fixture-winget' }
function npm { throw 'Preview invoked npm' }
function node { throw 'Preview invoked node' }
function claude { throw 'Preview launched Claude' }
function codex { throw 'Preview launched Codex' }
function Invoke-RestMethod { throw 'Preview downloaded a tool' }
'@ | Add-Content (Join-Path $preview 'windows/scripts/lib.ps1')
  $before = @(Get-ChildItem -LiteralPath $Sandbox -Recurse -Force | Sort-Object FullName | ForEach-Object { $_.FullName })
  $output = & $PowerShell -NoProfile -File (Join-Path $preview 'windows/install.ps1') -Yes -DryRun -Profile ai 2>&1 | Out-String
  $code = $LASTEXITCODE
  $output | Set-Content (Join-Path $Evidence 'real-preview.log')
  Assert-Equal $code 0
  Assert-Equal @(Get-ChildItem -LiteralPath $Sandbox -Recurse -Force | Sort-Object FullName | ForEach-Object { $_.FullName }) $before
}
Test-Case 'bundled bootstrap preview works offline without Git or a checkout' {
  $bootstrap = Join-Path $Sandbox 'bootstrap-install.ps1'
  Copy-Item (Join-Path $Repo 'windows/install.ps1') $bootstrap
  $before = @(Get-ChildItem -LiteralPath $Sandbox -Recurse -Force | Sort-Object FullName | ForEach-Object { $_.FullName })
  $oldPath = $env:Path
  try {
    $env:Path = ''
    $output = & $PowerShell -NoProfile -File $bootstrap -DryRun -Yes -Profile ai 2>&1 | Out-String
    $code = $LASTEXITCODE
  } finally { $env:Path = $oldPath }
  $output | Set-Content (Join-Path $Evidence 'bootstrap-preview.log')
  Assert-Equal $code 0
  Assert-Equal @([regex]::Matches($output, '\[starter-kit:stage:(\w+)\]') | ForEach-Object { $_.Groups[1].Value }) @('prereqs','packages','runtimes','shell','agents')
  Assert-Equal @(Get-ChildItem -LiteralPath $Sandbox -Recurse -Force | Sort-Object FullName | ForEach-Object { $_.FullName }) $before
}
Test-Case 'GUI default and post-install eligibility' {
  $contract = & (Join-Path $Repo 'gui/windows/installer.ps1') -SelfTest | ConvertFrom-Json
  Assert-Equal $contract.profiles @('ai','recommended','full','minimal','work')
  Assert-Equal $contract.defaultProfile 'ai'
  Assert-Equal $contract.previewByDefault $false
  Assert-Equal $contract.separatePreviewAction $true
  Import-Functions (Join-Path $Repo 'gui/windows/installer.ps1') @('Test-OnboardingReady','New-PracticeDirectory','Get-AgentLaunchCommand')
  Assert-Equal (Test-OnboardingReady -ExitCode 0 -Preview $false -Cancelled $false -Profile 'ai' -Log '[starter-kit:ai-ready]') $true
  foreach ($state in @(@{ExitCode=1}, @{Preview=$true}, @{Cancelled=$true}, @{Profile='full'}, @{Log='' })) {
    $p = @{ ExitCode=0; Preview=$false; Cancelled=$false; Profile='ai'; Log='[starter-kit:ai-ready]' }
    foreach ($key in $state.Keys) { $p[$key] = $state[$key] }
    Assert-Equal (Test-OnboardingReady @p) $false
  }
  $base = Join-Path $Sandbox "practice space $([char]0xD55C)$([char]0xAE00) ' quote"
  $null = New-Item -ItemType Directory -Path $base
  Set-Content (Join-Path $base 'existing.txt') 'untouched'
  $first = New-PracticeDirectory -Parent $base
  $second = New-PracticeDirectory -Parent $base
  if ($first -eq $second -or -not (Test-Path -LiteralPath $first)) { throw 'practice folders must be new' }
  Assert-Equal (Get-Content (Join-Path $base 'existing.txt')) 'untouched'
  Assert-Equal @(Get-ChildItem -LiteralPath $first).Count 0
  foreach ($agent in @('claude','codex')) {
    $command = Get-AgentLaunchCommand -Agent $agent -Directory $first
    $decoded = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($command))
    function git { $global:LASTEXITCODE = 0; 'fixture-git' }
    function node { $global:LASTEXITCODE = 0; 'fixture-node' }
    function npm { $global:LASTEXITCODE = 0; 'fixture-npm' }
    function claude { $script:LaunchArgs = @($args); $script:LaunchDirectory = (Get-Location).Path; $global:LASTEXITCODE = 0; 'fixture-claude' }
    function codex { $script:LaunchArgs = @($args); $script:LaunchDirectory = (Get-Location).Path; $global:LASTEXITCODE = 0; 'fixture-codex' }
    $oldLocation = Get-Location
    try {
      & ([scriptblock]::Create($decoded))
      Assert-Equal $script:LaunchDirectory $first
      Assert-Equal $script:LaunchArgs @()
      # Reverification in the launch terminal must fail before agent startup.
      function npm { $global:LASTEXITCODE = 19; 'broken-npm' }
      $script:LaunchDirectory = $null
      $failed = $false
      try { & ([scriptblock]::Create($decoded)) } catch { $failed = $true }
      Assert-Equal $failed $true
      Assert-Equal $script:LaunchDirectory $null
    } finally { Set-Location -LiteralPath $oldLocation.Path }
  }
}
Test-Case 'primary and preview buttons dispatch distinct installer modes' {
  $tokens = $null; $errors = $null
  $ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $Repo 'gui/windows/installer.ps1'), [ref]$tokens, [ref]$errors)
  Assert-Equal $errors.Count 0
  function Start-InstallerRun([bool]$Preview) { $script:DispatchedPreview = $Preview }
  foreach ($name in @('installButton', 'previewButton')) {
    $handler = $ast.Find({ param($n)
      $n -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
      $n.Expression.Extent.Text -eq ('$' + $name) -and $n.Member.Value -eq 'Add_Click'
    }.GetNewClosure(), $true)
    if (-not $handler) { throw "No click handler for $name" }
    $script:DispatchedPreview = $null
    & $handler.Arguments[0].ScriptBlock.GetScriptBlock()
    Assert-Equal $script:DispatchedPreview ($name -eq 'previewButton')
  }
}
Test-Case 'release archive pins its bundled installer and previews offline' {
  $package = Join-Path $Sandbox 'package'
  $null = New-Item -ItemType Directory -Path $package
  $hash = (Get-FileHash (Join-Path $Repo 'windows/install.ps1') -Algorithm SHA256).Hash.ToLowerInvariant()
  $gui = [IO.File]::ReadAllText((Join-Path $Repo 'gui/windows/installer.ps1')).Replace('__BOOTSTRAP_SHA256__', $hash)
  [IO.File]::WriteAllText((Join-Path $package 'installer.ps1'), $gui, (New-Object Text.UTF8Encoding($true)))
  Copy-Item (Join-Path $Repo 'windows/install.ps1') (Join-Path $package 'bootstrap-install.ps1')
  Copy-Item (Join-Path $Repo 'windows/scripts/lib.ps1') (Join-Path $package 'cleanup-lib.ps1')
  Copy-Item (Join-Path $Repo 'gui/windows/cleanup-installer-clone.ps1') $package
  Copy-Item (Join-Path $Repo 'gui/windows/Lazy-Starter-Kit-Installer.cmd') $package
  Copy-Item (Join-Path $Repo 'VERSION') $package
  $commit = '1111111111111111111111111111111111111111'
  $commit | Set-Content (Join-Path $package 'RELEASE_COMMIT') -Encoding ASCII
  $archive = Join-Path $Sandbox 'windows-gui.zip'
  Compress-Archive -Path (Join-Path $package '*') -DestinationPath $archive
  $unpacked = Join-Path $Sandbox 'unpacked'
  Expand-Archive -Path $archive -DestinationPath $unpacked
  $contract = & $PowerShell -NoProfile -File (Join-Path $unpacked 'installer.ps1') -SelfTest | ConvertFrom-Json
  Assert-Equal $LASTEXITCODE 0
  Assert-Equal $contract.installerSource 'bundled'
  Assert-Equal $contract.releaseCommit $commit
  Assert-Equal $contract.releaseRef ('v' + (Get-Content (Join-Path $Repo 'VERSION') -Raw).Trim())
  Assert-Equal $contract.installerSHA256 $hash
  Assert-Equal $contract.defaultProfile 'ai'
  $contract | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $Evidence 'packaged-contract.json')
  $oldPath = $env:Path
  try {
    $env:Path = ''
    $output = & $PowerShell -NoProfile -File (Join-Path $unpacked 'bootstrap-install.ps1') -DryRun -Yes 2>&1 | Out-String
    Assert-Equal $LASTEXITCODE 0
  } finally { $env:Path = $oldPath }
  Assert-Equal @([regex]::Matches($output, '\[starter-kit:stage:(\w+)\]') | ForEach-Object { $_.Groups[1].Value }) @('prereqs','packages','runtimes','shell','agents')
  $output | Set-Content (Join-Path $Evidence 'packaged-preview.log')
  Write-Host "Archive exercised: $archive"
}
Test-Case 'PATH persistence is minimal and idempotent without lifecycle receipts' {
  Import-Functions (Join-Path $Repo 'windows/scripts/lib.ps1') @('Update-AiPath')
  $localBin = Join-Path $Sandbox '.local/bin'
  $script:UserPath = "C:\existing;;$localBin"
  $original = $script:UserPath
  $processPath = $env:Path
  function Get-UserEnvironmentPath { return $script:UserPath }
  function Set-UserEnvironmentPath { param($Value) $script:UserPath = $Value }
  try {
    Update-AiPath -Persist
    $expected = "$original;$(Join-Path $Sandbox 'AppData/Roaming/npm')"
    Assert-Equal $script:UserPath $expected
    Update-AiPath -Persist
    Assert-Equal $script:UserPath $expected
    Assert-Equal (Test-Path -LiteralPath (Join-Path $Sandbox '.local/share/lazy-starter-kit/windows-ai-path.json')) $false
  } finally { $env:Path = $processPath }
}
Test-Case 'retired uninstall exits 2 and leaves the disposable home untouched' {
  $before = @(Get-ChildItem -LiteralPath $Sandbox -Recurse -File -Force | Sort-Object FullName | Get-FileHash | ForEach-Object { "$($_.Path):$($_.Hash)" })
  $r = Invoke-TestPowerShell (Join-Path $Repo 'windows/uninstall.ps1') @('-Yes')
  Assert-Equal $r.Code 2
  Assert-Equal @(Get-ChildItem -LiteralPath $Sandbox -Recurse -File -Force | Sort-Object FullName | Get-FileHash | ForEach-Object { "$($_.Path):$($_.Hash)" }) $before
}
if ($Failures.Count) { throw "$($Failures.Count) test(s) failed:`n$($Failures -join "`n")" }
Write-Host 'PASS Windows beginner onboarding behavior'
