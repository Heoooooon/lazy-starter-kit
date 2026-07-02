#!/usr/bin/env bash
#
# lazy-starter-kit — uninstaller. Reverses what install.sh set up, in reverse
# dependency order, idempotently. Destructive groups are confirm-gated.
#
# What it NEVER removes automatically:
#   - your git identity / config
#   - system compiler/build tools installed by 'prereqs'
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
# Groups (reverse order): agents shell docker runtimes packages
#
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SELF_DIR"
# shellcheck source=scripts/lib.sh
source "$ROOT/scripts/lib.sh"

KIT_VERSION="$(cat "$ROOT/../VERSION" 2>/dev/null || echo dev)"
: "${WITH_GAJAE:=0}"
: "${KEEP_CODEX_HOME:=0}"

GROUP_IDS=(agents shell docker runtimes packages)

# usage — print the leading comment block (skip the shebang, stop at the first
# non-comment line) so --help never leaks code that follows the header.
usage() { awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$ROOT/uninstall.sh"; }

# ---------------------------------------------------------------------------
# agents — codex + lazycodex + Hermes (+ optionally gajae-code)
# ---------------------------------------------------------------------------
undo_agents() {
  step "Remove AI agents (codex + lazycodex + Hermes)"
  load_local_bins; load_mise
  export PATH="$HOME/.bun/bin:$PATH"

  # codex (npm global — plain npm IS the mise npm once load_mise ran)
  if have npm && npm ls -g --depth=0 2>/dev/null | grep -q '@openai/codex'; then
    info "Uninstalling @openai/codex…"
    run npm uninstall -g @openai/codex
    have mise && run mise reshim
  else
    info "codex npm package not installed"
  fi

  local d found=0
  for d in "$HOME"/.npm/_npx/*/node_modules/lazycodex-ai; do
    [[ -e "$d" ]] || continue
    found=1
    run rm -rf "$(dirname "$(dirname "$d")")"
  done
  [[ "$found" == 1 ]] && ok "cleared lazycodex npx cache" || info "no lazycodex npx cache"

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

  # Hermes Agent — remove command shim + (confirm) data dir
  if have hermes || [[ -d "$HOME/.hermes" ]]; then
    run rm -f "$HOME/.local/bin/hermes"
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
  remove_block "$HOME/.zshrc"    "lazy-starter-kit:main"
  remove_block "$HOME/.zshrc"    "lazy-starter-kit:ohmyzsh"

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
# docker — remove Docker Engine (native packages)
# ---------------------------------------------------------------------------
undo_docker() {
  step "Remove containers (Docker Engine)"
  if ! have docker; then info "docker not installed"; return 0; fi
  if confirm "Uninstall Docker Engine (docker-ce + compose/buildx; containers & images lost)?"; then
    if have systemctl; then run $SUDO systemctl disable --now docker 2>/dev/null || true; fi
    case "$PM" in
      apt)    pm_remove docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker.io ;;
      dnf|yum) pm_remove docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin ;;
      pacman) pm_remove docker docker-compose docker-buildx ;;
      zypper) pm_remove docker docker-compose ;;
      apk)    pm_remove docker docker-cli-compose ;;
    esac
    ok "Docker removed (your user's docker group membership is left as-is)"
  else
    info "kept Docker"
  fi
}

# ---------------------------------------------------------------------------
# runtimes — mise tools + rustup
# ---------------------------------------------------------------------------
undo_runtimes() {
  step "Remove language runtimes (mise node/python/go + rustup)"
  load_local_bins
  if have mise; then
    if confirm "Remove mise-managed node/python/go/ast-grep (versions + global config)?"; then
      if [[ "$DRY_RUN" == "1" ]]; then
        info "[dry-run] mise uninstall node python go ; mise rm -g node python go ast-grep"
      else
        mise uninstall node python go 2>/dev/null || true
        local t; for t in node python go "ubi:ast-grep/ast-grep"; do mise rm -g "$t" 2>/dev/null || true; done
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
# packages — user-space dev tools + (optional) native CLI utilities
# ---------------------------------------------------------------------------
undo_packages() {
  step "Remove developer tools (mise/starship/uv/bun) + CLI utilities"

  # user-space tool installs (all under $HOME)
  if confirm "Remove user-space tools mise/starship/uv/bun and their homes?"; then
    run rm -f  "$HOME/.local/bin/mise" "$HOME/.local/bin/starship" \
               "$HOME/.local/bin/uv" "$HOME/.local/bin/uvx"
    run rm -rf "$HOME/.local/share/mise" "$HOME/.config/mise" "$HOME/.cache/mise"
    run rm -rf "$HOME/.bun"
    ok "removed mise/starship/uv/bun"
  else
    info "kept user-space tools"
  fi

  # native CLI utilities via package manager
  if confirm "Uninstall CLI utilities (ripgrep, fd, bat, fzf, jq, tree, gh) via $PM?"; then
    case "$PM" in
      apt)     pm_remove ripgrep fd-find bat fzf jq tree gh ;;
      dnf|yum) pm_remove ripgrep fd-find bat fzf jq tree gh ;;
      pacman)  pm_remove ripgrep fd bat fzf jq tree github-cli ;;
      zypper)  pm_remove ripgrep fd bat fzf jq tree gh ;;
      apk)     pm_remove ripgrep fd bat fzf jq tree github-cli ;;
    esac
    # drop the fd/bat compatibility symlinks we created on Debian/Ubuntu
    for l in fd bat; do [[ -L "$HOME/.local/bin/$l" ]] && run rm -f "$HOME/.local/bin/$l" || true; done
    ok "CLI utilities processed"
  else
    info "kept CLI utilities"
  fi
  info "Build tools (gcc/make) from 'prereqs' are left installed — remove manually if desired."
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

# Normalize --only/--skip (strip spaces so `--only "shell, packages"` works),
# then reject any unknown token up front instead of silently selecting nothing.
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
is_linux || die "Linux only."
[[ "$DRY_RUN" == "1" ]] && warn "DRY-RUN: no changes will be made."

printf '%s\n' "$_C_BOLD== lazy-starter-kit v$KIT_VERSION · uninstall ==$_C_RESET"
info "groups: $(selected | tr '\n' ' ')"
warn "Your git identity and system build tools are left untouched (remove manually if desired)."

for id in $(selected); do
  "undo_$id"
done

step "Uninstall complete."
ok "Restart your terminal to load a clean environment."
[[ "$DRY_RUN" == "1" ]] && info "That was a dry run — re-run without --dry-run to apply."
exit 0
