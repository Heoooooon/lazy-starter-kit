# Brewfile — declarative Homebrew manifest for lazy-starter-kit.
# Applied with: brew bundle --file Brewfile
# Safe to edit: add/remove lines, then re-run ./install.sh --only brew

# --- core dev CLI --------------------------------------------------------
brew "git"            # newer than Apple's bundled git
brew "gh"             # GitHub CLI (auth + HTTPS credential helper)
brew "jq"             # JSON processor
brew "ripgrep"        # rg — fast grep
brew "fd"             # fast find
brew "fzf"            # fuzzy finder (Ctrl-R / Ctrl-T)
brew "bat"            # cat with syntax highlighting
brew "tree"           # directory tree
brew "wget"           # downloader
brew "ast-grep"       # structural code search/rewrite

# --- system maintenance --------------------------------------------------
brew "mole"           # mo — clean / uninstall / analyze / optimize / monitor your Mac

# --- shell experience ----------------------------------------------------
brew "starship"       # cross-shell prompt

# --- runtime / version management ---------------------------------------
brew "mise"           # node / python / go (and more) version manager
brew "uv"             # fast Python package/installer manager
brew "rustup"         # Rust toolchain manager (stable installed in step 03)
brew "bun"            # JS runtime + package manager (used for gajae-code)

# --- containers ----------------------------------------------------------
brew "colima"         # lightweight container runtime (Docker without Desktop)
brew "docker"         # docker CLI
brew "docker-compose" # compose v2 plugin
brew "docker-buildx"  # buildx plugin

# --- fonts (Nerd Font for starship glyphs) ------------------------------
cask "font-jetbrains-mono-nerd-font"

# --- terminal (optional; comment out if you use another) ----------------
# orca: open-source Agent Development Environment (MIT, stablyai/orca) —
# runs Claude Code/Codex/etc. in parallel git worktrees, Ghostty-class
# terminal, scrollback survives restarts. Cask is sha256-pinned and ships
# the `orca` CLI. Swap for `cask "cmux"` or `cask "ghostty"` if you prefer
# a plain terminal.
tap  "stablyai/orca"
cask "orca"
