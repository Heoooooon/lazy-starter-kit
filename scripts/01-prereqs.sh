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
      info '[dry-run] download and run the official Homebrew installer'
    else
      local brew_installer brew_status
      brew_installer="$(mktemp)"
      brew_status=0

      # Download first and validate the minimum expected shape before running.
      if ! curl -fsSL \
        https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh \
        -o "$brew_installer"; then
        rm -f "$brew_installer"
        die "Could not download the Homebrew installer."
      fi

      if [[ ! -s "$brew_installer" ]] ||
         ! head -1 "$brew_installer" | grep -q '^#!/bin/bash'; then
        rm -f "$brew_installer"
        die "Downloaded Homebrew installer is invalid."
      fi

      if [[ "$ASSUME_YES" == "1" ]]; then
        # Fully non-interactive: suitable when Homebrew is already installed
        # or sudo authentication has been prepared by the caller.
        info "Installing Homebrew non-interactively…"
        NONINTERACTIVE=1 /bin/bash "$brew_installer" ||
          brew_status=$?

      elif ( : </dev/tty ) 2>/dev/null; then
        # Keep password/confirmation prompts attached to the real terminal
        # even when lazy-starter-kit itself was started with `curl | bash`.
        info "Homebrew may request your macOS administrator password."
        INTERACTIVE=1 /bin/bash "$brew_installer" </dev/tty ||
          brew_status=$?

      else
        rm -f "$brew_installer"
        die "Homebrew installation requires an interactive terminal. Run ./install.sh from Terminal."
      fi

      rm -f "$brew_installer"

      if [[ "$brew_status" -ne 0 ]]; then
        die "Homebrew installation failed with exit code $brew_status."
      fi

      ok "Homebrew installed"
    fi
  fi

  load_brew

  local p zprofile; p="$(brew_prefix)"; zprofile="$(zsh_config_file .zprofile)"
  remove_block "$zprofile" "macos-starter-kit:brew"   # migrate pre-rename block
  if [[ "$zprofile" != "$HOME/.zprofile" ]]; then
    remove_block "$HOME/.zprofile" "macos-starter-kit:brew"
    remove_block "$HOME/.zprofile" "lazy-starter-kit:brew"
  fi
  inject_block "$zprofile" "lazy-starter-kit:brew" <<EOF
eval "\$($p/bin/brew shellenv)"
EOF
}
