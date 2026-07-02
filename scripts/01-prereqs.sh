#!/usr/bin/env bash
# 01-prereqs.sh — Xcode Command Line Tools + Homebrew

step_prereqs() {
  step "Prerequisites: Xcode CLT + Homebrew"

  # --- Xcode Command Line Tools (git, clang, make, headers) -------------
  if xcode-select -p >/dev/null 2>&1; then
    ok "Xcode Command Line Tools present ($(xcode-select -p))"
  else
    info "Installing Xcode Command Line Tools…"
    if [[ "$DRY_RUN" == "1" ]]; then
      info "[dry-run] xcode-select --install"
    else
      xcode-select --install >/dev/null 2>&1 || true
      info "A system dialog opened — click Install and wait for it to finish."
      # Bound the wait so a cancelled dialog can't spin forever (~30 min max).
      local waited=0 max=1800
      until xcode-select -p >/dev/null 2>&1; do
        if [[ "$waited" -ge "$max" ]]; then
          die "Timed out waiting for Command Line Tools. Install them manually (run 'xcode-select --install' or use Software Update), then re-run this script."
        fi
        sleep 15; waited=$((waited + 15))
        [[ $((waited % 60)) -eq 0 ]] && info "…still waiting for Command Line Tools (${waited}s elapsed)"
      done
      ok "Xcode Command Line Tools installed"
    fi
  fi

  # --- Homebrew ----------------------------------------------------------
  if [[ -x "$(brew_prefix)/bin/brew" ]]; then
    ok "Homebrew present ($(brew_prefix))"
  else
    info "Installing Homebrew…"
    if [[ "$DRY_RUN" == "1" ]]; then
      info "[dry-run] /bin/bash -c \"\$(curl -fsSL .../Homebrew/install/HEAD/install.sh)\""
    else
      NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      ok "Homebrew installed"
    fi
  fi

  load_brew

  # --- persist brew shellenv to ~/.zprofile (managed block) -------------
  local p; p="$(brew_prefix)"
  remove_block "$HOME/.zprofile" "macos-starter-kit:brew"   # migrate pre-rename block
  inject_block "$HOME/.zprofile" "lazy-starter-kit:brew" <<EOF
eval "\$($p/bin/brew shellenv)"
EOF
}
