#!/usr/bin/env bash
# 07-agents.sh — AI coding agents: gajae-code (gjc), codex, lazycodex (OmO), Hermes, Claude Code

step_agents() {
  step "AI agents: gajae-code + codex + lazycodex + Hermes + Claude Code"
  load_local_bins
  load_mise
  export PATH="$HOME/.bun/bin:$PATH"   # bun global bins (gjc) live here

  # --- gajae-code (gjc) via bun -----------------------------------------
  if have bun; then
    if have gjc; then
      ok "gajae-code present (gjc $(gjc --version 2>/dev/null | head -1))"
    else
      info "Installing gajae-code (bun add -g gajae-code)…"
      run bun add -g gajae-code
    fi
  else
    warn "bun not found — skipping gajae-code (install bun via the 'packages' step)"
  fi

  # --- Claude Code (Anthropic) ------------------------------------------
  # Official installer drops the `claude` binary into ~/.local/bin and then
  # self-updates in the background. Installs by default everywhere (incl. CI).
  # Kept ahead of the npm-dependent agents so a box without node still gets it.
  if have claude; then
    ok "Claude Code present ($(claude --version 2>/dev/null | head -1))"
  elif [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] curl -fsSL https://claude.ai/install.sh | bash"
  else
    info "Installing Claude Code (Anthropic)…"
    # Download first, then verify it's a real script (non-empty + shebang)
    # before executing — a truncated/failed download must not run as bash.
    local cc_tmp; cc_tmp="$(mktemp)"
    if curl -fsSL https://claude.ai/install.sh -o "$cc_tmp" \
       && [[ -s "$cc_tmp" ]] && head -1 "$cc_tmp" | grep -q '^#!'; then
      bash "$cc_tmp" \
        || warn "Claude Code install did not complete — re-run later: curl -fsSL https://claude.ai/install.sh | bash"
    else
      warn "Claude Code install did not complete — re-run later: curl -fsSL https://claude.ai/install.sh | bash"
    fi
    rm -f "$cc_tmp"
  fi

  # --- codex (base harness that lazycodex extends) ----------------------
  if ! have npm; then
    if [[ "$DRY_RUN" == "1" ]]; then
      info "[dry-run] npm install -g @openai/codex"
      info "[dry-run] npx --yes lazycodex-ai install"
    else
      warn "npm not found — skipping codex + lazycodex (run the 'runtimes' step first)"
    fi
    return 0
  fi
  if have codex; then
    ok "codex present ($(codex --version 2>/dev/null | head -1))"
  else
    info "Installing @openai/codex (npm -g)…"
    run npm install -g @openai/codex
    # mise-managed node needs a reshim so the `codex` shim appears on PATH
    have mise && run mise reshim
  fi

  # --- lazycodex (OmO agent harness for codex) --------------------------
  # No global install by design — always run via npx.
  if [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] npx --yes lazycodex-ai install"
  elif is_tty && [[ "$ASSUME_YES" != "1" ]]; then
    info "Installing lazycodex (npx lazycodex-ai install)…"
    npx --yes lazycodex-ai install || warn "lazycodex installer did not complete"
  else
    info "Installing lazycodex (non-interactive, autonomous)…"
    npx --yes lazycodex-ai install --no-tui --codex-autonomous || \
      warn "lazycodex installer did not complete"
  fi
  info "lazycodex: on first 'codex' launch, APPROVE the omo hooks in the startup review."

  # --- Hermes Agent (Nous Research) -------------------------------------
  # Official installer self-manages Python/Node/Chromium and links `hermes`
  # into ~/.local/bin. Heavy + external, so it's non-fatal and toggleable
  # with HERMES=0 (CI sets HERMES=0 to stay lean).
  export PATH="$HOME/.local/bin:$PATH"
  if [[ "${HERMES:-1}" != "1" ]]; then
    info "Skipping Hermes Agent (HERMES=0)"
  elif have hermes; then
    ok "Hermes Agent present ($(hermes --version 2>/dev/null | head -1 || echo installed))"
  elif [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup"
  else
    info "Installing Hermes Agent (Nous Research)…"
    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup \
      || warn "Hermes installer did not complete (re-run later: curl … | bash)"
    info "Hermes: configure with 'hermes setup --portal', then start with 'hermes'."
  fi
}
