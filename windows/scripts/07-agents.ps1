# 07-agents.ps1 -- AI coding agents: gajae-code (gjc), codex, lazycodex (OmO)

function Step-Agents {
  Write-Step "AI agents: gajae-code + codex + lazycodex"
  Update-SessionPath

  # --- gajae-code (gjc) via bun -----------------------------------------
  if (Test-HasCommand bun) {
    if (Test-HasCommand gjc) {
      Write-Ok "gajae-code present (gjc $(& gjc --version 2>$null | Select-Object -First 1))"
    } else {
      Write-Info "Installing gajae-code (bun add -g gajae-code)..."
      Invoke-Run -Exe 'bun' -Arguments @('add', '-g', 'gajae-code') | Out-Null
      Update-SessionPath
    }
  } else {
    Write-Warn "bun not found -- skipping gajae-code (install bun via the 'packages' step)"
  }

  # --- codex (base harness that lazycodex extends) ----------------------
  $haveNpm = Test-HasCommand npm
  if (-not $haveNpm -and (Test-HasCommand mise)) {
    # npm may only be reachable through mise's node shim
    $haveNpm = $true
  }
  if (-not $haveNpm) {
    Write-Warn "npm not found -- skipping codex + lazycodex (run the 'runtimes' step first)"
    return
  }

  if (Test-HasCommand codex) {
    Write-Ok "codex present ($(& codex --version 2>$null | Select-Object -First 1))"
  } else {
    Write-Info "Installing @openai/codex (npm -g)..."
    if ($script:DryRun) {
      Write-Info "[dry-run] mise exec -- npm install -g @openai/codex; mise reshim"
    } else {
      if (Test-HasCommand mise) {
        & mise exec -- npm install -g '@openai/codex'
        & mise reshim 2>$null
      } else {
        & npm install -g '@openai/codex'
      }
    }
    Update-SessionPath
  }

  # --- lazycodex (OmO harness for codex) -- always via npx ----------------
  if ($script:DryRun) {
    Write-Info "[dry-run] npx --yes lazycodex-ai install"
  } elseif (-not [Console]::IsInputRedirected) {
    Write-Info "Installing lazycodex (npx lazycodex-ai install)..."
    & npx --yes lazycodex-ai install
    if ($LASTEXITCODE -ne 0) { Write-Warn "lazycodex installer did not complete" }
  } else {
    Write-Info "Installing lazycodex (non-interactive, autonomous)..."
    & npx --yes lazycodex-ai install --no-tui --codex-autonomous
    if ($LASTEXITCODE -ne 0) { Write-Warn "lazycodex installer did not complete" }
  }
  Write-Info "lazycodex: on first 'codex' launch, APPROVE the omo hooks in the startup review."

  # --- Hermes Agent (Nous Research) -------------------------------------
  # The official installer is a bash/curl script with no native Windows build.
  # Run it inside WSL if you want Hermes on Windows.
  Write-Info "Hermes Agent: no native Windows installer -- install it inside WSL2:"
  Write-Info "  wsl bash -c 'curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup'"
}
