#!/usr/bin/env bash
# 04-shell.sh — zsh: oh-my-zsh, plugins, ~/.zshrc block, starship, default shell

OMZ_DIR="$HOME/.oh-my-zsh"
ZSH_CUSTOM_DIR="$OMZ_DIR/custom"

_clone_plugin() {
  local name="$1" url="$2" dest="$ZSH_CUSTOM_DIR/plugins/$1" i
  if [[ -d "$dest" ]]; then ok "plugin present: $name"; return 0; fi
  info "cloning plugin: $name"
  # Retry a few times: shallow clones over TLS occasionally flake mid-transfer.
  # A persistent failure only warns (non-fatal) so the whole install survives.
  for i in 1 2 3; do
    rm -rf "$dest"
    if run git clone --depth 1 "$url" "$dest"; then return 0; fi
    [[ "$i" -lt 3 ]] && { warn "clone $name attempt $i failed; retrying…"; sleep 2; }
  done
  warn "could not clone $name (skip; re-run the 'shell' step later)"
  return 0
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
      # Download to a file first: `sh -c "$(curl …)"` silently runs an empty
      # script (exit 0) if curl fails, which would then break the shell via the
      # injected 'source oh-my-zsh.sh' block. Verify the download AND the result.
      local omz_tmp; omz_tmp="$(mktemp)"
      if curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$omz_tmp" \
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

  # --- ensure oh-my-zsh is sourced (only if user isn't already doing it) -
  # Guard on the framework actually being present: injecting the source line
  # when the install failed would error on every new shell startup.
  if [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] would ensure oh-my-zsh is sourced in ~/.zshrc (lazy-starter-kit:ohmyzsh block)"
  elif [[ -d "$OMZ_DIR" ]] && ! grep -qs 'oh-my-zsh.sh' "$HOME/.zshrc" 2>/dev/null; then
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
