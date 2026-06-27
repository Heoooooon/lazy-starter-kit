#!/usr/bin/env bash
# 03-runtimes.sh — language runtimes: mise (node/python/go) + rustup (rust)

# Edit these to taste; mise resolves "lts"/"latest" at install time.
MISE_TOOLS=("node@lts" "python@latest" "go@latest")

step_runtimes() {
  step "Runtimes: mise (node/python/go) + rustup (rust)"
  load_brew
  # In a full dry-run on a bare machine, mise/rustup aren't installed yet (the
  # brew step only previewed them). Preview gracefully instead of dying.
  if ! have mise || ! have rustup; then
    if [[ "$DRY_RUN" == "1" ]]; then
      info "[dry-run] would install via mise: ${MISE_TOOLS[*]}, and Rust stable via rustup (after the brew step provides them)"
      return 0
    fi
    have mise   || die "mise not found — run the 'brew' step first."
    have rustup || die "rustup not found — run the 'brew' step first."
  fi

  # Heads-up: a runtime already installed by another method (system .pkg, nvm,
  # brew, …) is NOT removed — mise installs its own and shadows it via PATH.
  # Checked here, before mise is on PATH, so any hit is genuinely non-mise.
  local _t _p
  for _t in node python go; do
    if _p="$(command -v "$_t" 2>/dev/null)" && [[ -n "$_p" && "$_p" != *"/.local/share/mise/"* ]]; then
      warn "existing $_t at $_p — mise will install its own and shadow it (verify later: which -a $_t)"
    fi
  done

  # --- mise-managed runtimes --------------------------------------------
  info "mise: ${MISE_TOOLS[*]}"
  run mise use -g "${MISE_TOOLS[@]}"
  load_mise

  # --- rust via rustup ---------------------------------------------------
  if rustup show active-toolchain >/dev/null 2>&1 \
     && rustup show active-toolchain 2>/dev/null | grep -q .; then
    ok "rust toolchain: $(rustup show active-toolchain 2>/dev/null | head -1)"
  else
    info "Installing Rust stable toolchain…"
    run rustup default stable
  fi
  info "Ensuring rust-analyzer component…"
  if [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] rustup component add rust-analyzer"
  else
    rustup component add rust-analyzer >/dev/null 2>&1 || warn "rust-analyzer component add skipped"
  fi

  if [[ "$DRY_RUN" != "1" ]]; then
    ok "node $(node -v 2>/dev/null)  python $(python --version 2>&1 | awk '{print $2}')  go $(go version 2>/dev/null | awk '{print $3}')  $(rustc --version 2>/dev/null)"
  fi
}
