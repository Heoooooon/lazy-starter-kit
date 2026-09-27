# 07-agents.ps1 -- AI coding agents: codex, Claude Code (claude)

function Step-Agents {
  Write-Step "AI agents: codex + Claude Code"
  Update-SessionPath
  if ($script:DryRun -and $script:InstallProfile -eq 'ai') {
    Write-Info '[dry-run] npm.cmd install -g @openai/codex'
    Write-Info '[dry-run] official Claude Code installer: https://claude.ai/install.ps1'
    Write-Info '[dry-run] install Codex/Claude safety hooks with Node; persist minimal AI PATH'
    return
  }

  # --- codex via npm ---------------------------------------------------
  $haveNpm = Test-HasCommand npm
  if (-not $haveNpm -and $script:InstallProfile -ne 'ai' -and (Test-HasCommand mise)) {
    # npm may only be reachable through mise's node shim
    $haveNpm = $true
  }
  if (-not $haveNpm) {
    if ($script:InstallProfile -eq 'ai') { Stop-Kit 'npm missing -- action needed: install Node.js LTS/npm before AI agents.' }
    Write-Warn "npm not found -- skipping codex (run the 'runtimes' step first)"
    return
  }

  if (Test-HasCommand codex) {
    Write-Ok "codex present ($(Invoke-NativeSilently 'codex' @('--version') | Select-Object -First 1))"
  } else {
    Write-Info "Installing @openai/codex (npm -g)..."
    if ($script:DryRun) {
      Write-Info "[dry-run] mise exec -- npm install -g @openai/codex; mise reshim"
    } else {
      if ($script:InstallProfile -eq 'ai') {
        & npm.cmd install -g '@openai/codex'
        if ($LASTEXITCODE -ne 0) { Stop-Kit "Codex install failed (exit $LASTEXITCODE)." }
      } elseif (Test-HasCommand mise) {
        & mise exec -- npm install -g '@openai/codex'
        Invoke-NativeSilently 'mise' @('reshim')
      } else {
        & npm install -g '@openai/codex'
      }
    }
    Update-SessionPath
  }

  # --- Claude Code (claude) via the official installer ------------------
  # https://claude.ai/install.ps1 is non-interactive, works on WinPS 5.1+/7,
  # installs to ~/.local/bin/claude.exe, and self-updates in the background.
  if (Test-HasCommand claude) {
    Write-Ok "Claude Code present ($(Invoke-NativeSilently 'claude' @('--version') | Select-Object -First 1))"
  } elseif ($script:DryRun) {
    Write-Info "[dry-run] irm https://claude.ai/install.ps1 | iex"
  } else {
    Write-Info "Installing Claude Code (irm https://claude.ai/install.ps1 | iex)..."
    try {
      # Fetch the installer into a variable and sanity-check it before running,
      # rather than piping straight into `iex`. Executing a scriptblock built
      # from the text works on WinPS 5.1 too (no `| iex` of a raw string).
      $installer = Invoke-RestMethod -Uri 'https://claude.ai/install.ps1'
      if ([string]::IsNullOrWhiteSpace($installer)) {
        throw "installer download was empty"
      }
      & ([scriptblock]::Create($installer))
      # Make claude.exe (~/.local/bin) visible to later steps this session.
      Update-SessionPath
      if (Test-HasCommand claude) {
        Write-Ok "Claude Code installed ($(Invoke-NativeSilently 'claude' @('--version') | Select-Object -First 1))"
      } else {
        Write-Info "Claude Code installed -- open a new shell (or it's on ~/.local/bin) to use 'claude'."
      }
    } catch {
      if ($script:InstallProfile -eq 'ai') { Stop-Kit "Claude Code install failed: $($_.Exception.Message)" }
      Write-Warn "Claude Code install did not complete -- re-run later: irm https://claude.ai/install.ps1 | iex"
    }
  }

  $safetyInstaller = Join-Path (Split-Path -Parent $Root) 'scripts\ai\install-shell-guard.js'
  if ((Test-HasCommand node) -and (Test-Path -LiteralPath $safetyInstaller)) {
    $safetyArgs = @($safetyInstaller, '--home', $env:USERPROFILE)
    if ($script:DryRun) { $safetyArgs += '--dry-run' }
    & node @safetyArgs
    if ($LASTEXITCODE -ne 0) {
      if ($script:InstallProfile -eq 'ai') { Stop-Kit 'AI safety-hook installation failed; action needed.' }
      Write-Warn "could not install the Codex/Claude recursive-rm guard"
    }
    else { Write-Info "AI safety: review and approve the lazy-starter-kit hook when Codex first asks." }
  } else {
    if ($script:InstallProfile -eq 'ai') { Stop-Kit 'Node or the safety-hook installer is missing; action needed.' }
    Write-Warn "node not found -- could not install the Codex/Claude recursive-rm guard"
  }

  if ($script:InstallProfile -eq 'ai') { Update-AiPath -Persist; return }

  # --- Hermes Agent (Nous Research) -------------------------------------
  # The official installer is a bash/curl script with no native Windows build.
  # Run it inside WSL if you want Hermes on Windows.
  Write-Info "Hermes Agent: no native Windows installer -- install it inside WSL2:"
  Write-Info "  wsl bash -c 'curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup'"

  # --- Antigravity CLI (Google) -- not installed by the kit ----------------
  # Gemini CLI's closed-source successor (`agy`) has a small free tier and its
  # own account flow, so it is a manual one-liner documented in the README
  # next to Grok Build:  irm https://antigravity.google/cli/install.ps1 | iex
  # Automatic uninstall is retired; use the vendor's removal instructions.
}
