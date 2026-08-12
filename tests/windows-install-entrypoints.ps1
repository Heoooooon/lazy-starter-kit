$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot

$guiInstallerPath = Join-Path $Root 'gui\windows\installer.ps1'
$guiInstallerBytes = [System.IO.File]::ReadAllBytes($guiInstallerPath)
if ($guiInstallerBytes.Length -lt 3 -or
    $guiInstallerBytes[0] -ne 0xEF -or
    $guiInstallerBytes[1] -ne 0xBB -or
    $guiInstallerBytes[2] -ne 0xBF) {
  throw 'Windows GUI installer must retain its UTF-8 BOM for PowerShell 5.1'
}
Write-Host 'ok   Windows GUI source retains PowerShell 5.1 UTF-8 encoding'

if ($env:OS -ne 'Windows_NT') {
  $parseFailures = @()
  Get-ChildItem -Path $Root -Recurse -Filter '*.ps1' | ForEach-Object {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
      $_.FullName,
      [ref]$tokens,
      [ref]$errors
    ) | Out-Null
    if ($errors.Count -gt 0) {
      $parseFailures += "$($_.FullName): $($errors -join '; ')"
    }
  }
  if ($parseFailures.Count -gt 0) {
    throw "PowerShell parse failures:`n$($parseFailures -join "`n")"
  }
  Write-Host 'ok   PowerShell sources parse on the portable QA surface'

  $launcherSource =
    Get-Content (Join-Path $Root 'windows\Install-lazy-starter-kit.cmd') -Raw
  foreach ($token in @(
      'STARTER_KIT_LAUNCHER_SELF_TEST',
      'launcher-ready',
      'powershell.exe',
      '-File "%INSTALL_FILE%"'
    )) {
    if (-not $launcherSource.Contains($token)) {
      throw "Windows launcher is missing its $token contract"
    }
  }
  Write-Host 'ok   Windows launcher retains its cmd.exe hand-off contract'

  $gui = & $guiInstallerPath -SelfTest | Out-String
  $contract = $gui | ConvertFrom-Json
  if (($contract.profiles -join ',') -ne 'full,minimal,work' -or
      -not $contract.supportsDryRun -or
      -not $contract.supportsCancellation) {
    throw "Windows GUI portable self-test contract failed: $gui"
  }

  $bootstrapSource = Get-Content (Join-Path $Root 'windows\install.ps1') -Raw
  if ($bootstrapSource -notmatch
      '(?s)if \(\$Doctor\).+?\$global:LASTEXITCODE\s*=\s*\$code') {
    throw 'Windows bootstrap does not preserve Doctor status through hand-off cleanup'
  }
  Write-Host 'PASS portable Windows installer contracts'
  return
}

# Given the double-click launcher, when its test seam is enabled, then cmd.exe
# reaches the PowerShell installer hand-off without downloading or installing.
$env:STARTER_KIT_LAUNCHER_SELF_TEST = '1'
$launcher = & cmd.exe /d /c (Join-Path $Root 'windows\Install-lazy-starter-kit.cmd') 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { throw "Windows launcher self-test failed: $launcher" }
if ($launcher -notmatch 'launcher-ready') { throw "Windows launcher did not reach its self-test contract: $launcher" }
Remove-Item Env:STARTER_KIT_LAUNCHER_SELF_TEST
Write-Host 'ok   Windows double-click launcher reaches installer hand-off'

$TempRoot = Join-Path $Root '.tmp-tests'

# Given the files shipped in the double-click archive, when the launcher runs,
# then it must select the bundled bootstrap and pass the pinned release ref.
$LauncherPackageDir =
  Join-Path $TempRoot "windows-launcher-$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $LauncherPackageDir -Force | Out-Null
try {
  $launcherPath = Join-Path $LauncherPackageDir 'Install-lazy-starter-kit.cmd'
  $bootstrapPath = Join-Path $LauncherPackageDir 'bootstrap-install.ps1'
  $releaseCommit = '1111111111111111111111111111111111111111'
  @'
[CmdletBinding()]
param()
Write-Output "branch=$env:STARTER_KIT_BRANCH;commit=$env:STARTER_KIT_COMMIT"
exit 0
'@ | Set-Content -LiteralPath $bootstrapPath -Encoding UTF8
  '9.9.9' | Set-Content (Join-Path $LauncherPackageDir 'VERSION') -Encoding ASCII
  $releaseCommit |
    Set-Content (Join-Path $LauncherPackageDir 'RELEASE_COMMIT') -Encoding ASCII
  $bootstrapHash =
    (Get-FileHash -LiteralPath $bootstrapPath -Algorithm SHA256).Hash.ToLowerInvariant()
  $launcherText = [System.IO.File]::ReadAllText(
    (Join-Path $Root 'windows\Install-lazy-starter-kit.cmd'),
    [System.Text.Encoding]::UTF8
  ).Replace('__BOOTSTRAP_SHA256__', $bootstrapHash)
  [System.IO.File]::WriteAllText(
    $launcherPath,
    $launcherText,
    (New-Object System.Text.UTF8Encoding($false))
  )
  $env:STARTER_KIT_NO_PAUSE = '1'
  $launcher = & cmd.exe /d /c $launcherPath 2>&1 | Out-String
  if ($LASTEXITCODE -ne 0) {
    throw "Bundled Windows launcher failed: $launcher"
  }
  if ($launcher -notmatch "branch=v9\.9\.9;commit=$releaseCommit") {
    throw "Bundled Windows launcher did not pass its pinned release: $launcher"
  }

  Remove-Item -LiteralPath (Join-Path $LauncherPackageDir 'RELEASE_COMMIT') -Force
  $launcher = & cmd.exe /d /c $launcherPath 2>&1 | Out-String
  if ($LASTEXITCODE -eq 0 -or
      $launcher -notmatch '릴리스 ZIP을 모두 압축 해제한 뒤 다시 실행해 주세요') {
    throw "Incomplete Windows launcher package did not fail clearly: $launcher"
  }
} finally {
  Remove-Item Env:STARTER_KIT_NO_PAUSE -ErrorAction SilentlyContinue
  . (Join-Path $Root 'windows\scripts\lib.ps1')
  Remove-KitTree -AllowedRoot $TempRoot -Path $LauncherPackageDir
}
Write-Host 'ok   Windows double-click launcher uses its bundled release'

# Given a copied bootstrap outside the repository, when its existing checkout
# is dirty or does not match the pinned commit, then it must fail closed.
$BootstrapTestDir = Join-Path $TempRoot "windows-bootstrap-$([Guid]::NewGuid().ToString('N'))"
$CheckoutDir = Join-Path $BootstrapTestDir 'checkout'
$BootstrapRef = "starter-kit-bootstrap-test-$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $BootstrapTestDir -Force | Out-Null
try {
  $BootstrapScript = Join-Path $BootstrapTestDir 'install.ps1'
  Copy-Item (Join-Path $Root 'windows\install.ps1') $BootstrapScript
  $PinnedCommit = (git -C $Root rev-parse HEAD).Trim()
  git -C $Root branch --force $BootstrapRef $PinnedCommit
  if ($LASTEXITCODE -ne 0) { throw 'Could not create Windows bootstrap test ref' }
  git clone --quiet --no-hardlinks $Root $CheckoutDir
  if ($LASTEXITCODE -ne 0) { throw 'Could not prepare Windows bootstrap checkout' }
  $env:STARTER_KIT_REPO = $Root
  $env:STARTER_KIT_DIR = $CheckoutDir
  $env:STARTER_KIT_BRANCH = $BootstrapRef
  $env:STARTER_KIT_COMMIT = '0000000000000000000000000000000000000000'
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $BootstrapScript -List *> $null
  if ($LASTEXITCODE -eq 0) {
    throw 'Windows bootstrap accepted a ref that did not match its pinned commit'
  }
  $env:STARTER_KIT_COMMIT = $PinnedCommit
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $BootstrapScript -List *> $null
  if ($LASTEXITCODE -ne 0) {
    throw 'Windows bootstrap rejected its exact pinned commit'
  }
  Set-Content (Join-Path $CheckoutDir 'untracked-change') 'local change'
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $BootstrapScript -List *> $null
  if ($LASTEXITCODE -eq 0) {
    throw 'Windows bootstrap executed from a dirty checkout'
  }

  # Given an ephemeral hand-off target that exits non-zero without throwing,
  # then the bootstrap must preserve that exact exit code and remove the clone.
  $HandoffFixtureRepo = Join-Path $BootstrapTestDir 'handoff-fixture'
  $HandoffCloneDir = Join-Path $BootstrapTestDir 'handoff-clone'
  New-Item -ItemType Directory -Path `
    (Join-Path $HandoffFixtureRepo 'windows\scripts') -Force | Out-Null
  @'
[CmdletBinding()]
param([switch]$List)
exit 23
'@ | Set-Content `
    (Join-Path $HandoffFixtureRepo 'windows\install.ps1') -Encoding UTF8
  Copy-Item (Join-Path $Root 'windows\scripts\lib.ps1') `
    (Join-Path $HandoffFixtureRepo 'windows\scripts\lib.ps1')
  git -C $HandoffFixtureRepo init --quiet --initial-branch handoff-test
  git -C $HandoffFixtureRepo config user.name 'starter-kit test'
  git -C $HandoffFixtureRepo config user.email 'starter-kit-test@example.invalid'
  git -C $HandoffFixtureRepo add .
  git -C $HandoffFixtureRepo commit --quiet -m fixture
  if ($LASTEXITCODE -ne 0) { throw 'Could not prepare hand-off fixture repository' }

  $env:STARTER_KIT_REPO = $HandoffFixtureRepo
  $env:STARTER_KIT_DIR = $HandoffCloneDir
  $env:STARTER_KIT_EPHEMERAL_ROOT = $HandoffCloneDir
  $env:STARTER_KIT_BRANCH = 'handoff-test'
  Remove-Item Env:STARTER_KIT_COMMIT -ErrorAction SilentlyContinue
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $BootstrapScript -List *> $null
  if ($LASTEXITCODE -ne 23) {
    throw "Windows ephemeral hand-off returned $LASTEXITCODE instead of 23"
  }
  if (Test-Path -LiteralPath $HandoffCloneDir) {
    throw 'Windows ephemeral hand-off did not remove its checkout'
  }
} finally {
  Remove-Item Env:STARTER_KIT_REPO -ErrorAction SilentlyContinue
  Remove-Item Env:STARTER_KIT_DIR -ErrorAction SilentlyContinue
  Remove-Item Env:STARTER_KIT_EPHEMERAL_ROOT -ErrorAction SilentlyContinue
  Remove-Item Env:STARTER_KIT_BRANCH -ErrorAction SilentlyContinue
  Remove-Item Env:STARTER_KIT_COMMIT -ErrorAction SilentlyContinue
  git -C $Root branch --delete --force $BootstrapRef *> $null
  . (Join-Path $Root 'windows\scripts\lib.ps1')
  Remove-KitTree -AllowedRoot $TempRoot -Path $BootstrapTestDir
}
Write-Host 'ok   Windows bootstrap fails closed on commit and checkout drift'

# Given the GUI installer, when it runs in self-test mode, then it exposes the
# profiles and preview support consumed by the release/QA checks.
$gui = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
  $guiInstallerPath -SelfTest | Out-String
if ($LASTEXITCODE -ne 0) { throw "Windows GUI self-test failed: $gui" }
$contract = $gui | ConvertFrom-Json
$guiSource = Get-Content (Join-Path $Root 'gui\windows\installer.ps1') -Raw
$bootstrapSource = Get-Content (Join-Path $Root 'windows\install.ps1') -Raw
if ($bootstrapSource -notmatch
    '(?s)if \(\$Doctor\).+?\$global:LASTEXITCODE\s*=\s*\$code') {
  throw 'Windows bootstrap does not preserve Doctor status through hand-off cleanup'
}
if (($contract.profiles -join ',') -ne 'full,minimal,work') {
  throw "Windows GUI profiles are incomplete: $gui"
}
if (-not $contract.supportsDryRun) { throw "Windows GUI does not report dry-run support: $gui" }
if ($contract.installerSource -notin @('repo', 'bundled')) {
  throw "Windows GUI does not expose a local bootstrap source: $gui"
}
if ($contract.releaseRef -eq 'main' -and $contract.appVersion -ne 'dev') {
  throw "Windows GUI claims a release version while using mutable main: $gui"
}
if (-not $contract.actionTitlesTrackPreviewState) {
  throw "Windows GUI does not report preview/install title synchronization: $gui"
}
if (-not $contract.supportsCancellation) {
  throw "Windows GUI does not report active-install cancellation: $gui"
}
if ($guiSource -match 'raw\.githubusercontent\.com/.+/main/') {
  throw 'Windows GUI still downloads a mutable main bootstrap'
}
if ($guiSource -notmatch '\$dryRun\.Add_CheckedChanged') {
  throw 'Windows GUI preview checkbox does not update the primary action'
}
if ($guiSource -notmatch "taskkill\.exe") {
  throw 'Windows GUI cancellation does not terminate the installer process tree'
}
if ($guiSource -notmatch '\$script:InstallerCloneDir = \$cloneDirectory' -or
    $guiSource -notmatch '-File \$CleanupScriptPath' -or
    $guiSource -notmatch '-Path \$script:InstallerCloneDir') {
  throw 'Windows GUI cancellation does not clean its ephemeral checkout'
}
if ($guiSource -match '(?m)^\.\s+\$CleanupLibraryPath') {
  throw 'Windows GUI imports cleanup state into its UI script scope'
}
Write-Host 'ok   Windows GUI reports its contract'

# Given the exact files uploaded in the Windows GUI archive, when that packaged
# installer self-tests, then it must identify its immutable release payload.
$PackageDir = Join-Path $TempRoot "windows-gui-$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $PackageDir -Force | Out-Null
try {
  $bootstrapSource = Join-Path $Root 'windows\install.ps1'
  $bootstrapHash =
    (Get-FileHash -LiteralPath $bootstrapSource -Algorithm SHA256).Hash.ToLowerInvariant()
  $packagedGuiSource = [System.IO.File]::ReadAllText(
    (Join-Path $Root 'gui\windows\installer.ps1'),
    [System.Text.Encoding]::UTF8
  ).Replace(
    '__BOOTSTRAP_SHA256__',
    $bootstrapHash
  )
  [System.IO.File]::WriteAllText(
    (Join-Path $PackageDir 'installer.ps1'),
    $packagedGuiSource,
    (New-Object System.Text.UTF8Encoding($true))
  )
  Copy-Item (Join-Path $Root 'windows\install.ps1') `
    (Join-Path $PackageDir 'bootstrap-install.ps1')
  Copy-Item (Join-Path $Root 'windows\scripts\lib.ps1') `
    (Join-Path $PackageDir 'cleanup-lib.ps1')
  Copy-Item (Join-Path $Root 'gui\windows\cleanup-installer-clone.ps1') `
    (Join-Path $PackageDir 'cleanup-installer-clone.ps1')
  Copy-Item (Join-Path $Root 'VERSION') $PackageDir
  $releaseCommit = (git -C $Root rev-parse HEAD).Trim()
  $releaseCommit | Set-Content (Join-Path $PackageDir 'RELEASE_COMMIT') -Encoding ASCII
  $packagedGui = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
    (Join-Path $PackageDir 'installer.ps1') -SelfTest | Out-String
  if ($LASTEXITCODE -ne 0) {
    throw "Packaged Windows GUI self-test failed: $packagedGui"
  }
  $packagedContract = $packagedGui | ConvertFrom-Json
  $kitVersion = (Get-Content (Join-Path $Root 'VERSION') -Raw).Trim()
  if ($packagedContract.appVersion -ne $kitVersion) {
    throw "Packaged Windows GUI version is not $kitVersion`: $packagedGui"
  }
  if ($packagedContract.releaseRef -ne "v$kitVersion") {
    throw "Packaged Windows GUI does not pin v$kitVersion`: $packagedGui"
  }
  if ($packagedContract.releaseCommit -ne $releaseCommit) {
    throw "Packaged Windows GUI does not pin commit $releaseCommit`: $packagedGui"
  }
  if ($packagedContract.installerSource -ne 'bundled') {
    throw "Packaged Windows GUI does not use its bundled bootstrap: $packagedGui"
  }
} finally {
  . (Join-Path $Root 'windows\scripts\lib.ps1')
  Remove-KitTree -AllowedRoot $TempRoot -Path $PackageDir
  if ((Test-Path -LiteralPath $TempRoot) -and
      -not (Get-ChildItem -LiteralPath $TempRoot -Force | Select-Object -First 1)) {
    Remove-Item -LiteralPath $TempRoot -Force
  }
}
Write-Host 'ok   Packaged Windows GUI pins its bundled release bootstrap'

Write-Host 'PASS Windows install entrypoints'
