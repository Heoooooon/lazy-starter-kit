#requires -Version 5.1
<#
.SYNOPSIS
  lazy-starter-kit -- uninstaller. Reverses install.ps1 in reverse order.

.DESCRIPTION
  Destructive groups are confirm-gated. Never auto-removes your git identity.
  gajae-code (gjc) is kept unless you pass -WithGajae.

  Groups (reverse order): wsl agents shell docker runtimes packages

.PARAMETER DryRun         Show what would happen, change nothing.
.PARAMETER Yes            Non-interactive: accept every removal prompt.
.PARAMETER Only           Comma-separated groups to run.
.PARAMETER Skip           Comma-separated groups to skip.
.PARAMETER WithGajae      Also remove gajae-code (gjc). Refused if gjc is running.
.PARAMETER KeepCodexHome  Keep ~/.codex when removing codex.
.PARAMETER List           List group ids and exit.
#>
[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$Yes,
  [string[]]$Only = @(),
  [string[]]$Skip = @(),
  [switch]$WithGajae,
  [switch]$KeepCodexHome,
  [switch]$List
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
if (-not $Root) { $Root = Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $Root 'scripts\lib.ps1')
$script:DryRun    = [bool]$DryRun
$script:AssumeYes = [bool]$Yes

$versionFile = Join-Path $Root '..\VERSION'
$KitVersion = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { 'dev' }

$GroupIds = @('wsl', 'agents', 'shell', 'docker', 'runtimes', 'packages')

# ---------------------------------------------------------------------------
# wsl -- reverse of install: the WSL step runs LAST (it bootstraps a whole Linux
# environment and runs the Linux kit inside it), so its teardown runs FIRST.
# Unregistering the distro deletes everything the Linux kit / Hermes installed
# inside it, so it belongs ahead of the Windows-side agents.
# ---------------------------------------------------------------------------
function Undo-Wsl {
  Write-Step "Remove the WSL Ubuntu distro (optional)"

  $distro = 'Ubuntu'
  # WSL_UTF8=1 makes wsl.exe emit UTF-8 so `--list` output is parseable.
  $env:WSL_UTF8 = '1'

  if (-not (Test-HasCommand wsl)) { Write-Info "wsl.exe not present -- nothing to remove"; return }

  Invoke-NativeSilently 'wsl' @('--status') | Out-Null
  if ($LASTEXITCODE -ne 0) { Write-Info "WSL not installed -- nothing to remove"; return }

  $names = Invoke-NativeSilently 'wsl' @('--list', '--quiet')
  $registered = $false
  if (($LASTEXITCODE -eq 0) -and $names) {
    $registered = [bool](@($names | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -contains $distro)
  }
  if (-not $registered) { Write-Info "$distro not registered -- nothing to remove"; return }

  if ($script:DryRun) {
    Write-Info "[dry-run] would offer:  wsl --unregister $distro  (DELETES the distro filesystem)"
    Write-Info "[dry-run] WSL itself (the platform) is left installed either way."
    return
  }

  # DATA LOSS: `wsl --unregister` permanently deletes the entire distro
  # filesystem -- everything the Linux kit / Hermes installed inside it. So this
  # is a DefaultNo gate that NEVER fires under -Yes (AssumeYes returns $false),
  # and a bare Enter declines.
  Write-Warn "DATA LOSS: 'wsl --unregister $distro' permanently deletes the $distro filesystem"
  Write-Warn "(all files, packages, and the Linux kit / Hermes install inside it)."
  if (Confirm-Action "Unregister (delete) the $distro distro?" -DefaultNo) {
    & wsl --unregister $distro
    if ($LASTEXITCODE -eq 0) { Write-Ok "unregistered $distro (distro filesystem deleted)" }
    else { Write-Warn "wsl --unregister $distro exited $LASTEXITCODE" }
  } else {
    Write-Info "kept the $distro distro"
  }
  Write-Info "WSL itself (the platform) stays installed -- remove it via 'Turn Windows features on or off' if wanted."
}

# ---------------------------------------------------------------------------
# agents
# ---------------------------------------------------------------------------
function Undo-Agents {
  Write-Step "Remove AI agents (codex + lazycodex + Claude Code)"
  Update-SessionPath

  $safetyInstaller = Join-Path (Split-Path -Parent $Root) 'scripts\ai\install-shell-guard.js'
  if ((Test-HasCommand node) -and (Test-Path -LiteralPath $safetyInstaller)) {
    $safetyArgs = @($safetyInstaller, 'uninstall', '--home', $env:USERPROFILE)
    if ($script:DryRun) { $safetyArgs += '--dry-run' }
    & node @safetyArgs
    if ($LASTEXITCODE -ne 0) { Write-Warn "could not remove the lazy-starter-kit AI safety hook" }
  }

  # codex is installed either through mise's npm shim OR plain global npm --
  # 07-agents falls back to `npm install -g '@openai/codex'` when mise is absent,
  # so uninstall must cover both or it silently leaves codex behind.
  if (Test-HasCommand mise) {
    $installed = (Invoke-NativeSilently 'mise' @('exec', '--', 'npm', 'ls', '-g', '--depth=0') | Out-String)
    if ($installed -match '@openai/codex') {
      Write-Info "Uninstalling @openai/codex (mise npm)..."
      if (-not $script:DryRun) { & mise exec -- npm uninstall -g '@openai/codex'; Invoke-NativeSilently 'mise' @('reshim') }
      else { Write-Info "[dry-run] mise exec -- npm uninstall -g @openai/codex" }
    } else { Write-Info "codex npm package not installed (mise)" }
  }
  if (Test-HasCommand npm) {
    $installedNpm = (Invoke-NativeSilently 'npm' @('ls', '-g', '--depth=0') | Out-String)
    if ($installedNpm -match '@openai/codex') {
      Write-Info "Uninstalling @openai/codex (npm -g)..."
      if (-not $script:DryRun) { Invoke-NativeSilently 'npm' @('uninstall', '-g', '@openai/codex') | Out-Null; Write-Ok "removed @openai/codex (npm)" }
      else { Write-Info "[dry-run] npm uninstall -g @openai/codex" }
    } else { Write-Info "codex npm package not installed (npm)" }
  }

  # Antigravity CLI (opt-in install: ANTIGRAVITY=1) -- remove its install dir
  $agyDir = Join-Path $env:LOCALAPPDATA 'agy'
  if (Test-Path $agyDir) {
    if ($script:DryRun) { Write-Info "[dry-run] remove $agyDir" }
    else { Remove-KitTree -AllowedRoot $env:LOCALAPPDATA -Path $agyDir }
    Write-Ok "Antigravity CLI removed"
  }
  # lazycodex npx cache
  $npxRoots = @(
    (Join-Path $env:LOCALAPPDATA 'npm-cache\_npx'),
    (Join-Path $env:APPDATA 'npm-cache\_npx')
  )
  $cleared = $false
  foreach ($root in $npxRoots) {
    if (-not (Test-Path $root)) { continue }
    foreach ($dir in (Get-ChildItem $root -Directory -ErrorAction SilentlyContinue)) {
      if (Test-Path (Join-Path $dir.FullName 'node_modules\lazycodex-ai')) {
        Remove-KitTree -AllowedRoot $root -Path $dir.FullName
        $cleared = $true
      }
    }
  }
  if ($cleared) { Write-Ok "cleared lazycodex npx cache" } else { Write-Info "no lazycodex npx cache" }

  # ~/.codex
  $codexHome = Join-Path $env:USERPROFILE '.codex'
  if ((Test-Path $codexHome) -and (-not $KeepCodexHome)) {
    if (Confirm-Action "Remove ~/.codex (codex home: config, auth, sessions, omo plugin)?") {
      $auth = Join-Path $codexHome 'auth.json'
      if (Test-Path $auth) {
        $bak = Join-Path $env:USERPROFILE ("codex-auth-backup-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".json")
        if ($script:DryRun) { Write-Info "[dry-run] would back up ~/.codex/auth.json -> $($bak.Replace($env:USERPROFILE, '~'))" }
        else { Copy-Item $auth $bak; Write-Ok "backed up auth.json -> $bak" }
      }
      if ($script:DryRun) { Write-Info "[dry-run] would remove ~/.codex" }
      else { Remove-KitTree -AllowedRoot $env:USERPROFILE -Path $codexHome; Write-Ok "removed ~/.codex" }
    } else { Write-Info "kept ~/.codex" }
  }

  # Claude Code (claude) -- native install from https://claude.ai/install.ps1.
  # Remove the binary + data dir unconditionally (mirrors the native uninstall);
  # ~/.claude settings/auth are confirm-gated below like ~/.codex.
  $claudeBin  = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
  $claudeData = Join-Path $env:USERPROFILE '.local\share\claude'
  if ((Test-Path $claudeBin) -or (Test-Path $claudeData)) {
    if ($script:DryRun) {
      if (Test-Path $claudeBin)  { Write-Info "[dry-run] would remove ~/.local/bin/claude.exe" }
      if (Test-Path $claudeData) { Write-Info "[dry-run] would remove ~/.local/share/claude" }
    } else {
      if (Test-Path $claudeBin)  { Remove-Item -LiteralPath $claudeBin -Force -ErrorAction SilentlyContinue }
      if (Test-Path $claudeData) { Remove-KitTree -AllowedRoot $env:USERPROFILE -Path $claudeData }
      Write-Ok "removed Claude Code (claude.exe + data dir)"
    }
  } else {
    Write-Info "Claude Code not installed"
  }

  # ~/.claude + ~/.claude.json (Claude Code settings, history, auth)
  $claudeHome = Join-Path $env:USERPROFILE '.claude'
  $claudeJson = Join-Path $env:USERPROFILE '.claude.json'
  if ((Test-Path $claudeHome) -or (Test-Path $claudeJson)) {
    if (Confirm-Action "Remove ~/.claude and ~/.claude.json (Claude Code settings, history, auth)?") {
      if (Test-Path $claudeJson) {
        $bak = Join-Path $env:USERPROFILE ("claude-json-backup-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + ".json")
        if ($script:DryRun) { Write-Info "[dry-run] would back up ~/.claude.json -> $($bak.Replace($env:USERPROFILE, '~'))" }
        else { Copy-Item $claudeJson $bak; Write-Ok "backed up .claude.json -> $bak" }
      }
      if ($script:DryRun) { Write-Info "[dry-run] would remove ~/.claude and ~/.claude.json" }
      else {
        if (Test-Path $claudeHome) { Remove-KitTree -AllowedRoot $env:USERPROFILE -Path $claudeHome }
        if (Test-Path $claudeJson) { Remove-Item -LiteralPath $claudeJson -Force -ErrorAction SilentlyContinue }
        Write-Ok "removed ~/.claude and ~/.claude.json"
      }
    } else { Write-Info "kept ~/.claude and ~/.claude.json" }
  }

  # gajae-code (gjc)
  if ($WithGajae) {
    if (Get-Process -Name gjc -ErrorAction SilentlyContinue) {
      Write-Warn "gjc is RUNNING -- refusing to remove gajae-code (close the session, then re-run)"
    } elseif (Test-HasCommand gjc) {
      Write-Info "Removing gajae-code..."
      if (-not $script:DryRun) { & bun remove -g gajae-code } else { Write-Info "[dry-run] bun remove -g gajae-code" }
    } else { Write-Info "gajae-code not installed" }
  } else {
    Write-Info "Keeping gajae-code (pass -WithGajae to remove)"
  }
}

# ---------------------------------------------------------------------------
# shell
# ---------------------------------------------------------------------------
function Undo-Shell {
  Write-Step "Revert shell configuration"
  # Strip the block from BOTH host profiles (5.1 WindowsPowerShell\ and 7
  # PowerShell\); the installer writes both.
  foreach ($profilePath in (Get-AllHostsProfilePaths)) {
    Remove-ManagedBlock -Path $profilePath -Tag 'lazy-starter-kit:main'
  }

  $starshipToml = Join-Path $env:USERPROFILE '.config\starship.toml'
  if (Test-Path $starshipToml) {
    if (Confirm-Action "Remove ~/.config/starship.toml?") {
      if (-not $script:DryRun) { Remove-Item -LiteralPath $starshipToml -Force }
    } else { Write-Info "kept starship.toml" }
  }
}

# ---------------------------------------------------------------------------
# docker
# ---------------------------------------------------------------------------
function Undo-Docker {
  Write-Step "Remove Docker Desktop"
  if (Test-WingetPackage -Id 'Docker.DockerDesktop') {
    if (Confirm-Action "Uninstall Docker Desktop (containers & images lost)?") {
      Uninstall-WingetPackage -Id 'Docker.DockerDesktop' -Name 'Docker Desktop'
    } else { Write-Info "kept Docker Desktop" }
  } else { Write-Info "Docker Desktop not installed" }
}

# ---------------------------------------------------------------------------
# runtimes
# ---------------------------------------------------------------------------
function Undo-Runtimes {
  Write-Step "Remove language runtimes (mise node/python/go + rustup)"
  Update-SessionPath
  if (Test-HasCommand mise) {
    if (Confirm-Action "Remove mise-managed node/python/go/ast-grep (versions + global config)?") {
      if ($script:DryRun) {
        Write-Info "[dry-run] mise uninstall node python go; mise rm -g node python go ast-grep"
      } else {
        Invoke-NativeSilently 'mise' @('uninstall', 'node', 'python', 'go')
        foreach ($t in @('node','python','go','ubi:ast-grep/ast-grep')) { Invoke-NativeSilently 'mise' @('rm', '-g', $t) }
        Write-Ok "removed mise runtimes"
      }
    } else { Write-Info "kept mise runtimes" }
  }
  if (Test-HasCommand rustup) {
    if (Confirm-Action "Uninstall Rust (rustup self uninstall)?") {
      if ($script:DryRun) { Write-Info "[dry-run] rustup self uninstall -y" }
      else { & rustup self uninstall -y; Write-Ok "rust uninstalled" }
    } else { Write-Info "kept rust/rustup" }
  }
}

# ---------------------------------------------------------------------------
# packages
# ---------------------------------------------------------------------------
function Undo-Packages {
  Write-Step "Uninstall winget packages"
  if (-not (Confirm-Action "Uninstall the winget CLI/dev packages? (git & Nerd Font are kept)")) {
    Write-Info "kept winget packages"; return
  }
  $ids = [ordered]@{
    'GitHub.cli'              = 'gh'
    'jqlang.jq'               = 'jq'
    'BurntSushi.ripgrep.MSVC' = 'ripgrep'
    'sharkdp.fd'              = 'fd'
    'sharkdp.bat'             = 'bat'
    'junegunn.fzf'            = 'fzf'
    'Starship.Starship'      = 'starship'
    'jdx.mise'                = 'mise'
    'astral-sh.uv'            = 'uv'
    'Rustlang.Rustup'         = 'rustup'
    'Oven-sh.Bun'             = 'bun'
  }
  foreach ($id in $ids.Keys) { Uninstall-WingetPackage -Id $id -Name $ids[$id] }
  Write-Info "git and the Nerd Font are intentionally kept (remove manually if desired)."
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
$GroupFunc = @{
  wsl = 'Undo-Wsl'; agents = 'Undo-Agents'; shell = 'Undo-Shell'; docker = 'Undo-Docker'
  runtimes = 'Undo-Runtimes'; packages = 'Undo-Packages'
}

if ($List) { $GroupIds | ForEach-Object { Write-Output $_ }; exit 0 }

function Get-SelectedGroups {
  $onlyList = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  $skipList = @($Skip | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  foreach ($id in $GroupIds) {
    if ($onlyList.Count -gt 0) { if ($onlyList -contains $id) { $id } }
    elseif ($skipList -notcontains $id) { $id }
  }
}

# Validate every -Only/-Skip token against the known group ids -- a typo would
# otherwise silently select zero groups and exit 0.
foreach ($tok in (@(@($Only) + @($Skip)) | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
  if ($GroupIds -notcontains $tok) { Stop-Kit "unknown step id: '$tok' (valid: $($GroupIds -join ' '))" }
}

if (-not (Test-IsWindows)) { Stop-Kit "Windows only." }
if ($script:DryRun) { Write-Warn "DRY-RUN: no changes will be made." }

Write-Host "== lazy-starter-kit v$KitVersion - uninstall ==" -ForegroundColor White
$selected = @(Get-SelectedGroups)
Write-Info ("groups: " + ($selected -join ' '))
Write-Warn "Your git identity is left untouched (remove manually if desired)."

foreach ($id in $selected) { & $GroupFunc[$id] }

Write-Step "Uninstall complete."
Write-Ok "Restart PowerShell to load a clean environment."
if ($script:DryRun) { Write-Info "That was a dry run -- re-run without -DryRun to apply." }
exit 0
