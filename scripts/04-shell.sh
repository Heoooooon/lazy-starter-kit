#!/usr/bin/env bash
# 04-shell.sh — zsh: oh-my-zsh, plugins, ~/.zshrc block, starship, cmux font

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
  load_brew

  [[ "$SHELL" == */zsh ]] || warn "default shell is $SHELL (macOS default is zsh; run: chsh -s /bin/zsh)"

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
    inject_block "$HOME/.zshrc" "macos-starter-kit:ohmyzsh" <<'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""            # prompt handled by starship below
plugins=(git)
source "$ZSH/oh-my-zsh.sh"
EOF
  fi

  # --- our zsh config block (mise, fzf, bat, rustup, bun, starship) ------
  if [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] inject 'macos-starter-kit:main' block into ~/.zshrc"
  else
    inject_block "$HOME/.zshrc" "macos-starter-kit:main" < "$ROOT/config/zshrc.block.sh"
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

  # --- cmux terminal font (Ghostty-based terminal for AI coding agents) ---
  # cmux config is JSONC (allows // comments), so we never edit an existing
  # file (jq would choke on comments). We only seed a minimal config when
  # none exists; otherwise just point the user at the font.
  local cmux_cfg="$HOME/.config/cmux/cmux.json"
  if have cmux || [[ -e "$cmux_cfg" ]] || [[ -d /Applications/cmux.app ]]; then
    if [[ "$DRY_RUN" == "1" ]]; then
      info "[dry-run] ensure cmux uses 'JetBrainsMono Nerd Font Mono' (seed $cmux_cfg if absent)"
    elif [[ -e "$cmux_cfg" ]]; then
      info "cmux config exists — set \"fontFamily\": \"JetBrainsMono Nerd Font Mono\" in ~/.config/cmux/cmux.json (or via cmux settings)"
    else
      mkdir -p "$(dirname "$cmux_cfg")"
      cat > "$cmux_cfg" <<'EOF'
{
  "fontFamily": "JetBrainsMono Nerd Font Mono",
  "fontSize": 14
}
EOF
      ok "seeded ~/.config/cmux/cmux.json with the Nerd Font"
    fi
  else
    info "cmux not detected — Nerd Font is installed; set it in your terminal's settings"
  fi
}
