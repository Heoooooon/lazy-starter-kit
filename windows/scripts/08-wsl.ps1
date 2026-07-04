# 08-wsl.ps1 -- WSL2 + Ubuntu, then (optionally) the lazy-starter-kit LINUX kit
#              inside it. Optional & heavily opt-in (needs admin + virtualization).
#
# This step is an IDEMPOTENT, RESUMABLE pipeline: each run detects the current
# WSL state and advances AS FAR AS IT CAN in one go -- it loops detect->act,
# falling through registration -> root init -> the Linux-kit offer in a single
# run whenever no reboot is pending. It NEVER reboots the machine itself.
# `wsl --install` can require a reboot; when it does we print a clear
# "reboot, then re-run  .\install.ps1 -Only wsl" next-step and stop -- the next
# run resumes from wherever this one left off.
#
# Verified against Microsoft's WSL docs (fetched 2026, ms.date 2025-06/2025-12):
#   https://learn.microsoft.com/windows/wsl/install
#   https://learn.microsoft.com/windows/wsl/basic-commands
#   https://learn.microsoft.com/windows/wsl/setup/environment
# and the (archived Jan-2025) WSL distro-launcher for non-interactive root init:
#   https://github.com/microsoft/WSL-DistroLauncher
#
# Facts we rely on (subtle ones cited inline where they matter):
#  - `wsl --install` enables the WSL + Virtual Machine Platform components,
#    installs the kernel, sets WSL2 as the default, and installs Ubuntu. It
#    requires an ADMINISTRATOR PowerShell and "a reboot may be required"
#    (setup/environment: "reboot may be required"; install: "then restart your
#    machine"). The docs do NOT publish an exit code for the reboot case -- see
#    the heuristic in Install-WslPlatform.
#  - `--no-launch` installs the distro without launching it, so no first-run
#    OOBE username prompt fires during the install (basic-commands#install).
#  - `-d Ubuntu` / `--distribution Ubuntu` selects the distro.
#  - `wsl --status` exits 0 only once the WSL platform is actually installed;
#    on a machine without WSL, wsl.exe is a stub that prints help and exits != 0.
#  - `wsl -d Ubuntu -u root -e true` exits 0 only when Ubuntu is registered AND
#    initialized AND runnable -- our definitive, encoding-agnostic "ready" probe
#    (basic-commands: `wsl --distribution <D> --user <U>` runs a command as a
#    user; root always exists).
#  - `ubuntu.exe install --root` initializes the distro non-interactively with
#    the default user left as root, bypassing the interactive OOBE username
#    prompt (WSL-DistroLauncher: "install [--root]" = "Install the distribution
#    and do not launch the shell", "--root: Do not create a user account and
#    leave the default user set to root").
#  - `wsl --set-default-version 2` sets WSL2 as the default for new distros.
#  - `wsl --unregister Ubuntu` (used by the uninstaller) permanently deletes the
#    distro's filesystem/data (basic-commands: "all data, settings, and software
#    associated with that distribution will be permanently lost").

$script:WslDistro = 'Ubuntu'

# ---------------------------------------------------------------------------
# Detection -- read-only; safe to call under -DryRun. Returns Usable/Registered/
# Ready flags computed from EXIT CODES (encoding-agnostic) plus one parsed list.
# ---------------------------------------------------------------------------
function Get-WslState {
  # wsl.exe emits UTF-16LE by default, which PowerShell mangles when parsing its
  # text output; WSL_UTF8=1 makes wsl.exe emit UTF-8 so `--list` is parseable.
  # We still lean on exit-code probes everywhere we can.
  $env:WSL_UTF8 = '1'

  $state = [ordered]@{
    Usable     = $false   # WSL platform installed (`wsl --status` exits 0)
    Registered = $false   # target distro appears in `wsl -l -q`
    Ready      = $false   # `wsl -d <distro> -u root -e true` exits 0
  }

  if (-not (Test-HasCommand wsl)) { return $state }

  Invoke-NativeSilently 'wsl' @('--status') | Out-Null
  $state.Usable = ($LASTEXITCODE -eq 0)
  if (-not $state.Usable) { return $state }

  $names = Invoke-NativeSilently 'wsl' @('--list', '--quiet')
  if (($LASTEXITCODE -eq 0) -and $names) {
    $trimmed = @($names | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $state.Registered = [bool]($trimmed -contains $script:WslDistro)
  }
  if (-not $state.Registered) { return $state }

  Invoke-NativeSilently 'wsl' @('-d', $script:WslDistro, '-u', 'root', '-e', 'true') | Out-Null
  $state.Ready = ($LASTEXITCODE -eq 0)
  return $state
}

# ---------------------------------------------------------------------------
# Run the lazy-starter-kit LINUX installer INSIDE the distro as root. The Linux
# kit handles root fine (SUDO="" path, proven in the CI containers). We skip its
# docker step (Docker-in-WSL is a separate opt-in). Branch is pinned to
# STARTER_KIT_BRANCH when set, else main. Output is streamed live.
# ---------------------------------------------------------------------------
function Invoke-WslLinuxKit {
  $ref = if ($env:STARTER_KIT_BRANCH) { $env:STARTER_KIT_BRANCH } else { 'main' }
  $url = "https://raw.githubusercontent.com/Heoooooon/lazy-starter-kit/$ref/linux/install.sh"
  $bash = "curl -fsSL $url | bash -s -- --yes --skip docker"
  $wslArgs = @('-d', $script:WslDistro, '-u', 'root', '-e', 'bash', '-lc', $bash)

  if ($script:DryRun) {
    Write-Host ("  [dry-run] wsl {0}" -f ($wslArgs -join ' ')) -ForegroundColor DarkGray
    return
  }

  Write-Info "Running the Linux kit inside $script:WslDistro (root; skipping docker; ref: $ref)..."
  # Stream the installer's output live. We can't use Invoke-NativeSilently (it
  # discards stderr) because we want to SEE progress; but under EAP=Stop on
  # WinPS 5.1 a native command's stderr line becomes a TERMINATING error, so we
  # relax EAP to 'Continue' for the streamed call and restore it afterward.
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    & wsl @wslArgs
  } finally {
    $ErrorActionPreference = $prev
  }
  if ($LASTEXITCODE -eq 0) {
    Write-Ok "Linux kit finished inside $script:WslDistro"
  } else {
    Write-Warn "Linux kit exited $LASTEXITCODE inside $script:WslDistro -- non-fatal."
    Write-Info "Re-run just this step later:  .\install.ps1 -Only wsl"
  }
}

# ---------------------------------------------------------------------------
# Initialize a registered-but-uninitialized distro non-interactively as root.
# Prefer the launcher's `ubuntu install --root` (no OOBE username prompt). If the
# launcher isn't resolvable, fall back to an interactive first-run when we have a
# console, else print guidance.
# ---------------------------------------------------------------------------
function Initialize-WslDistro {
  $launcher = $script:WslDistro.ToLower()   # 'ubuntu' -> ubuntu.exe

  if (Test-HasCommand $launcher) {
    Write-Info "Initializing $script:WslDistro non-interactively as root ($launcher install --root)..."
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
      & $launcher install --root
    } finally {
      $ErrorActionPreference = $prev
    }
    if ($LASTEXITCODE -eq 0) { Write-Ok "$script:WslDistro initialized (default user: root)" }
    else { Write-Warn "$launcher install --root exited $LASTEXITCODE" }
    return
  }

  if (-not [Console]::IsInputRedirected) {
    Write-Info "Launcher '$launcher' not on PATH; opening $script:WslDistro for first-run setup (create a UNIX user when prompted)..."
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
      & wsl -d $script:WslDistro
    } finally {
      $ErrorActionPreference = $prev
    }
    return
  }

  Write-Warn "$script:WslDistro needs first-run initialization but no non-interactive path is available here."
  Write-Info "Open '$script:WslDistro' from the Start menu once (create a UNIX user), then re-run  .\install.ps1 -Only wsl"
}

# ---------------------------------------------------------------------------
# Install WSL2 + the distro (heavy, admin-only). Never reached under -Yes /
# non-interactive (the DefaultNo gate in Step-Wsl blocks that). Detects the
# reboot case and prints a big resume next-step.
#
# Returns $true when the install advanced WITHOUT needing a reboot (so the
# caller's loop can re-detect and continue the pipeline in the same run), and
# $false when the caller must stop now -- a reboot is required (banner already
# printed) or the install errored.
# ---------------------------------------------------------------------------
function Install-WslPlatform {
  param([switch]$PlatformMissing)

  if (-not (Test-HasCommand wsl)) {
    Write-Err "wsl.exe not found -- your Windows is too old for one-command WSL."
    Write-Info "Update to Windows 10 2004 (build 19041)+ or Windows 11, then re-run  .\install.ps1 -Only wsl"
    return $false
  }

  Write-Info "Installing WSL2 + $script:WslDistro (wsl --install --no-launch -d $script:WslDistro)..."
  # Capture combined output so we can scan it for a reboot notice; keep the exit
  # code. Relax EAP so wsl's stderr progress doesn't abort under EAP=Stop.
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $out = ''
  try {
    $out = (& wsl --install --no-launch -d $script:WslDistro 2>&1 | Out-String)
  } finally {
    $ErrorActionPreference = $prev
  }
  $code = $LASTEXITCODE
  if ($out) { Write-Host $out.TrimEnd() }

  if ($code -ne 0) {
    # Mirror the winget admin-ledger tone: state the likely cause, keep going.
    Write-Warn "wsl --install exited $code."
    Write-Info "This usually means it needs an ADMINISTRATOR PowerShell, or hardware virtualization is disabled in BIOS/UEFI."
    Write-Info "Fix that, then re-run:  .\install.ps1 -Only wsl"
    return $false
  }

  # Ensure WSL2 is the default for future distros (new installs are already WSL2,
  # but this is cheap and idempotent).
  Invoke-NativeSilently 'wsl' @('--set-default-version', '2') | Out-Null

  # Reboot detection. Microsoft's docs say only that "a reboot may be required"
  # and publish NO exit code for it, so we detect heuristically:
  #  (a) the install output mentions restart/reboot, OR
  #  (b) the WSL PLATFORM was freshly enabled AND WSL still isn't usable in this
  #      session -- enabling the optional components only takes effect after a
  #      reboot, so wsl.exe won't be functional until then.
  $rebootNeeded = ($out -match '(?i)re-?boot|re-?start')
  if (-not $rebootNeeded -and $PlatformMissing) {
    $after = Get-WslState
    if (-not $after.Usable) { $rebootNeeded = $true }
  }

  if ($rebootNeeded) {
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Yellow
    Write-Host "   REBOOT REQUIRED to finish installing WSL." -ForegroundColor Yellow
    Write-Host "   After rebooting, run:   .\install.ps1 -Only wsl" -ForegroundColor Yellow
    Write-Host "   (that resumes: initializes $script:WslDistro, then offers the Linux kit)" -ForegroundColor Yellow
    Write-Host "  ============================================================" -ForegroundColor Yellow
    return $false
  }

  Write-Ok "WSL2 + $script:WslDistro installed."
  # No reboot pending: signal the caller's loop to re-detect and continue this
  # run straight into initialization and the Linux-kit offer.
  return $true
}

# ---------------------------------------------------------------------------
# Step entry point -- the state machine, driven as a bounded detect->act LOOP.
# Each cycle detects the current WSL state and performs the ONE action that
# advances it, then re-detects and falls through to the next stage IN THE SAME
# RUN, so one interactive run goes as far as it usefully can:
#   READY                  -> (re-)offer the Linux kit (default-Yes; idempotent)
#   REGISTERED, not READY  -> initialize non-interactively, then loop -> offer
#   USABLE, not REGISTERED -> opt-in gate (default-No) -> register, then loop
#   not installed          -> opt-in gate (default-No) -> wsl --install
# The only place we stop MID-pipeline is when Windows needs a reboot to finish
# installing WSL (Install-WslPlatform prints the REBOOT REQUIRED banner and
# returns $false) -- we never reboot for you. A cycle that makes no forward
# progress also stops (with a re-run next-step) so the loop can't spin forever.
# ---------------------------------------------------------------------------
function Step-Wsl {
  Write-Step "WSL2 + Ubuntu (optional; runs the Linux kit inside)"

  if (-not (Test-IsWindows)) { Write-Info "not Windows -- skipping WSL"; return }

  # Rank the state so we can detect a cycle that failed to move forward:
  #   0 nothing / 1 usable / 2 registered / 3 ready (each implies the ones below).
  # There are only three stages, so a small cycle budget is plenty; the
  # no-progress guard below is the real infinite-loop protection.
  $prevRank = -1
  $maxCycles = 6

  for ($cycle = 1; $cycle -le $maxCycles; $cycle++) {
    $st = Get-WslState

    $rank = 0
    if ($st.Usable)     { $rank = 1 }
    if ($st.Registered) { $rank = 2 }
    if ($st.Ready)      { $rank = 3 }

    # A cycle that didn't advance the state (e.g. init ran but the distro still
    # isn't runnable) means we've done all we usefully can right now: stop with
    # a re-run next-step instead of looping on the same action forever.
    if ($rank -le $prevRank) {
      Write-Warn "$script:WslDistro didn't advance to the next stage this run."
      Write-Info "Re-run to continue (or open '$script:WslDistro' once from the Start menu if it's stuck):  .\install.ps1 -Only wsl"
      return
    }
    $prevRank = $rank

    # ----------------------------------------------------------------- READY
    if ($st.Ready) {
      Write-Ok "WSL2 default + $script:WslDistro registered and initialized"
      if ($script:DryRun) {
        Write-Info "[dry-run] plan: offer to run the Linux kit inside $script:WslDistro"
        Invoke-WslLinuxKit
        return
      }
      if (Confirm-Action "Run the lazy-starter-kit Linux setup inside $script:WslDistro now?") {
        Invoke-WslLinuxKit
      } else {
        Write-Info "Skipped. Run it later:  .\install.ps1 -Only wsl"
      }
      return
    }

    # ------------------------------------------- REGISTERED but not initialized
    if ($st.Registered) {
      Write-Info "$script:WslDistro is registered but not initialized yet."
      if ($script:DryRun) {
        $launcher = $script:WslDistro.ToLower()
        if (Test-HasCommand $launcher) {
          Write-Host ("  [dry-run] {0} install --root   (non-interactive root init)" -f $launcher) -ForegroundColor DarkGray
        } else {
          Write-Host ("  [dry-run] wsl -d {0}   (interactive first-run init)" -f $script:WslDistro) -ForegroundColor DarkGray
        }
        Write-Info "[dry-run] then offer to run the Linux kit inside $script:WslDistro"
        return
      }
      Initialize-WslDistro
      # Initialization involves no reboot, so loop and re-detect: if it's runnable
      # now we fall straight through to the Linux-kit offer in this same run.
      continue
    }

    # ---------------------------------------- NOT registered (opt-in install gate)
    $platformMissing = -not $st.Usable
    if ($platformMissing) {
      Write-Info "WSL is not installed on this machine."
    } else {
      Write-Info "WSL2 is available but the $script:WslDistro distro isn't installed."
    }
    Write-Info "WSL needs administrator rights and hardware virtualization (BIOS/UEFI)."
    Write-Warn "This installs a full Linux environment; a reboot may be required."

    if ($script:DryRun) {
      Write-Host "  [dry-run] wsl --install --no-launch -d $script:WslDistro" -ForegroundColor DarkGray
      Write-Host "  [dry-run] wsl --set-default-version 2" -ForegroundColor DarkGray
      if ($platformMissing) {
        Write-Info "[dry-run] a reboot may be required; then re-run  .\install.ps1 -Only wsl"
      } else {
        Write-Info "[dry-run] no reboot needed to register, so this run continues: initialize $script:WslDistro, then offer the Linux kit"
      }
      return
    }

    # Heavy opt-in, EXACTLY like Docker Desktop: default-No, and NEVER installed
    # non-interactively. Under -Yes (AssumeYes) or redirected input this gate
    # returns $false, so CI -- which can't do nested virtualization -- is
    # deterministic: it just prints the skip line below and moves on.
    if ($script:AssumeYes -or [Console]::IsInputRedirected) {
      Write-Info "Skipped WSL (opt-in; not installed non-interactively)."
      Write-Info "To install it explicitly: rerun interactively and answer y, or  .\install.ps1 -Only wsl"
      return
    }
    if (-not (Confirm-Action "Install WSL2 + $script:WslDistro now? (needs admin + a likely reboot)" -DefaultNo)) {
      Write-Info "Skipped. To set it up later:  .\install.ps1 -Only wsl"
      return
    }

    if (-not (Test-IsAdmin)) {
      Write-Err "WSL install needs an ADMINISTRATOR PowerShell."
      Write-Info "Right-click PowerShell > 'Run as administrator', then:  .\install.ps1 -Only wsl"
      return
    }

    # Install/register. $true = advanced with no reboot pending -> loop and
    # continue the pipeline; $false = stop now (reboot required, banner already
    # printed, or an install error).
    if (-not (Install-WslPlatform -PlatformMissing:$platformMissing)) { return }
    continue
  }

  # Cycle budget exhausted (shouldn't happen: the pipeline is only three stages,
  # and each cycle must strictly advance the rank to get here).
  Write-Info "Re-run to continue:  .\install.ps1 -Only wsl"
}
