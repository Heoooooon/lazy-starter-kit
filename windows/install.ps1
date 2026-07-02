#requires -Version 5.1
<#
.SYNOPSIS
  lazy-starter-kit -- install a complete Windows dev environment from scratch.

.DESCRIPTION
  From a fresh machine -> winget packages, runtimes, PowerShell profile, Docker,
  and AI coding agents (gajae-code + codex + lazycodex).

  Steps (in order): prereqs packages runtimes shell docker git agents

.PARAMETER DryRun
  Show what would happen, change nothing.
.PARAMETER Yes
  Non-interactive: accept defaults, never prompt.
.PARAMETER Only
  Comma-separated list of steps to run (e.g. -Only packages,shell).
.PARAMETER Skip
  Comma-separated list of steps to skip.
.PARAMETER NoAgents
  Shortcut for -Skip agents.
.PARAMETER List
  List step ids and exit.
.PARAMETER Version
  Print the kit version and exit.

.EXAMPLE
  irm https://raw.githubusercontent.com/Heoooooon/lazy-starter-kit/main/windows/install.ps1 | iex

.EXAMPLE
  .\install.ps1 -DryRun
#>
[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$Yes,
  [string[]]$Only = @(),
  [string[]]$Skip = @(),
  [switch]$NoAgents,
  [switch]$List,
  [switch]$Version,
  [switch]$Help
)

$ErrorActionPreference = 'Stop'

# Are we running from a real .ps1 file, or piped through `iex` (irm | iex)? When
# iex'd the script shares the caller's session scope, so `exit` closes the user's
# terminal -- wiping the "Next steps" output on success and the error on failure.
# We `return`/`throw` instead in that mode, and keep exit codes for real file runs
# (CI relies on them). $PSCommandPath is the running file's path, empty under iex.
$script:RunFromFile = [bool]$PSCommandPath

$HomeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$RepoUrl    = if ($env:STARTER_KIT_REPO)   { $env:STARTER_KIT_REPO }   else { 'https://github.com/Heoooooon/lazy-starter-kit.git' }
$RepoBranch = if ($env:STARTER_KIT_BRANCH) { $env:STARTER_KIT_BRANCH } else { 'main' }
$CloneDir   = if ($env:STARTER_KIT_DIR)    { $env:STARTER_KIT_DIR }    else { Join-Path $HomeDir '.lazy-starter-kit' }

# ---------------------------------------------------------------------------
# Resolve the repo root (the windows\ dir), or bootstrap by cloning.
# ---------------------------------------------------------------------------
function Resolve-Root {
  $dir = $PSScriptRoot
  if (-not $dir) { try { $dir = Split-Path -Parent $MyInvocation.MyCommand.Path } catch {} }
  if ($dir -and (Test-Path (Join-Path $dir 'scripts\lib.ps1'))) { return $dir }

  Write-Host "==> Bootstrapping lazy-starter-kit into $CloneDir" -ForegroundColor Blue
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    # A piped one-liner (irm | iex) needs git to clone the kit. On a fresh
    # machine, install it via winget, then refresh PATH for this session.
    if (Get-Command winget -ErrorAction SilentlyContinue) {
      Write-Host "==> git not found - installing via winget..." -ForegroundColor Blue
      winget install --id Git.Git -e --accept-package-agreements --accept-source-agreements --silent --disable-interactivity
      $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' +
                  [Environment]::GetEnvironmentVariable('Path','User') + ';C:\Program Files\Git\cmd'
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
      Write-Host "==> git still not found. Either:" -ForegroundColor Red
      Write-Host "    1) install git:  winget install --id Git.Git   (then re-run), or" -ForegroundColor Red
      Write-Host "    2) download the ZIP: https://github.com/Heoooooon/lazy-starter-kit/archive/refs/heads/main.zip" -ForegroundColor Red
      Write-Host "       extract it, then run  windows\install.ps1" -ForegroundColor Red
      if ($script:RunFromFile) { exit 1 } else { throw "git is required -- install it and re-run (see options above)." }
    }
  }
  if (Test-Path (Join-Path $CloneDir '.git')) {
    git -C $CloneDir pull --ff-only origin $RepoBranch | Out-Null
  } else {
    git clone --branch $RepoBranch --depth 1 $RepoUrl $CloneDir | Out-Null
  }
  return (Join-Path $CloneDir 'windows')
}

$Root = Resolve-Root

# If we bootstrapped (cloned), hand off to the cloned copy with the same args.
$self = $null
try { $self = $MyInvocation.MyCommand.Path } catch {}
$target = Join-Path $Root 'install.ps1'
if ((-not $self) -or ($self -ne $target)) {
  if (Test-Path $target) {
    & $target @PSBoundParameters
    # Propagate the cloned copy's exit code when we're a file; under iex, `return`
    # so we don't close the caller's terminal.
    if ($script:RunFromFile) { exit $LASTEXITCODE } else { return }
  }
}

# ---------------------------------------------------------------------------
# Load shared helpers + set flags
# ---------------------------------------------------------------------------
. (Join-Path $Root 'scripts\lib.ps1')
$script:DryRun    = [bool]$DryRun
$script:AssumeYes = [bool]$Yes

$versionFile = Join-Path $Root '..\VERSION'
$KitVersion = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { 'dev' }

# ---------------------------------------------------------------------------
# Step registry
# ---------------------------------------------------------------------------
$StepIds = @('prereqs', 'packages', 'runtimes', 'shell', 'docker', 'git', 'agents')
$StepFile = @{
  prereqs  = '01-prereqs.ps1'
  packages = '02-packages.ps1'
  runtimes = '03-runtimes.ps1'
  shell    = '04-shell.ps1'
  docker   = '05-docker.ps1'
  git      = '06-git.ps1'
  agents   = '07-agents.ps1'
}
$StepFunc = @{
  prereqs  = 'Step-Prereqs'
  packages = 'Step-Packages'
  runtimes = 'Step-Runtimes'
  shell    = 'Step-Shell'
  docker   = 'Step-Docker'
  git      = 'Step-Git'
  agents   = 'Step-Agents'
}

if ($Help)    { Get-Help $target -Detailed;                    if ($script:RunFromFile) { exit 0 } else { return } }
if ($List)    { $StepIds | ForEach-Object { Write-Output $_ }; if ($script:RunFromFile) { exit 0 } else { return } }
if ($Version) { Write-Output "lazy-starter-kit $KitVersion";    if ($script:RunFromFile) { exit 0 } else { return } }

if ($NoAgents) { $Skip = @($Skip) + 'agents' }

# Validate every -Only/-Skip token against the known step ids -- a typo like
# `-Only pacakges` would otherwise silently select zero steps and exit 0.
foreach ($tok in (@(@($Only) + @($Skip)) | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
  if ($StepIds -notcontains $tok) { Stop-Kit "unknown step id: '$tok' (valid: $($StepIds -join ' '))" }
}

function Get-SelectedSteps {
  $onlyList = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  $skipList = @($Skip | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  foreach ($id in $StepIds) {
    if ($onlyList.Count -gt 0) {
      if ($onlyList -contains $id) { $id }
    } elseif ($skipList -notcontains $id) {
      $id
    }
  }
}

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
if (-not (Test-IsWindows)) { Stop-Kit "This kit targets Windows only." }
if ($script:DryRun) { Write-Warn "DRY-RUN: no changes will be made." }

Write-Host "== lazy-starter-kit v$KitVersion ==" -ForegroundColor White
$selected = @(Get-SelectedSteps)
Write-Info ("steps: " + ($selected -join ' '))

# ---------------------------------------------------------------------------
# Execute
# ---------------------------------------------------------------------------
foreach ($id in $selected) {
  $file = Join-Path $Root ("scripts\" + $StepFile[$id])
  if (-not (Test-Path $file)) { Stop-Kit "missing step file: $file" }
  . $file
  & $StepFunc[$id]
}

Write-Step "Done."
if ($script:DryRun) {
  Write-Info "That was a dry run -- re-run without -DryRun to apply."
} else {
  Write-Step "Next steps"
  Write-Info "1) Open a NEW PowerShell window so the profile loads (autosuggestions, prompt)."
  if ((Test-HasCommand gh)) {
    Invoke-NativeSilently 'gh' @('auth', 'status') | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Info "2) Sign in to GitHub:  gh auth login   (also sets your git identity)" }
  }
  Write-Info "3) Set your terminal font to 'JetBrainsMono Nerd Font' (Windows Terminal > Settings > Appearance)."
  Write-Info "Note: on Windows PowerShell 5.1, restart it once if PSReadLine was upgraded. PowerShell 7 is smoother."
}
if ($script:RunFromFile) { exit 0 } else { return }
