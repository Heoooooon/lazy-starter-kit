# managed by lazy-starter-kit — edits between the markers are overwritten on re-run.

# ~/.local/bin: user-local commands (mise, starship, uv, hermes …)
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"

# mise: node / python / go version manager
command -v mise >/dev/null && eval "$(mise activate zsh)"

# rust (rustup / cargo): cargo / rustc / rust-analyzer
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
[ -d "$HOME/.cargo/bin" ] && export PATH="$HOME/.cargo/bin:$PATH"

# bun: global packages (e.g. gjc / gajae-code) live in ~/.bun/bin
export BUN_INSTALL="$HOME/.bun"
[ -d "$BUN_INSTALL/bin" ] && export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"

# oh-my-zsh plugins (sourced directly so they work regardless of plugins=() line)
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
[ -f "$ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ] \
  && source "$ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
[ -f "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] \
  && source "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"

# Debian/Ubuntu ship these under alternate names — alias them back
command -v batcat >/dev/null && ! command -v bat >/dev/null && alias bat='batcat'
command -v fdfind >/dev/null && ! command -v fd  >/dev/null && alias fd='fdfind'

# fzf: fuzzy finder keybindings + completion (Ctrl-R history, Ctrl-T files)
if command -v fzf >/dev/null; then
  if fzf --zsh >/dev/null 2>&1; then
    source <(fzf --zsh)
  else
    [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh
    [ -f /usr/share/doc/fzf/examples/completion.zsh ]   && source /usr/share/doc/fzf/examples/completion.zsh
    [ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
    [ -f /usr/share/fzf/completion.zsh ]   && source /usr/share/fzf/completion.zsh
  fi
fi

# bat: nicer cat
command -v bat >/dev/null && alias cat='bat --paging=never'

# starship prompt — keep LAST so it owns the prompt
command -v starship >/dev/null && eval "$(starship init zsh)"
