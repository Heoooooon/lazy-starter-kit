#!/usr/bin/env bash
# 04-shell.sh — zsh: oh-my-zsh, plugins, ~/.zshrc block, starship, terminal font

OMZ_DIR="$HOME/.oh-my-zsh"
ZSH_CUSTOM_DIR="$OMZ_DIR/custom"

# Pin ohmyzsh's tools/install.sh (the bootstrap script we execute) to an
# immutable, reviewable commit instead of the moving 'master' branch, so the
# code we pipe into sh can't change under us. To bump: set this to a newer
# ohmyzsh/ohmyzsh commit SHA and confirm the raw URL below serves 200 for it.
# NOTE: this pins only the bootstrap script — oh-my-zsh itself still clones its
# own current master when it installs.
OMZ_INSTALLER_REF="ff2f16e8df7386d7198009566aef09cbbc0c8212"  # 2026-07-01

_clone_plugin() {
  local name="$1" url="$2" dest="$ZSH_CUSTOM_DIR/plugins/$1" i
  if [[ -d "$dest" ]]; then ok "plugin present: $name"; return 0; fi
  info "cloning plugin: $name"
  # Retry a few times: shallow clones over TLS occasionally flake mid-transfer.
  # A persistent failure only warns (non-fatal) so the whole install survives.
  for i in 1 2 3; do
    safe_rm_rf_under "$ZSH_CUSTOM_DIR/plugins" "$dest"
    if run git clone --depth 1 "$url" "$dest"; then return 0; fi
    [[ "$i" -lt 3 ]] && { warn "clone $name attempt $i failed; retrying…"; sleep 2; }
  done
  warn "could not clone $name (skip; re-run the 'shell' step later)"
  return 0
}

step_shell() {
  local zshrc zshrc_q
  zshrc="$(zsh_config_file .zshrc)"
  zshrc_q="$(shell_quote "$zshrc")"
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
      # Download to a file first: `sh -c "$(curl …)"` silently runs an empty
      # script (exit 0) if curl fails, which would then break the shell via the
      # injected 'source oh-my-zsh.sh' block. Verify the download AND the result.
      local omz_tmp; omz_tmp="$(mktemp)"
      if curl -fsSL "https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/${OMZ_INSTALLER_REF}/tools/install.sh" -o "$omz_tmp" \
         && [[ -s "$omz_tmp" ]]; then
        RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh "$omz_tmp" || warn "oh-my-zsh installer did not complete"
      else
        warn "could not download the oh-my-zsh installer (network?) — skipping oh-my-zsh"
      fi
      rm -f "$omz_tmp"
      [[ -d "$OMZ_DIR" ]] || warn "oh-my-zsh not installed — the shell config will skip its oh-my-zsh block"
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

  # --- migrate: strip legacy 'macos-starter-kit:*' blocks (pre-rename installs)
  # so a re-run replaces cleanly instead of leaving a duplicate block behind.
  remove_block "$zshrc" "macos-starter-kit:main"
  remove_block "$zshrc" "macos-starter-kit:ohmyzsh"
  if [[ "$zshrc" != "$HOME/.zshrc" ]]; then
    remove_block "$HOME/.zshrc" "macos-starter-kit:main"
    remove_block "$HOME/.zshrc" "macos-starter-kit:ohmyzsh"
    remove_block "$HOME/.zshrc" "lazy-starter-kit:main"
    remove_block "$HOME/.zshrc" "lazy-starter-kit:ohmyzsh"
  fi

  # --- ensure oh-my-zsh is sourced (only if user isn't already doing it) -
  # Guard on the framework actually being present: injecting the source line
  # when the install failed would error on every new shell startup.
  if [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] would ensure oh-my-zsh is sourced in $zshrc_q (lazy-starter-kit:ohmyzsh block)"
  elif [[ -d "$OMZ_DIR" ]] && ! grep -qs 'oh-my-zsh.sh' "$zshrc" 2>/dev/null; then
    inject_block "$zshrc" "lazy-starter-kit:ohmyzsh" <<'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""            # prompt handled by starship below
plugins=(git npm node macos)
source "$ZSH/oh-my-zsh.sh"
EOF
  fi

  # --- our zsh config block (mise, fzf, bat, rustup, bun, starship) ------
  if [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] inject 'lazy-starter-kit:main' block into $zshrc_q"
  else
    inject_block "$zshrc" "lazy-starter-kit:main" < "$ROOT/config/zshrc.block.sh"
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

  # --- terminal font (orca / cmux) ----------------------------------------
  # orca (the kit's default terminal cask): fonts live in its in-app settings,
  # not a stable config file — so we only point the user there. cmux (the
  # previous default, still handled for existing installs): config is JSONC
  # (allows // comments), so we never edit an existing file (jq would choke);
  # we only seed a minimal config when none exists.
  local orca_found=0
  if [[ -d /Applications/Orca.app ]] || have orca; then
    orca_found=1
    info "orca detected — for prompt icons set its terminal font to 'JetBrainsMono Nerd Font Mono' (Orca settings)"
  fi
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
  elif [[ "$orca_found" == 0 ]]; then
    info "no kit terminal detected — Nerd Font is installed; set it in your terminal's settings"
  fi
}
