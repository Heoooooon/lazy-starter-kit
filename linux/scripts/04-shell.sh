#!/usr/bin/env bash
# 04-shell.sh — zsh: oh-my-zsh, plugins, ~/.zshrc block, starship, default shell

OMZ_DIR="$HOME/.oh-my-zsh"
ZSH_CUSTOM_DIR="$OMZ_DIR/custom"

_clone_plugin() {
  local name="$1" url="$2" dest="$ZSH_CUSTOM_DIR/plugins/$1"
  if [[ -d "$dest" ]]; then
    ok "plugin present: $name"
  else
    info "cloning plugin: $name"
    run git clone --depth 1 "$url" "$dest"
  fi
}

step_shell() {
  step "Shell: oh-my-zsh + plugins + zsh config + prompt"
  load_local_bins

  have zsh || { warn "zsh not installed — run the 'prereqs' step first"; return 0; }

  # --- oh-my-zsh ---------------------------------------------------------
  if [[ -d "$OMZ_DIR" ]]; then
    ok "oh-my-zsh present"
  else
    info "Installing oh-my-zsh (keeps your existing .zshrc)…"
    if [[ "$DRY_RUN" == "1" ]]; then
      info "[dry-run] install oh-my-zsh (RUNZSH=no CHSH=no KEEP_ZSHRC=yes)"
    else
      RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    fi
  fi

  # --- plugins -----------------------------------------------------------
  if [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] clone zsh-autosuggestions + zsh-syntax-highlighting"
  else
    mkdir -p "$ZSH_CUSTOM_DIR/plugins"
    _clone_plugin zsh-autosuggestions     https://github.com/zsh-users/zsh-autosuggestions
    _clone_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting
  fi

  # --- ensure oh-my-zsh is sourced (only if user isn't already doing it) -
  if [[ "$DRY_RUN" != "1" ]] && ! grep -qs 'oh-my-zsh.sh' "$HOME/.zshrc" 2>/dev/null; then
    inject_block "$HOME/.zshrc" "lazy-starter-kit:ohmyzsh" <<'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""            # prompt handled by starship below
plugins=(git npm node)
source "$ZSH/oh-my-zsh.sh"
EOF
  fi

  # --- our zsh config block (mise, fzf, bat, cargo, bun, starship) -------
  if [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] inject 'lazy-starter-kit:main' block into ~/.zshrc"
  else
    inject_block "$HOME/.zshrc" "lazy-starter-kit:main" < "$ROOT/config/zshrc.block.sh"
  fi

  # --- starship preset (don't clobber a user's existing one) -------------
  if [[ -f "$HOME/.config/starship.toml" ]]; then
    ok "starship.toml present (left untouched)"
  elif [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] copy starship.toml -> ~/.config/starship.toml"
  else
    mkdir -p "$HOME/.config"
    cp "$ROOT/config/starship.toml" "$HOME/.config/starship.toml"
    ok "installed ~/.config/starship.toml"
  fi

  # --- make zsh the default login shell (opt-in) -------------------------
  local zsh_path; zsh_path="$(command -v zsh || true)"
  if [[ -n "$zsh_path" && "$SHELL" != *zsh ]]; then
    if [[ "$DRY_RUN" == "1" ]]; then
      info "[dry-run] chsh -s $zsh_path (make zsh the default shell)"
    elif confirm "Make zsh your default login shell?"; then
      # ensure the shell is registered in /etc/shells
      if ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
        run bash -c "echo '$zsh_path' | $SUDO tee -a /etc/shells >/dev/null" || true
      fi
      run chsh -s "$zsh_path" || warn "chsh failed — set your shell manually: chsh -s $zsh_path"
    else
      info "Left default shell as $SHELL. Switch later: chsh -s $zsh_path"
    fi
  fi
}
