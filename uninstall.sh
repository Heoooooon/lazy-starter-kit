#!/usr/bin/env bash
#
# lazy-starter-kit — uninstaller. Reverses what install.sh set up, in reverse
# dependency order, idempotently. Destructive groups are confirm-gated.
#
# What it NEVER removes automatically (too system-wide / your data):
#   - Homebrew itself, Xcode Command Line Tools
#   - your git identity / config
#   - gajae-code (gjc) unless you pass --with-gajae
#
# Usage:
#   ./uninstall.sh [options]
#
# Options:
#   --dry-run          Show what would happen, change nothing.
#   --yes, -y          Non-interactive: accept every removal prompt.
#   --only  a,b,c      Run only these groups.
#   --skip  a,b,c      Run all groups except these.
#   --with-gajae       Also remove gajae-code (gjc). Refused if gjc is running.
#   --keep-codex-home  Keep ~/.codex (config/auth/sessions) when removing codex.
#   --list             List group ids and exit.
#   --version, -V      Print the kit version and exit.
#   --help, -h         Show this help.
#
# Groups (reverse order): agents shell docker runtimes brew
#
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SELF_DIR"
# shellcheck source=scripts/lib.sh
source "$ROOT/scripts/lib.sh"

KIT_VERSION="$(cat "$ROOT/VERSION" 2>/dev/null || echo dev)"
: "${WITH_GAJAE:=0}"
: "${KEEP_CODEX_HOME:=0}"

GROUP_IDS=(agents shell docker runtimes brew)

# usage — print the leading comment block (skip the shebang, stop at the first
# non-comment line) so --help never leaks code that follows the header.
usage() { awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$ROOT/uninstall.sh"; }

# ---------------------------------------------------------------------------
# agents — codex + lazycodex + Claude Code (+ optionally gajae-code)
# ---------------------------------------------------------------------------
undo_agents() {
  step "Remove AI agents (codex + lazycodex + Claude Code)"
  load_brew; load_mise
  export PATH="$HOME/.bun/bin:$PATH"

  # codex (npm global — plain npm IS the mise npm once load_mise ran)
  if have npm && npm ls -g --depth=0 2>/dev/null | grep -q '@openai/codex'; then
    info "Uninstalling @openai/codex…"
    run npm uninstall -g @openai/codex
    have mise && run mise reshim
  else
    info "codex npm package not installed"
  fi

  # lazycodex npx cache
  local d found=0
  for d in "$HOME"/.npm/_npx/*/node_modules/lazycodex-ai; do
    [[ -e "$d" ]] || continue
    found=1
    run rm -rf "$(dirname "$(dirname "$d")")"
  done
  [[ "$found" == 1 ]] && ok "cleared lazycodex npx cache" || info "no lazycodex npx cache"

  # ~/.codex home (config, auth, sessions, omo plugin)
  if [[ -d "$HOME/.codex" && "$KEEP_CODEX_HOME" != "1" ]]; then
    if confirm "Remove ~/.codex (codex home: config, auth, sessions, omo plugin)?"; then
      if [[ -f "$HOME/.codex/auth.json" ]]; then
        local bak; bak="$HOME/codex-auth-backup-$(date +%Y%m%d-%H%M%S).json"
        if [[ "$DRY_RUN" == "1" ]]; then
          info "[dry-run] would back up auth.json -> ${bak/#$HOME/~}"
        else
          cp -p "$HOME/.codex/auth.json" "$bak" && ok "backed up auth.json -> ${bak/#$HOME/~}"
        fi
      fi
      run rm -rf "$HOME/.codex"
    else
      info "kept ~/.codex"
    fi
  fi
  if [[ -d "$HOME/.cache/codex-runtimes" ]]; then
    if confirm "Remove ~/.cache/codex-runtimes (downloaded codex runtime, large)?"; then
      run rm -rf "$HOME/.cache/codex-runtimes"
    else
      info "kept ~/.cache/codex-runtimes"
    fi
  fi

  # Hermes Agent — remove command shim + (confirm) data dir
  if have hermes || [[ -d "$HOME/.hermes" ]]; then
    run rm -f "$HOME/.local/bin/hermes"
    # node/npm/npx in ~/.local/bin only if they symlink into ~/.hermes
    local b tgt
    for b in node npm npx; do
      tgt="$HOME/.local/bin/$b"
      if [[ -L "$tgt" ]] && readlink "$tgt" 2>/dev/null | grep -q "/.hermes/"; then
        run rm -f "$tgt"
      fi
    done
    if [[ -d "$HOME/.hermes" ]]; then
      if confirm "Remove ~/.hermes (Hermes code, data, sessions)?"; then
        run rm -rf "$HOME/.hermes"
      else
        info "kept ~/.hermes"
      fi
    fi
    ok "Hermes Agent removed"
  else
    info "Hermes Agent not installed"
  fi

  # Antigravity CLI (opt-in install: ANTIGRAVITY=1) — remove the agy binary
  if [[ -e "$HOME/.local/bin/agy" ]]; then
    run rm -f "$HOME/.local/bin/agy"
    ok "Antigravity CLI removed"
  fi

  # Claude Code — native install is ours, remove it unconditionally
  if [[ -e "$HOME/.local/bin/claude" || -d "$HOME/.local/share/claude" ]]; then
    run rm -f  "$HOME/.local/bin/claude"
    run rm -rf "$HOME/.local/share/claude"
    ok "Claude Code removed"
  else
    info "Claude Code not installed"
  fi
  # user data (settings, history, MCP config, auth) — confirm-gated
  if [[ -d "$HOME/.claude" || -f "$HOME/.claude.json" ]]; then
    if confirm "Remove ~/.claude and ~/.claude.json (Claude Code settings, history, auth)?"; then
      if [[ -f "$HOME/.claude.json" ]]; then
        local ccbak; ccbak="$HOME/claude-json-backup-$(date +%Y%m%d-%H%M%S).json"
        if [[ "$DRY_RUN" == "1" ]]; then
          info "[dry-run] would back up ~/.claude.json -> ${ccbak/#$HOME/~}"
        else
          cp -p "$HOME/.claude.json" "$ccbak" && ok "backed up ~/.claude.json -> ${ccbak/#$HOME/~}"
        fi
      fi
      run rm -rf "$HOME/.claude"
      run rm -f  "$HOME/.claude.json"
    else
      info "kept ~/.claude"
    fi
  fi

  # gajae-code (gjc) — protected by default
  if [[ "$WITH_GAJAE" == "1" ]]; then
    if pgrep -f '/.bun/bin/gjc' >/dev/null 2>&1; then
      warn "gjc is RUNNING — refusing to remove gajae-code (close the session, then re-run)"
    elif have gjc; then
      info "Removing gajae-code…"
      run bun remove -g gajae-code
    else
      info "gajae-code not installed"
    fi
  else
    info "Keeping gajae-code (pass --with-gajae to remove)"
  fi
}

# ---------------------------------------------------------------------------
# shell — managed blocks + (optional) oh-my-zsh / starship.toml
# ---------------------------------------------------------------------------
undo_shell() {
  step "Revert shell configuration"
  remove_block "$HOME/.zshrc"            "lazy-starter-kit:main"
  remove_block "$HOME/.zshrc"            "lazy-starter-kit:ohmyzsh"
  remove_block "$HOME/.zprofile"         "lazy-starter-kit:brew"
  remove_block "$HOME/.config/ghostty/config" "lazy-starter-kit:ghostty"
  # also strip legacy 'macos-starter-kit:*' blocks (installs from before the rename)
  remove_block "$HOME/.zshrc"            "macos-starter-kit:main"
  remove_block "$HOME/.zshrc"            "macos-starter-kit:ohmyzsh"
  remove_block "$HOME/.zprofile"         "macos-starter-kit:brew"
  remove_block "$HOME/.config/ghostty/config" "macos-starter-kit:ghostty"

  if [[ -f "$HOME/.config/starship.toml" ]]; then
    if confirm "Remove ~/.config/starship.toml?"; then run rm -f "$HOME/.config/starship.toml"
    else info "kept starship.toml"; fi
  fi
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    if confirm "Remove ~/.oh-my-zsh (framework + plugins)?"; then run rm -rf "$HOME/.oh-my-zsh"
    else info "kept oh-my-zsh"; fi
  fi
}

# ---------------------------------------------------------------------------
# docker — Colima VM + docker plugin config entry
# ---------------------------------------------------------------------------
undo_docker() {
  step "Remove containers (Colima VM + docker config entry)"
  load_brew
  if have colima && colima list 2>/dev/null | grep -q colima; then
    if confirm "Stop and delete the Colima VM (containers & images lost)?"; then
      run colima stop || true
      run colima delete --force || true
    else
      info "kept Colima VM"
    fi
  else
    info "no Colima VM"
  fi

  local cfg="$HOME/.docker/config.json" pdir; pdir="$(brew_prefix)/lib/docker/cli-plugins"
  if [[ -f "$cfg" ]] && have jq && grep -q cliPluginsExtraDirs "$cfg" 2>/dev/null; then
    if [[ "$DRY_RUN" == "1" ]]; then
      info "[dry-run] would remove $pdir from $cfg"
    else
      local tmp; tmp="$(mktemp)"
      jq --arg d "$pdir" '(.cliPluginsExtraDirs) |= (map(select(. != $d)))' "$cfg" > "$tmp" && mv "$tmp" "$cfg"
      ok "removed plugin dir from docker config"
    fi
  fi
}

# ---------------------------------------------------------------------------
# runtimes — mise tools + rustup
# ---------------------------------------------------------------------------
undo_runtimes() {
  step "Remove language runtimes (mise node/python/go + rustup)"
  load_brew
  if have mise; then
    if confirm "Remove mise-managed node/python/go (versions + global config entries)?"; then
      if [[ "$DRY_RUN" == "1" ]]; then
        info "[dry-run] mise uninstall node python go ; mise rm -g node python go"
      else
        mise uninstall node python go 2>/dev/null || true
        local t; for t in node python go; do mise rm -g "$t" 2>/dev/null || true; done
        ok "removed mise runtimes"
      fi
    else
      info "kept mise runtimes"
    fi
  fi
  if have rustup; then
    if confirm "Uninstall Rust (rustup self uninstall)?"; then
      if [[ "$DRY_RUN" == "1" ]]; then info "[dry-run] rustup self uninstall -y"
      else rustup self uninstall -y || true; ok "rust uninstalled"; fi
    else
      info "kept rust/rustup"
    fi
  fi
}

# ---------------------------------------------------------------------------
# brew — uninstall everything listed in the Brewfile
# ---------------------------------------------------------------------------
undo_brew() {
  step "Uninstall Homebrew packages listed in the Brewfile"
  load_brew
  have brew || { warn "brew not found"; return 0; }
  local bf="$ROOT/Brewfile"
  [[ -f "$bf" ]] || { warn "no Brewfile at $bf"; return 0; }

  if ! confirm "Uninstall all formulae/casks in the Brewfile? (Homebrew itself stays)"; then
    info "kept brew packages"; return 0
  fi
  local f
  for f in $(grep -E '^brew "' "$bf" | sed -E 's/^brew "([^"]+)".*/\1/'); do
    run brew uninstall "$f" 2>/dev/null || warn "skip $f (missing, in use, or has dependents)"
  done
  for f in $(grep -E '^cask "' "$bf" | sed -E 's/^cask "([^"]+)".*/\1/'); do
    run brew uninstall --cask "$f" 2>/dev/null || warn "skip cask $f"
  done
  # sweep orphaned dependencies the Brewfile packages pulled in (e.g. node@24)
  run brew autoremove
  ok "Brewfile packages processed"
}

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------
ONLY=""; SKIP=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)         export DRY_RUN=1 ;;
    -y|--yes)          export ASSUME_YES=1 ;;
    --only)            ONLY="${2:-}"; shift ;;
    --only=*)          ONLY="${1#*=}" ;;
    --skip)            SKIP="${2:-}"; shift ;;
    --skip=*)          SKIP="${1#*=}" ;;
    --with-gajae)      export WITH_GAJAE=1 ;;
    --keep-codex-home) export KEEP_CODEX_HOME=1 ;;
    --list)            printf '%s\n' "${GROUP_IDS[@]}"; exit 0 ;;
    -V|--version)      echo "lazy-starter-kit $KIT_VERSION"; exit 0 ;;
    -h|--help)         usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
  shift
done

# Normalize --only/--skip (strip spaces so `--only "shell, brew"` works), then
# reject any unknown token up front instead of silently selecting nothing.
ONLY="${ONLY// /}"; SKIP="${SKIP// /}"
_validate_ids() {
  local list="$1" tok id found valid="${GROUP_IDS[*]}"
  while [[ -n "$list" ]]; do
    tok="${list%%,*}"
    if [[ "$list" == *,* ]]; then list="${list#*,}"; else list=""; fi
    [[ -z "$tok" ]] && continue
    found=0
    for id in "${GROUP_IDS[@]}"; do [[ "$id" == "$tok" ]] && found=1; done
    [[ "$found" == 1 ]] || die "unknown group id: '$tok' (valid: $valid)"
  done
}
[[ -n "$ONLY" ]] && _validate_ids "$ONLY"
[[ -n "$SKIP" ]] && _validate_ids "$SKIP"

selected() {
  local id keep
  for id in "${GROUP_IDS[@]}"; do
    if [[ -n "$ONLY" ]]; then
      [[ ",$ONLY," == *",$id,"* ]] && echo "$id"
    else
      keep=1
      [[ -n "$SKIP" && ",$SKIP," == *",$id,"* ]] && keep=0
      [[ "$keep" == 1 ]] && echo "$id"
    fi
  done
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
is_macos || die "macOS only."
[[ "$DRY_RUN" == "1" ]] && warn "DRY-RUN: no changes will be made."

printf '%s\n' "$_C_BOLD== lazy-starter-kit v$KIT_VERSION · uninstall ==$_C_RESET"
info "groups: $(selected | tr '\n' ' ')"
warn "Homebrew, Xcode CLT, and your git identity are left untouched (remove manually if desired)."

for id in $(selected); do
  "undo_$id"
done

step "Uninstall complete."
ok "Restart your terminal. To fully reset prereqs, remove Homebrew/Xcode CLT manually."
[[ "$DRY_RUN" == "1" ]] && info "That was a dry run — re-run without --dry-run to apply."
exit 0
