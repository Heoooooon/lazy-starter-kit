#!/usr/bin/env bash
# 02-packages.sh — CLI tools (native pkg) + distro-agnostic tool installers.
#
# Strategy: install the plain CLI utilities from the distro (fast, cached),
# but pull the "moving target" developer tools (starship, mise, uv, bun,
# rustup) from their official user-space installers so we don't fight
# per-distro package naming/versions. Everything lands in $HOME — no sudo.

# distro-agnostic user-space installers -------------------------------------
_install_starship() {
  have starship && { ok "starship present"; return 0; }
  info "Installing starship (-> ~/.local/bin)…"
  if [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b ~/.local/bin"
  else
    mkdir -p "$HOME/.local/bin"
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin" \
      || warn "starship install failed"
  fi
}

_install_mise() {
  have mise && { ok "mise present"; return 0; }
  info "Installing mise (-> ~/.local/bin)…"
  if [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] curl -fsSL https://mise.run | sh"
  else
    curl -fsSL https://mise.run | sh || warn "mise install failed"
  fi
}

_install_uv() {
  have uv && { ok "uv present"; return 0; }
  info "Installing uv (-> ~/.local/bin)…"
  if [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] curl -LsSf https://astral.sh/uv/install.sh | sh"
  else
    curl -LsSf https://astral.sh/uv/install.sh | sh || warn "uv install failed"
  fi
}

_install_bun() {
  have bun && { ok "bun present"; return 0; }
  info "Installing bun (-> ~/.bun)…"
  if [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] curl -fsSL https://bun.sh/install | bash"
  else
    curl -fsSL https://bun.sh/install | bash || warn "bun install failed"
  fi
}

_install_rustup() {
  if have rustup; then ok "rustup present"; return 0; fi
  info "Installing rustup (-> ~/.cargo, ~/.rustup)…"
  if [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path"
  else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --no-modify-path || warn "rustup install failed"
  fi
}

# GitHub CLI — package name & availability vary; apt needs GitHub's own repo.
_install_gh() {
  have gh && { ok "gh (GitHub CLI) present"; return 0; }
  info "Installing gh (GitHub CLI)…"
  if [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] install gh (apt: add cli.github.com repo; else native package)"
    return 0
  fi
  case "$PM" in
    apt)
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | $SUDO tee /usr/share/keyrings/githubcli-archive-keyring.gpg >/dev/null
      $SUDO chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | $SUDO tee /etc/apt/sources.list.d/github-cli.list >/dev/null
      $SUDO apt-get update -y
      pm_try gh ;;
    dnf|yum|zypper) pm_try gh ;;
    pacman)         pm_try github-cli ;;
    apk)            pm_try github-cli ;;
  esac
}

step_packages() {
  step "CLI tools + developer toolchain installers"

  # --- plain CLI utilities from the distro ------------------------------
  # Best-effort per tool: names vary and older distros may lack some.
  info "Installing CLI utilities via $PM (best-effort)…"
  case "$PM" in
    apt)    pm_try ripgrep fd-find bat fzf jq tree ;;
    dnf|yum) pm_try ripgrep fd-find bat fzf jq tree ;;
    pacman) pm_try ripgrep fd bat fzf jq tree ;;
    zypper) pm_try ripgrep fd bat fzf jq tree ;;
    apk)    pm_try ripgrep fd bat fzf jq tree ;;
  esac
  # Debian/Ubuntu ship fd as `fdfind` and bat as `batcat`. Expose real
  # `fd`/`bat` commands via symlinks so they work in ANY shell/script — not
  # just the zsh aliases in the shell block.
  if [[ "$DRY_RUN" != "1" ]]; then
    mkdir -p "$HOME/.local/bin"
    if have fdfind && ! have fd;  then ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd";  fi
    if have batcat && ! have bat; then ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"; fi
  fi

  # --- distro-agnostic developer tools ----------------------------------
  _install_mise
  _install_starship
  _install_uv
  _install_bun
  _install_rustup
  _install_gh

  load_local_bins
  ok "packages step complete"
}
