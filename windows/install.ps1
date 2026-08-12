#requires -Version 5.1
<#
.SYNOPSIS
  lazy-starter-kit -- install a complete Windows dev environment from scratch.

.DESCRIPTION
  From a fresh machine -> winget packages, runtimes, PowerShell profile, Docker,
  and AI coding agents (gajae-code + codex + lazycodex).

  Steps (in order): prereqs packages runtimes shell docker git agents wsl

.PARAMETER DryRun
  Show what would happen, change nothing.
.PARAMETER Yes
  Non-interactive: accept defaults, never prompt.
.PARAMETER Profile
  Preset step selection (full|minimal|work):
    full     everything (same as no switch).
    minimal  prereqs packages runtimes shell git (skips docker, agents, wsl).
    work     everything except docker and wsl.
  Implemented as a preset skip-set UNIONed with -Skip. Mutually exclusive with
  -Only.
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
.PARAMETER Doctor
  Diagnose the current setup (tools, runtimes, profile/starship config) and exit.
  Changes nothing; exits 1 if anything is missing, else 0.
.PARAMETER Update
  Update the kit checkout, then continue the install with the remaining
  switches (e.g. -Update -Only agents). Branch checkouts fast-forward; detached
  release checkouts move to the newest release tag. Requires a git checkout.

.EXAMPLE
  irm https://raw.githubusercontent.com/Heoooooon/lazy-starter-kit/main/windows/install.ps1 | iex

.EXAMPLE
  .\install.ps1 -DryRun

.EXAMPLE
  .\install.ps1 -Doctor

.EXAMPLE
  .\install.ps1 -Update -Only agents
#>
[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$Yes,
  # Validation is intentionally manual (not [ValidateSet]) so an unknown name
  # gets the same friendly "valid: ..." message as an unknown step id, rather
  # than PowerShell's raw binding error.
  [string]$Profile,
  [string[]]$Only = @(),
  [string[]]$Skip = @(),
  [switch]$NoAgents,
  [switch]$List,
  [switch]$Version,
  [switch]$Doctor,
  [switch]$Update,
  [switch]$Help
)

$ErrorActionPreference = 'Stop'

# Are we running from a real .ps1 file, or piped through `iex` (irm | iex)? When
# iex'd the script shares the caller's session scope, so `exit` closes the user's
# terminal -- wiping the "Next steps" output on success and the error on failure.
# We `return`/`throw` instead in that mode, and keep exit codes for real file runs
# (CI relies on them). $PSCommandPath is the running file's path, empty under iex.
$script:RunFromFile =
  [bool]$PSCommandPath -and $env:STARTER_KIT_HANDOFF_CHILD -ne '1'

$HomeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$RepoUrl    = if ($env:STARTER_KIT_REPO)   { $env:STARTER_KIT_REPO }   else { 'https://github.com/Heoooooon/lazy-starter-kit.git' }
# STARTER_KIT_BRANCH pins an explicit ref (a tag like v0.9.0, or 'main' to ride
# the development branch). Left unset, the bootstrap resolves the newest release
# tag instead of main -- a fresh machine should get a ref CI actually verified
# end-to-end, not whatever landed on main minutes ago.
$RepoBranch = if ($env:STARTER_KIT_BRANCH) { $env:STARTER_KIT_BRANCH } else { $null }
$RepoCommit = if ($env:STARTER_KIT_COMMIT) { $env:STARTER_KIT_COMMIT } else { $null }
$CloneDir   = if ($env:STARTER_KIT_DIR)    { $env:STARTER_KIT_DIR }    else { Join-Path $HomeDir '.lazy-starter-kit' }
$EphemeralRoot = if ($env:STARTER_KIT_EPHEMERAL_ROOT) {
  $env:STARTER_KIT_EPHEMERAL_ROOT
} else {
  $null
}
if ($RepoCommit -and $RepoCommit -notmatch '^[0-9a-f]{40}$') {
  throw 'STARTER_KIT_COMMIT must be a full 40-character commit SHA.'
}

# ---------------------------------------------------------------------------
# Resolve the repo root (the windows\ dir), or bootstrap by cloning.
# ---------------------------------------------------------------------------
function Resolve-Root {
  $dir = $PSScriptRoot
  if (-not $dir) { try { $dir = Split-Path -Parent $MyInvocation.MyCommand.Path } catch {} }
  if ($dir -and (Test-Path (Join-Path $dir 'scripts\lib.ps1'))) { return $dir }

  Write-Host "==> Bootstrapping lazy-starter-kit into $CloneDir" -ForegroundColor Blue
  if ($EphemeralRoot) {
    if ($EphemeralRoot -ne $CloneDir) {
      throw 'STARTER_KIT_EPHEMERAL_ROOT must match STARTER_KIT_DIR.'
    }
    if (Test-Path -LiteralPath $CloneDir) {
      throw 'Ephemeral checkout path already exists; refusing to trust it.'
    }
  }
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
  if (-not $RepoBranch) { $script:RepoBranch = Get-KitLatestRef }
  Write-Host "==> Using $RepoBranch" -ForegroundColor Blue
  if (Test-Path (Join-Path $CloneDir '.git')) {
    $dirty = @(git -C $CloneDir status --porcelain --untracked-files=normal)
    if ($LASTEXITCODE -ne 0) {
      throw "Could not inspect existing checkout: $CloneDir"
    }
    if ($dirty.Count -gt 0) {
      throw "Existing checkout has local changes; refusing to run: $CloneDir"
    }
    git -C $CloneDir fetch --force --depth 1 origin $RepoBranch | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "Could not fetch $RepoBranch; refusing to use a stale checkout."
    }
    $fetchedCommit = (git -C $CloneDir rev-parse 'FETCH_HEAD^{commit}' | Select-Object -First 1).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $fetchedCommit) {
      throw "Could not resolve fetched commit for $RepoBranch."
    }
    if ($RepoCommit -and $fetchedCommit -ne $RepoCommit) {
      throw "Fetched commit $fetchedCommit does not match pinned commit $RepoCommit."
    }
    git -C $CloneDir checkout --quiet --detach $fetchedCommit | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "Could not check out verified commit $fetchedCommit."
    }
  } else {
    # -c advice.detachedHead=false: tag checkouts are detached by design;
    # the 15-line git lecture only alarms first-time users.
    git clone -c advice.detachedHead=false --branch $RepoBranch --depth 1 $RepoUrl $CloneDir | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Could not clone $RepoUrl at $RepoBranch." }
  }
  $resolvedCommit = (git -C $CloneDir rev-parse 'HEAD^{commit}' | Select-Object -First 1).Trim()
  if ($LASTEXITCODE -ne 0 -or -not $resolvedCommit) {
    throw "Could not resolve checkout commit in $CloneDir."
  }
  if ($RepoCommit -and $resolvedCommit -ne $RepoCommit) {
    throw "Checkout commit $resolvedCommit does not match pinned commit $RepoCommit."
  }
  return (Join-Path $CloneDir 'windows')
}

# Get-KitLatestRef -- newest vX.Y.Z tag on the remote; 'main' when a repo has no
# release tags yet (forks, first-ever run before v0.1.0).
function Get-KitLatestRef {
  try {
    $line = (git ls-remote --tags --refs --sort=-v:refname $RepoUrl 'v*' 2>$null | Select-Object -First 1)
    if ($line -and $line -match 'refs/tags/(.+)$') { return $Matches[1] }
  } catch {}
  return 'main'
}

$Root = Resolve-Root

# If we bootstrapped (cloned), hand off to the cloned copy with the same args.
$self = $null
try { $self = $MyInvocation.MyCommand.Path } catch {}
$target = Join-Path $Root 'install.ps1'
if ((-not $self) -or ($self -ne $target)) {
  if (Test-Path $target) {
    if ($script:RunFromFile) {
      if ($EphemeralRoot) {
        $handoffError = $null
        $handoffExit = 0
        $env:STARTER_KIT_HANDOFF_CHILD = '1'
        try {
          $global:LASTEXITCODE = 0
          & $target @PSBoundParameters
          if ($null -ne $LASTEXITCODE) {
            $handoffExit = [int]$LASTEXITCODE
          }
        } catch {
          $handoffError = $_
        } finally {
          Remove-Item Env:STARTER_KIT_HANDOFF_CHILD -ErrorAction SilentlyContinue
          . (Join-Path $Root 'scripts\lib.ps1')
          Remove-KitTree `
            -AllowedRoot (Split-Path -Parent $EphemeralRoot) `
            -Path $EphemeralRoot
        }
        if ($handoffError) { throw $handoffError }
        exit $handoffExit
      }
      & $target @PSBoundParameters
      exit $LASTEXITCODE
    }
    # Under iex, `& $target` runs a .ps1 FILE -- which a fresh machine's default
    # execution policy (Restricted) blocks with a PSSecurityException, even though
    # the iex'd STRING itself was exempt. Hand off in a child process with a
    # process-scoped policy bypass instead (GPO machine/user policy still wins).
    # The console is inherited, so prompts keep working; `return` (not exit) so we
    # don't close the caller's terminal.
    $psExe = (Get-Process -Id $PID).Path
    & $psExe -NoProfile -ExecutionPolicy Bypass -File $target
    return
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
# -Update: pull the latest kit, then re-run the UPDATED installer with the
# remaining switches. $Root is the windows\ subdir, so the git checkout root is
# its parent (mirrors Resolve-Root, which returns the windows\ dir). We handle
# this before the -Help/-List/-Version/-Doctor early exits so `-Update -Doctor`
# et al. run against the freshly-pulled copy.
# ---------------------------------------------------------------------------
if ($Update) {
  $checkoutRoot = [System.IO.Path]::GetFullPath((Join-Path $Root '..'))
  if (-not (Test-Path (Join-Path $checkoutRoot '.git'))) {
    Stop-Kit "-Update needs a git checkout, but '$checkoutRoot' isn't one. Re-clone the kit (or drop -Update)."
  }
  $oldVersion = $KitVersion
  # On a branch (manual clone / dev checkout) fast-forward it and leave the user
  # where they put themselves. Detached means the bootstrap pinned a release tag,
  # so "update" means move to the newest release (or to STARTER_KIT_BRANCH).
  # Invoke-NativeSilently: git writes progress to stderr, which under EAP=Stop on
  # WinPS 5.1 would abort the run; we only probe $LASTEXITCODE here.
  Invoke-NativeSilently 'git' @('-C', $checkoutRoot, 'symbolic-ref', '-q', 'HEAD') | Out-Null
  if ($LASTEXITCODE -eq 0) {
    Write-Step "Update: git -C '$checkoutRoot' pull --ff-only"
    Invoke-NativeSilently 'git' @('-C', $checkoutRoot, 'pull', '--ff-only') | Out-Null
    if ($LASTEXITCODE -ne 0) {
      Stop-Kit "git pull --ff-only failed (exit $LASTEXITCODE). Resolve local changes or divergence, then re-run."
    }
  } else {
    $ref = if ($env:STARTER_KIT_BRANCH) { $env:STARTER_KIT_BRANCH } else { $null }
    if (-not $ref) {
      $line = (Invoke-NativeSilently 'git' @('-C', $checkoutRoot, 'ls-remote', '--tags', '--refs', '--sort=-v:refname', 'origin', 'v*') | Select-Object -First 1)
      if ($line -and $line -match 'refs/tags/(.+)$') { $ref = $Matches[1] } else { $ref = 'main' }
    }
    Write-Step "Update: checking out $ref"
    Invoke-NativeSilently 'git' @('-C', $checkoutRoot, 'fetch', '--depth', '1', 'origin', $ref) | Out-Null
    if ($LASTEXITCODE -ne 0) {
      Stop-Kit "git fetch of '$ref' failed (exit $LASTEXITCODE). Check your network, then re-run."
    }
    Invoke-NativeSilently 'git' @('-C', $checkoutRoot, 'checkout', '--quiet', '--detach', 'FETCH_HEAD') | Out-Null
    if ($LASTEXITCODE -ne 0) {
      Stop-Kit "could not check out '$ref' (local changes?). Resolve them in '$checkoutRoot', then re-run."
    }
  }
  $newVersion = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { 'dev' }
  if ($oldVersion -eq $newVersion) { Write-Ok "already up to date ($newVersion)" }
  else { Write-Ok "updated $oldVersion -> $newVersion" }

  # Re-invoke the updated installer with the bound params minus -Update (so we
  # don't loop). Mirrors the bootstrap hand-off's `& $target @params` splat.
  $params = @{}
  foreach ($kv in $PSBoundParameters.GetEnumerator()) {
    if ($kv.Key -ne 'Update') { $params[$kv.Key] = $kv.Value }
  }
  & $target @params
  if ($script:RunFromFile) { exit $LASTEXITCODE } else { return }
}

# ---------------------------------------------------------------------------
# Step registry
# ---------------------------------------------------------------------------
$StepIds = @('prereqs', 'packages', 'runtimes', 'shell', 'docker', 'git', 'agents', 'wsl')
$StepFile = @{
  prereqs  = '01-prereqs.ps1'
  packages = '02-packages.ps1'
  runtimes = '03-runtimes.ps1'
  shell    = '04-shell.ps1'
  docker   = '05-docker.ps1'
  git      = '06-git.ps1'
  agents   = '07-agents.ps1'
  wsl      = '08-wsl.ps1'
}
$StepFunc = @{
  prereqs  = 'Step-Prereqs'
  packages = 'Step-Packages'
  runtimes = 'Step-Runtimes'
  shell    = 'Step-Shell'
  docker   = 'Step-Docker'
  git      = 'Step-Git'
  agents   = 'Step-Agents'
  wsl      = 'Step-Wsl'
}

# ---------------------------------------------------------------------------
# -Doctor: read-only diagnosis. Reports tool/runtime/config health in the kit's
# Write-Step/Write-Ok/Write-Warn style, changes nothing, and returns an exit
# code (0 = all present, PATH-only warnings included; 1 = something missing).
# The tool list mirrors the CI windows-e2e "verify installed" step.
# ---------------------------------------------------------------------------
function Invoke-Doctor {
  Write-Host "== lazy-starter-kit doctor (v$KitVersion) ==" -ForegroundColor White

  # tool -> fixing step id (used for the `.\install.ps1 -Only <step>` hint)
  $toolStep = [ordered]@{
    git = 'packages'; gh = 'packages'; jq = 'packages'; rg = 'packages'
    fd = 'packages'; bat = 'packages'; fzf = 'packages'; starship = 'packages'
    mise = 'packages'; uv = 'packages'; rustup = 'packages'; bun = 'packages'
    gjc = 'agents'; codex = 'agents'; claude = 'agents'
  }

  # user-local install dirs to probe when a tool isn't resolvable on PATH.
  $knownDirs = @()
  if ($env:USERPROFILE) {
    $knownDirs += (Join-Path $env:USERPROFILE '.local\bin')
    $knownDirs += (Join-Path $env:USERPROFILE '.bun\bin')
    $knownDirs += (Join-Path $env:USERPROFILE '.cargo\bin')
  }
  if ($env:LOCALAPPDATA) { $knownDirs += (Join-Path $env:LOCALAPPDATA 'mise\shims') }
  if ($env:APPDATA)      { $knownDirs += (Join-Path $env:APPDATA 'npm') }

  $missing = 0

  Write-Step "Tools"
  foreach ($tool in $toolStep.Keys) {
    if (Get-Command $tool -ErrorAction SilentlyContinue) {
      # ok: resolvable in this session -- show the first --version line, best-effort.
      $ver = ''
      try { $ver = (Invoke-NativeSilently $tool @('--version') | Select-Object -First 1) } catch {}
      if ($ver) { Write-Ok "$tool ($ver)" } else { Write-Ok "$tool" }
      continue
    }
    # not on PATH -- is the exe sitting in a known user-local install dir?
    $found = $null
    foreach ($d in $knownDirs) {
      foreach ($ext in @('.exe', '.cmd', '.bat', '')) {
        $candidate = Join-Path $d ($tool + $ext)
        if (Test-Path $candidate) { $found = $candidate; break }
      }
      if ($found) { break }
    }
    if ($found) {
      Write-Warn "$tool installed but not on PATH ($found) -- open a new PowerShell window to pick it up"
    } else {
      Write-Err "$tool missing -- fix: .\install.ps1 -Only $($toolStep[$tool])"
      $missing++
    }
  }

  # runtimes are mise-managed; resolve node/go/python via `mise which`.
  if (Get-Command mise -ErrorAction SilentlyContinue) {
    foreach ($rt in @('node', 'go', 'python')) {
      $p = (Invoke-NativeSilently 'mise' @('which', $rt) | Select-Object -First 1)
      if (($LASTEXITCODE -eq 0) -and $p) {
        Write-Ok "$rt (mise: $p)"
      } else {
        Write-Err "$rt missing -- fix: .\install.ps1 -Only runtimes"
        $missing++
      }
    }
  } else {
    Write-Warn "mise not resolvable -- skipping node/go/python checks (fix: .\install.ps1 -Only packages)"
  }

  Write-Step "Config"
  # managed profile block must be in BOTH CurrentUserAllHosts profiles (5.1 + 7).
  foreach ($profilePath in (Get-AllHostsProfilePaths)) {
    $short = if ($env:USERPROFILE) { $profilePath.Replace($env:USERPROFILE, '~') } else { $profilePath }
    if ((Test-Path $profilePath) -and (Select-String -Path $profilePath -SimpleMatch 'lazy-starter-kit:main' -Quiet)) {
      Write-Ok "profile block present ($short)"
    } else {
      Write-Warn "profile block missing ($short) -- fix: .\install.ps1 -Only shell"
    }
  }
  # starship.toml (04-shell.ps1 installs it at ~\.config\starship.toml)
  $starshipToml = Join-Path $HomeDir '.config\starship.toml'
  if (Test-Path $starshipToml) {
    Write-Ok "starship.toml present (~\.config\starship.toml)"
  } else {
    Write-Warn "starship.toml missing (~\.config\starship.toml) -- fix: .\install.ps1 -Only shell"
  }

  Write-Step "Summary"
  if ($missing -gt 0) {
    Write-Err "$missing item(s) missing -- run the suggested step(s) above, then re-check with -Doctor."
    return 1
  }
  Write-Ok "all expected tools present."
  return 0
}

if ($Help)    { Get-Help $target -Detailed;                    if ($script:RunFromFile) { exit 0 } else { return } }
if ($List)    { $StepIds | ForEach-Object { Write-Output $_ }; if ($script:RunFromFile) { exit 0 } else { return } }
if ($Version) { Write-Output "lazy-starter-kit $KitVersion";    if ($script:RunFromFile) { exit 0 } else { return } }
if ($Doctor)  {
  $code = Invoke-Doctor
  if ($script:RunFromFile) { exit $code }
  $global:LASTEXITCODE = $code
  return
}

if ($NoAgents) { $Skip = @($Skip) + 'agents' }

# ---------------------------------------------------------------------------
# -Profile <name>: a preset skip-set UNIONed with the user's -Skip. A preset
# picks steps to *drop*; -Only picks steps to *keep* -- combining them is
# ambiguous, so they're mutually exclusive. Unknown names get the same friendly
# "valid: ..." listing as an unknown step id.
# ($Profile is bound in $PSBoundParameters, so it survives the -Update
# re-invoke's param rebuild and the bootstrap hand-off's splat automatically.)
# ---------------------------------------------------------------------------
$ProfileNames = @('full', 'minimal', 'work')
$ProfileSkip  = @{
  full    = @()
  minimal = @('docker', 'agents', 'wsl')
  work    = @('docker', 'wsl')
}
if ($Profile) {
  if (@($Only).Count -gt 0) { Stop-Kit "choose either -Profile or -Only, not both." }
  if ($ProfileNames -notcontains $Profile) {
    Stop-Kit "unknown profile: '$Profile' (valid: $($ProfileNames -join ' '))"
  }
  $Skip = @($Skip) + $ProfileSkip[$Profile]
}

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
$stepsLine = "steps: " + ($selected -join ' ')
if ($Profile) { $stepsLine += "  (profile: $Profile)" }
Write-Info $stepsLine

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

  # --- optional: ask for a GitHub star (opt-in, default No) ---------------
  # Interactive runs only -- -Yes and non-interactive/CI never see this
  # (Confirm-Action -DefaultNo declines in both), and nothing is starred
  # without an explicit 'y'.
  $repoSlug = $RepoUrl -replace '^https://github\.com/', '' -replace '\.git$', ''
  if ((Test-HasCommand gh)) {
    Invoke-NativeSilently 'gh' @('auth', 'status') | Out-Null
    if ($LASTEXITCODE -eq 0) {
      Invoke-NativeSilently 'gh' @('api', "user/starred/$repoSlug") | Out-Null
      if ($LASTEXITCODE -ne 0) {
        if (Confirm-Action "Enjoyed the setup? Star $repoSlug on GitHub?" -DefaultNo) {
          Invoke-NativeSilently 'gh' @('api', '-X', 'PUT', "user/starred/$repoSlug") | Out-Null
          if ($LASTEXITCODE -eq 0) { Write-Ok "thanks for the star!" }
          else { Write-Info "couldn't star from here -- https://github.com/$repoSlug" }
        }
      }
    }
  }
}
if ($script:RunFromFile) { exit 0 } else { return }
