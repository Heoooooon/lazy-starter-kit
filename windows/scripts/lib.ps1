# lib.ps1 -- shared helpers for lazy-starter-kit
# dot-sourced by install.ps1 and every scripts/NN-*.ps1 step.
# Targets Windows PowerShell 5.1+ and PowerShell 7+.

Set-StrictMode -Version Latest

# ---------------------------------------------------------------------------
# Global flags (set by install.ps1)
# ---------------------------------------------------------------------------
if (-not (Test-Path variable:script:DryRun))    { $script:DryRun = $false }
if (-not (Test-Path variable:script:AssumeYes)) { $script:AssumeYes = $false }
# $true when the top-level script runs from a real .ps1 file; $false when it was
# piped through `iex` (irm | iex), where `exit` would close the user's terminal.
# install.ps1 sets this before dot-sourcing us; default $true is right for a file
# run and for the uninstaller.
if (-not (Test-Path variable:script:RunFromFile)) { $script:RunFromFile = $true }

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
function Write-Step { param([string]$Message) Write-Host ""; Write-Host "==> $Message" -ForegroundColor Blue }
function Write-Info { param([string]$Message) Write-Host "  - $Message" -ForegroundColor DarkGray }
function Write-Ok   { param([string]$Message) Write-Host "  ok  $Message" -ForegroundColor Green }
function Write-Warn { param([string]$Message) Write-Warning $Message }
function Write-Err  { param([string]$Message) Write-Host "  x   $Message" -ForegroundColor Red }
function Stop-Kit {
  # Fail the run. Under `irm | iex` (not a file) `exit 1` would close the user's
  # terminal and take the error text with it, so throw a terminating error whose
  # message survives instead; keep the exit code intact for real file runs (CI).
  param([string]$Message)
  Write-Err $Message
  if ($script:RunFromFile) { exit 1 } else { throw $Message }
}

# Tracks winget packages that failed to install, for an end-of-step summary.
if (-not (Test-Path variable:script:WingetFailures)) { $script:WingetFailures = @() }

# ---------------------------------------------------------------------------
# Predicates
# ---------------------------------------------------------------------------
function Test-HasCommand {
  param([Parameter(Mandatory)][string]$Name)
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Test-IsWindows {
  # $IsWindows exists on PS 7; on 5.1 it's undefined but the host is Windows.
  if (Test-Path variable:global:IsWindows) { return $global:IsWindows }
  return ($env:OS -eq 'Windows_NT')
}

function Test-IsAdmin {
  try {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } catch { return $false }
}

# ---------------------------------------------------------------------------
# Command execution -- run, or just print under -DryRun
# ---------------------------------------------------------------------------
function Invoke-Run {
  param(
    [Parameter(Mandatory)][string]$Exe,
    [string[]]$Arguments = @()
  )
  if ($script:DryRun) {
    Write-Host ("  [dry-run] {0} {1}" -f $Exe, ($Arguments -join ' ')) -ForegroundColor DarkGray
    return $true
  }
  & $Exe @Arguments
  return ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE)
}

# ---------------------------------------------------------------------------
# Native-command invocation with stderr discarded.
# On Windows PowerShell 5.1 a native command's stderr lines become ErrorRecords,
# and $ErrorActionPreference='Stop' (which install.ps1 sets) promotes the first
# one into a TERMINATING error -- so a plain `git config ... 2>$null` kills the
# script the moment the tool writes to stderr (e.g. gh when unauthenticated).
# Fixed only in PS 7.2+. We flip EAP to 'Continue' for the call so stderr is
# harmless, discard it with 2>$null, and return stdout. $LASTEXITCODE is left
# set by the native command for the caller to inspect.
# ---------------------------------------------------------------------------
function Invoke-NativeSilently {
  param(
    [Parameter(Mandatory)][string]$Exe,
    [string[]]$Arguments = @()
  )
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    # Buffer the full output BEFORE returning it. Streaming it out directly lets
    # a caller's `| Select-Object -First 1` stop the pipeline early, which kills
    # the still-running native process and leaves $LASTEXITCODE at -1 -- the
    # doctor's `mise which` runtime checks lost that race every time and
    # misreported installed runtimes as missing. With the output collected here,
    # the process always runs to completion and $LASTEXITCODE is its real exit
    # code.
    $out = & $Exe @Arguments 2>$null
    if ($null -ne $out) { $out }
  } finally {
    $ErrorActionPreference = $prev
  }
}

# ---------------------------------------------------------------------------
# Prompts
# ---------------------------------------------------------------------------
function Read-Default {
  param([string]$Question, [string]$Default = '')
  if ($script:AssumeYes -or [Console]::IsInputRedirected) { return $Default }
  $ans = Read-Host $Question
  if ([string]::IsNullOrWhiteSpace($ans)) { return $Default }
  return $ans
}

function Confirm-Action {
  # -DefaultNo flips the gate to default-No: bare Enter declines, the prompt reads
  # [y/N], and -Yes / non-interactive returns $false (used for the licensing-gated
  # Docker Desktop install). Without it, behaviour is unchanged (default-Yes).
  param([string]$Question, [switch]$DefaultNo)
  if ($script:AssumeYes) { return (-not $DefaultNo) }
  if ([Console]::IsInputRedirected) { return $false }
  if ($DefaultNo) {
    $ans = Read-Host ("{0} [y/N]" -f $Question)
    return ($ans -match '^[Yy]')
  }
  $ans = Read-Host ("{0} [Y/n]" -f $Question)
  return ([string]::IsNullOrWhiteSpace($ans) -or $ans -match '^[Yy]')
}

# ---------------------------------------------------------------------------
# PATH refresh -- winget-installed tools land on the Machine/User PATH but the
# current process won't see them until we re-read the environment.
# ---------------------------------------------------------------------------
function Update-SessionPath {
  # MERGE newly-installed tool dirs into the CURRENT process PATH -- do NOT rebuild
  # from Machine+User only. A rebuild drops process-level entries (VS dev shell,
  # portable git, dirs the profile prepended) and, with $ErrorActionPreference=
  # 'Stop', a later CommandNotFoundException would abort the whole run. We keep the
  # existing $env:Path entries in their original order and append Machine/User and
  # the known tool dirs that aren't already present (case-insensitive, and
  # trailing-backslash-insensitive so 'C:\x' and 'C:\x\' count as the same entry).
  $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  $user    = [Environment]::GetEnvironmentVariable('Path', 'User')

  $extra = @()
  foreach ($p in @($machine, $user)) { if ($p) { $extra += ($p -split ';') } }
  # user-local tool dirs (guard each base env var; may be unset off-Windows)
  if ($env:USERPROFILE) {
    $extra += (Join-Path $env:USERPROFILE '.cargo\bin')
    $extra += (Join-Path $env:USERPROFILE '.bun\bin')
    # Claude Code (claude.exe) installs here via https://claude.ai/install.ps1
    $extra += (Join-Path $env:USERPROFILE '.local\bin')
  }
  if ($env:LOCALAPPDATA) { $extra += (Join-Path $env:LOCALAPPDATA 'mise\shims') }
  if ($env:APPDATA)      { $extra += (Join-Path $env:APPDATA 'npm') }

  $seen   = @{}
  $merged = @()
  foreach ($p in @(($env:Path -split ';') + $extra)) {
    if ([string]::IsNullOrWhiteSpace($p)) { continue }
    $norm = $p.TrimEnd('\').ToLowerInvariant()
    if ($seen.ContainsKey($norm)) { continue }
    $seen[$norm] = $true
    $merged += $p
  }
  if ($merged.Count -gt 0) { $env:Path = ($merged -join ';') }
}

# ---------------------------------------------------------------------------
# CurrentUserAllHosts profile.ps1 paths for BOTH Windows PowerShell 5.1 and
# PowerShell 7. $PROFILE.CurrentUserAllHosts is HOST-specific (5.1 ->
# WindowsPowerShell\profile.ps1, 7 -> PowerShell\profile.ps1), so installing
# from one host leaves the other with no prompt/PSReadLine/mise. The README
# recommends switching to PS7 after installing, so we write both. Documents is
# derived from MyDocuments (never hardcoded ~\Documents -- OneDrive redirects it).
# ---------------------------------------------------------------------------
function Get-AllHostsProfilePaths {
  $docs = [Environment]::GetFolderPath('MyDocuments')
  if ([string]::IsNullOrWhiteSpace($docs)) {
    if ($env:USERPROFILE) { $docs = Join-Path $env:USERPROFILE 'Documents' } else { $docs = $HOME }
  }
  return @(
    (Join-Path $docs 'WindowsPowerShell\profile.ps1'),
    (Join-Path $docs 'PowerShell\profile.ps1')
  )
}

# ---------------------------------------------------------------------------
# winget helpers
# ---------------------------------------------------------------------------
function Test-WingetPackage {
  param([Parameter(Mandatory)][string]$Id)
  # Confirm BOTH the exit code AND that the id actually appears in the output:
  # some winget versions exit 0 even when nothing matched, so the match guards it.
  $match = Invoke-NativeSilently 'winget' @('list', '--id', $Id, '-e', '--accept-source-agreements') | Out-String -Stream | Select-String -SimpleMatch $Id
  return (($LASTEXITCODE -eq 0) -and [bool]$match)
}

# Install-WingetPackage <Id> [<Friendly name>]  -- idempotent winget install
function Install-WingetPackage {
  param(
    [Parameter(Mandatory)][string]$Id,
    [string]$Name = $null
  )
  if (-not $Name) { $Name = $Id }
  if (-not $script:DryRun -and (Test-WingetPackage -Id $Id)) {
    Write-Ok "$Name present"
    return
  }
  Write-Info "Installing $Name (winget: $Id)..."
  $wingetArgs = @('install', '--id', $Id, '-e', '--accept-package-agreements',
                  '--accept-source-agreements', '--silent',
                  '--disable-interactivity')
  if ($script:DryRun) {
    Write-Host ("  [dry-run] winget {0} [--scope user, then default]" -f ($wingetArgs -join ' ')) -ForegroundColor DarkGray
    return
  }
  # Prefer a per-user install (no admin/UAC). If the package has no user-scope
  # installer, retry at default scope (which may prompt for elevation).
  winget @wingetArgs --scope user
  if ($LASTEXITCODE -ne 0) { winget @wingetArgs }
  if ($LASTEXITCODE -ne 0) {
    Write-Warn "winget install for $Name exited with code $LASTEXITCODE (may need admin/UAC, a reboot, or be unavailable here)"
    $script:WingetFailures += $Name
  } else {
    Write-Ok "$Name installed"
  }
}

# Uninstall-WingetPackage <Id> [<Friendly name>]  -- used by the uninstaller
function Uninstall-WingetPackage {
  param([Parameter(Mandatory)][string]$Id, [string]$Name = $null)
  if (-not $Name) { $Name = $Id }
  if (-not $script:DryRun -and -not (Test-WingetPackage -Id $Id)) {
    Write-Info "$Name not installed"
    return
  }
  if ($script:DryRun) {
    Write-Host ("  [dry-run] winget uninstall --id {0} -e --silent" -f $Id) -ForegroundColor DarkGray
    return
  }
  winget uninstall --id $Id -e --silent --disable-interactivity
  if ($LASTEXITCODE -eq 0) {
    Write-Ok "$Name removed"
  } else {
    Write-Warn "could not remove $Name (winget exit $LASTEXITCODE) -- likely needs admin/UAC, or it isn't installed"
  }
}

# ---------------------------------------------------------------------------
# File-encoding detection for in-place profile edits.
# WinPS 5.1 parses a BOM-less profile.ps1 as the system ANSI codepage, so writing
# it back UTF-8-without-BOM (the .NET default) corrupts Korean comments into
# mojibake / syntax errors. We preserve the file's existing encoding: honour a
# UTF-8/UTF-16 BOM; for a BOM-less file assume ANSI on 5.1 and UTF-8 on PS7. A
# brand-new (or empty) file gets UTF-8 WITH BOM, which is safe on both.
# ---------------------------------------------------------------------------
function Get-ProfileEncoding {
  param([Parameter(Mandatory)][string]$Path)

  # New or empty file -> UTF-8 with BOM (unambiguous for 5.1 and 7).
  if (-not (Test-Path $Path) -or ((Get-Item $Path).Length -eq 0)) {
    return (New-Object System.Text.UTF8Encoding($true))
  }

  # Fallback used only when the file has no BOM.
  if ($PSVersionTable.PSVersion.Major -ge 6) {
    $fallback = New-Object System.Text.UTF8Encoding($false)  # PS7 default: UTF-8, no BOM
  } else {
    $fallback = [System.Text.Encoding]::Default              # WinPS 5.1: system ANSI codepage
  }

  # StreamReader detects a BOM and reports it via CurrentEncoding; with no BOM it
  # keeps our fallback. Read once so detection actually runs.
  $reader = New-Object System.IO.StreamReader($Path, $fallback, $true)
  try {
    $null = $reader.ReadToEnd()
    return $reader.CurrentEncoding
  } finally {
    $reader.Dispose()
  }
}

# ---------------------------------------------------------------------------
# Managed-block injection -- idempotent insert/replace between markers
# Update-ManagedBlock -Path <file> -Tag <tag> -Content <string>
# Re-running replaces the block; never duplicates.
# ---------------------------------------------------------------------------
function Update-ManagedBlock {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Tag,
    [Parameter(Mandatory)][string]$Content
  )
  $begin = "# >>> $Tag >>>"
  $end   = "# <<< $Tag <<<"
  $short = $Path.Replace($env:USERPROFILE, '~')

  # Preserve the existing file's encoding (or UTF-8 BOM for a new file) so we
  # don't corrupt a profile with Korean comments on WinPS 5.1.
  $enc = Get-ProfileEncoding $Path

  # Refuse to touch a file whose markers are unbalanced (crashed run / hand-edit):
  # rewriting would drop everything between the lone marker and EOF -- the user's
  # own config. Mirrors inject_block in the bash kits.
  if (Test-Path $Path) {
    $existing = [System.IO.File]::ReadAllLines($Path, $enc)
    $hasBegin = $existing -contains $begin
    $hasEnd   = $existing -contains $end
    if ($hasBegin -ne $hasEnd) {
      Write-Warn "$short has an unmatched lazy-starter-kit '$Tag' marker; refusing to modify it. Fix or delete the stray marker line by hand."
      return
    }
  }

  if ($script:DryRun) {
    if ((Test-Path $Path) -and (Select-String -Path $Path -SimpleMatch $begin -Quiet)) {
      Write-Info "[dry-run] would update '$Tag' block in $short"
    } else {
      Write-Info "[dry-run] would add '$Tag' block to $short"
    }
    return
  }

  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

  # one-time safety backup before the first rewrite of a non-empty user file
  $bak = "$Path.lazy-starter-kit.bak"
  if ((Test-Path $Path) -and ((Get-Item $Path).Length -gt 0) -and -not (Test-Path $bak)) {
    Copy-Item $Path $bak
    Write-Info "backed up $short -> $($bak.Replace($env:USERPROFILE, '~')) (first change)"
  }

  $lines = @()
  if (Test-Path $Path) {
    $skip = $false
    foreach ($line in [System.IO.File]::ReadAllLines($Path, $enc)) {
      if ($line -eq $begin) { $skip = $true; continue }
      if ($skip -and $line -eq $end) { $skip = $false; continue }
      if (-not $skip) { $lines += $line }
    }
  }
  $lines += $begin
  foreach ($l in ($Content -split "`r?`n")) { $lines += $l }
  $lines += $end

  [System.IO.File]::WriteAllLines($Path, $lines, $enc)
  Write-Ok "wrote '$Tag' block -> $short"
}

# Remove-ManagedBlock -Path <file> -Tag <tag>  -- delete a managed block. Idempotent.
function Remove-ManagedBlock {
  param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Tag)
  $begin = "# >>> $Tag >>>"
  $end   = "# <<< $Tag <<<"
  $short = $Path.Replace($env:USERPROFILE, '~')
  if (-not (Test-Path $Path)) { Write-Info "no $short (skip '$Tag')"; return }

  # Preserve the file's existing encoding on read and write-back (see Get-ProfileEncoding).
  $enc = Get-ProfileEncoding $Path

  # Refuse on unbalanced markers (see Update-ManagedBlock): a lone begin marker
  # would make the skip loop drop the user's own config below it.
  $existing = [System.IO.File]::ReadAllLines($Path, $enc)
  $hasBegin = $existing -contains $begin
  $hasEnd   = $existing -contains $end
  if ($hasBegin -ne $hasEnd) {
    Write-Warn "$short has an unmatched lazy-starter-kit '$Tag' marker; refusing to modify it. Fix or delete the stray marker line by hand."
    return
  }
  if (-not $hasBegin) { Write-Info "no '$Tag' block in $short"; return }

  if ($script:DryRun) { Write-Info "[dry-run] would remove '$Tag' block from $short"; return }

  # one-time safety backup before the first rewrite of a non-empty user file
  $bak = "$Path.lazy-starter-kit.bak"
  if (((Get-Item $Path).Length -gt 0) -and -not (Test-Path $bak)) {
    Copy-Item $Path $bak
    Write-Info "backed up $short -> $($bak.Replace($env:USERPROFILE, '~')) (first change)"
  }

  $lines = @()
  $skip = $false
  foreach ($line in $existing) {
    if ($line -eq $begin) { $skip = $true; continue }
    if ($skip -and $line -eq $end) { $skip = $false; continue }
    if (-not $skip) { $lines += $line }
  }
  [System.IO.File]::WriteAllLines($Path, $lines, $enc)
  Write-Ok "removed '$Tag' block from $short"
}
