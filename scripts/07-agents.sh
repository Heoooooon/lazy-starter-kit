#!/usr/bin/env bash
# 07-agents.sh — AI coding agents: codex, Claude Code, opt-in Hermes

step_agents() {
  step "AI agents: codex + Claude Code"
  load_brew
  load_mise
  export PATH="$HOME/.bun/bin:$PATH"   # bun global executables live here
  # ~/.local/bin hosts claude (Claude Code) and hermes; exporting it up front
  # also makes the Hermes installer detect PATH and skip editing ~/.zshrc
  # (the kit's managed block owns that PATH entry instead).
  export PATH="$HOME/.local/bin:$PATH"

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

  # --- codex -----------------------------------------------------------
  if ! have npm; then
    if [[ "$DRY_RUN" == "1" ]]; then
      info "[dry-run] npm install -g @openai/codex"
    else
      warn "npm not found — skipping codex (run the 'runtimes' step first)"
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

  if have node; then
    if [[ "$DRY_RUN" == "1" ]]; then
      node "$ROOT/scripts/ai/install-shell-guard.js" --home "$HOME" --dry-run
    else
      node "$ROOT/scripts/ai/install-shell-guard.js" --home "$HOME" \
        || warn "could not install the Codex/Claude recursive-rm guard"
    fi
  else
    warn "node not found — could not install the Codex/Claude recursive-rm guard"
  fi
  info "AI safety: review and approve the lazy-starter-kit hook when Codex first asks."

  # --- Hermes Agent (Nous Research, OPT-IN only) -------------------------
  # Official installer: clones NousResearch/hermes-agent, self-manages Python/
  # Node/Chromium, links `hermes` into ~/.local/bin (already on PATH, exported
  # at the top of this step). Heavy + external, so it's never installed by
  # default — enable with: HERMES=1 ./install.sh.
  if [[ "${HERMES:-0}" != "1" ]]; then
    info "Skipping Hermes Agent (opt-in; enable with HERMES=1)"
  elif have hermes; then
    ok "Hermes Agent present ($(hermes --version 2>/dev/null | head -1 || echo installed))"
  elif [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup"
  else
    info "Installing Hermes Agent (Nous Research)…"
    # Download first, then verify it's a real script (non-empty + shebang)
    # before executing — same guard as Claude Code above; a truncated or empty
    # download must never reach bash.
    local hm_tmp; hm_tmp="$(mktemp)"
    if curl -fsSL https://hermes-agent.nousresearch.com/install.sh -o "$hm_tmp" \
       && [[ -s "$hm_tmp" ]] && head -1 "$hm_tmp" | grep -q '^#!'; then
      bash "$hm_tmp" --skip-setup \
        || warn "Hermes installer did not complete (re-run later: curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup)"
    else
      warn "Hermes installer download failed or was not a script — skipped (re-run later: curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup)"
    fi
    rm -f "$hm_tmp"
    info "Hermes: configure with 'hermes setup --portal', then start with 'hermes'."
  fi

  # --- Antigravity CLI (Google) — not installed by the kit -----------------
  # Gemini CLI's closed-source successor (`agy`) has a small free tier and its
  # own account flow, so it is a manual one-liner documented in the README
  # next to Grok Build:  curl -fsSL https://antigravity.google/cli/install.sh | bash
}
