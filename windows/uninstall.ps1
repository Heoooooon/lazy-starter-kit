#requires -Version 5.1
<#
.SYNOPSIS
  lazy-starter-kit -- uninstaller. Reverses install.ps1 in reverse order.

.DESCRIPTION
  Destructive groups are confirm-gated. Never auto-removes your git identity.
  gajae-code (gjc) is kept unless you pass -WithGajae.

  Groups (reverse order): agents shell docker runtimes packages

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
  [string]$Only = '',
  [string]$Skip = '',
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

$GroupIds = @('agents', 'shell', 'docker', 'runtimes', 'packages')

# ---------------------------------------------------------------------------
# agents
# ---------------------------------------------------------------------------
function Undo-Agents {
  Write-Step "Remove AI agents (codex + lazycodex)"
  Update-SessionPath

  if (Test-HasCommand mise) {
    $installed = (& mise exec -- npm ls -g --depth=0 2>$null | Out-String)
    if ($installed -match '@openai/codex') {
      Write-Info "Uninstalling @openai/codex..."
      if (-not $script:DryRun) { & mise exec -- npm uninstall -g '@openai/codex'; & mise reshim 2>$null }
      else { Write-Info "[dry-run] mise exec -- npm uninstall -g @openai/codex" }
    } else { Write-Info "codex npm package not installed" }
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
        if (-not $script:DryRun) { Remove-Item $dir.FullName -Recurse -Force -ErrorAction SilentlyContinue }
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
        if (-not $script:DryRun) { Copy-Item $auth $bak; Write-Ok "backed up auth.json -> $bak" }
      }
      if (-not $script:DryRun) { Remove-Item $codexHome -Recurse -Force -ErrorAction SilentlyContinue }
    } else { Write-Info "kept ~/.codex" }
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
  Remove-ManagedBlock -Path $PROFILE.CurrentUserAllHosts -Tag 'lazy-starter-kit:main'

  $starshipToml = Join-Path $env:USERPROFILE '.config\starship.toml'
  if (Test-Path $starshipToml) {
    if (Confirm-Action "Remove ~/.config/starship.toml?") {
      if (-not $script:DryRun) { Remove-Item $starshipToml -Force }
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
        & mise uninstall node python go 2>$null
        foreach ($t in @('node','python','go','ubi:ast-grep/ast-grep')) { & mise rm -g $t 2>$null }
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
  agents = 'Undo-Agents'; shell = 'Undo-Shell'; docker = 'Undo-Docker'
  runtimes = 'Undo-Runtimes'; packages = 'Undo-Packages'
}

if ($List) { $GroupIds | ForEach-Object { Write-Output $_ }; exit 0 }

function Get-SelectedGroups {
  $onlyList = @($Only -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  $skipList = @($Skip -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  foreach ($id in $GroupIds) {
    if ($onlyList.Count -gt 0) { if ($onlyList -contains $id) { $id } }
    elseif ($skipList -notcontains $id) { $id }
  }
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
