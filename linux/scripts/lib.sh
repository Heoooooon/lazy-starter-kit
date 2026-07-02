#!/usr/bin/env bash
# lib.sh — shared helpers for lazy-starter-kit
# sourced by install.sh and every scripts/NN-*.sh step.

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
  _C_RESET=$'\033[0m'; _C_DIM=$'\033[2m'; _C_RED=$'\033[31m'
  _C_GREEN=$'\033[32m'; _C_YELLOW=$'\033[33m'; _C_BLUE=$'\033[34m'; _C_BOLD=$'\033[1m'
else
  _C_RESET=''; _C_DIM=''; _C_RED=''; _C_GREEN=''; _C_YELLOW=''; _C_BLUE=''; _C_BOLD=''
fi

step()  { printf '\n%s==>%s %s%s%s\n' "$_C_BLUE$_C_BOLD" "$_C_RESET" "$_C_BOLD" "$*" "$_C_RESET"; }
info()  { printf '%s  •%s %s\n' "$_C_DIM" "$_C_RESET" "$*"; }
ok()    { printf '%s  ✓%s %s\n' "$_C_GREEN" "$_C_RESET" "$*"; }
warn()  { printf '%s  !%s %s\n' "$_C_YELLOW" "$_C_RESET" "$*" >&2; }
err()   { printf '%s  ✗%s %s\n' "$_C_RED" "$_C_RESET" "$*" >&2; }
die()   { err "$*"; exit 1; }

# ---------------------------------------------------------------------------
# Environment flags (exported by install.sh)
# ---------------------------------------------------------------------------
: "${DRY_RUN:=0}"    # 1 = print actions, do not execute
: "${ASSUME_YES:=0}" # 1 = never prompt, take defaults

# run CMD...  — execute, or just print under DRY_RUN
run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '%s  [dry-run]%s %s\n' "$_C_DIM" "$_C_RESET" "$*"
    return 0
  fi
  "$@"
}

# ---------------------------------------------------------------------------
# Predicates
# ---------------------------------------------------------------------------
have()        { command -v "$1" >/dev/null 2>&1; }
is_tty()      { [[ -t 0 ]]; }
is_linux()    { [[ "$(uname -s)" == "Linux" ]]; }

# ---------------------------------------------------------------------------
# Privilege escalation — pick sudo only when needed & available
# ---------------------------------------------------------------------------
# SUDO is "" when we are root or when sudo is missing; system package installs
# use "$SUDO" so a rootless/CI environment degrades gracefully.
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  SUDO=""
elif have sudo; then
  SUDO="sudo"
else
  SUDO=""
fi

# can_sudo — true when system package installs can actually escalate:
#   * we are root, OR
#   * sudo exists AND we can obtain privileges (cached creds / NOPASSWD, or a
#     tty to prompt on). A non-interactive box where `sudo -n true` fails cannot
#     escalate, so callers should skip system packages instead of aborting.
can_sudo() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] && return 0
  [[ -n "$SUDO" ]] || return 1
  sudo -n true >/dev/null 2>&1 && return 0   # passwordless / cached creds
  is_tty                                      # otherwise we need a tty to prompt
}

# ---------------------------------------------------------------------------
# Distro / package-manager detection
# ---------------------------------------------------------------------------
# PM is one of: apt dnf yum pacman zypper apk  (empty if unknown)
detect_pm() {
  if have apt-get;  then echo apt
  elif have dnf;    then echo dnf
  elif have yum;    then echo yum
  elif have pacman; then echo pacman
  elif have zypper; then echo zypper
  elif have apk;    then echo apk
  else echo ""; fi
}
PM="$(detect_pm)"

# distro_id — the ID= field from /etc/os-release (ubuntu, debian, fedora, arch…)
distro_id() {
  [[ -r /etc/os-release ]] || { echo unknown; return; }
  # shellcheck disable=SC1091
  ( . /etc/os-release; echo "${ID:-unknown}" )
}

# pm_refresh — update the package index once (best effort)
_PM_REFRESHED=0
pm_refresh() {
  [[ "$_PM_REFRESHED" == "1" ]] && return 0
  _PM_REFRESHED=1
  case "$PM" in
    apt)    run $SUDO apt-get update -y || true ;;
    dnf)    run $SUDO dnf -y makecache || true ;;
    yum)    run $SUDO yum -y makecache || true ;;
    # Arch: a full -Syu is required — installing after a bare -Sy is a
    # partial upgrade (unsupported, can break glibc/openssl mismatches). We
    # therefore never do a bare -Sy. A full upgrade touches the whole system,
    # so it's confirm-gated (auto-yes under --yes, declined non-interactively).
    # Declined path: skip the refresh entirely and let the later `pacman -S`
    # installs run against the CURRENT sync DBs — this avoids the partial-
    # upgrade hazard at the cost of possibly-staler package versions.
    pacman)
      if confirm "Arch requires a full system upgrade (pacman -Syu) before installing. Run it now?"; then
        run $SUDO pacman -Syu --noconfirm || true
      else
        warn "skipping 'pacman -Syu' — installs will use the current sync DBs (no partial-upgrade refresh)"
      fi ;;
    zypper) run $SUDO zypper --non-interactive refresh || true ;;
    apk)    run $SUDO apk update || true ;;
    *)      warn "no supported package manager detected" ;;
  esac
}

# pm_install PKG...  — install one or more system packages (non-interactive)
pm_install() {
  [[ $# -gt 0 ]] || return 0
  pm_refresh   # refresh the package index once (no-op after the first call)
  case "$PM" in
    apt)    run $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@" ;;
    dnf)    run $SUDO dnf install -y "$@" ;;
    yum)    run $SUDO yum install -y "$@" ;;
    pacman) run $SUDO pacman -S --needed --noconfirm "$@" ;;
    zypper) run $SUDO zypper --non-interactive install --no-recommends "$@" ;;
    apk)    run $SUDO apk add "$@" ;;
    *)      warn "cannot install ($*): unknown package manager"; return 1 ;;
  esac
}

# pm_try PKG...  — best-effort install; a failure only warns (used for optional
# CLI tools whose package name may not exist on every distro).
pm_try() {
  pm_install "$@" || warn "could not install via $PM: $* (skipping)"
}

# pm_remove PKG...  — remove system packages (used by the uninstaller)
pm_remove() {
  [[ $# -gt 0 ]] || return 0
  case "$PM" in
    apt)    run $SUDO env DEBIAN_FRONTEND=noninteractive apt-get remove -y "$@" || true ;;
    dnf)    run $SUDO dnf remove -y "$@" || true ;;
    yum)    run $SUDO yum remove -y "$@" || true ;;
    pacman) run $SUDO pacman -Rns --noconfirm "$@" || true ;;
    zypper) run $SUDO zypper --non-interactive remove "$@" || true ;;
    apk)    run $SUDO apk del "$@" || true ;;
  esac
}

# load user-local bins for the current process, so freshly-installed tools
# (mise, starship, uv, bun, cargo) are visible to later steps immediately.
load_local_bins() {
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.bun/bin:$PATH"
  [[ -d "$HOME/.local/share/mise/shims" ]] && export PATH="$HOME/.local/share/mise/shims:$PATH"
  return 0   # never fail under `set -e` (trailing test may be false)
}

# load mise shims into PATH for the current process
load_mise() {
  have mise && eval "$(mise activate bash --shims)" 2>/dev/null || true
  export PATH="$HOME/.local/share/mise/shims:$PATH"
}

# ---------------------------------------------------------------------------
# Prompts
# ---------------------------------------------------------------------------
# ask "Question?" "default"  -> echoes the answer (default under ASSUME_YES / no tty)
ask() {
  local q="$1" def="${2:-}"
  if [[ "$ASSUME_YES" == "1" ]] || ! is_tty; then echo "$def"; return; fi
  local ans; read -r -p "$q " ans || true
  echo "${ans:-$def}"
}

# confirm "Question?"  -> yes(0)/no(1).
#   --yes (ASSUME_YES): always yes.  non-interactive without --yes: decline.
confirm() {
  local q="$1"
  [[ "$ASSUME_YES" == "1" ]] && return 0
  is_tty || return 1
  local ans; read -r -p "$q [Y/n] " ans || true
  [[ -z "$ans" || "$ans" =~ ^[Yy] ]]
}

# ---------------------------------------------------------------------------
# Managed-block injection — idempotent insert/replace between markers
# inject_block <file> <tag> <<<"content"   (content read from stdin)
# Re-running replaces the block; never duplicates.
# ---------------------------------------------------------------------------
inject_block() {
  local file="$1" tag="$2"
  local begin="# >>> ${tag} >>>"
  local end="# <<< ${tag} <<<"
  local content; content="$(cat)"

  # Refuse to touch a file whose markers are unbalanced (crashed run / hand-edit):
  # rewriting would drop everything between the lone marker and EOF — the user's
  # own config. grep -qxF = whole-line fixed match, mirroring awk's $0==b/$0==e.
  if [[ -f "$file" ]]; then
    local has_begin=0 has_end=0
    grep -qxF "$begin" "$file" && has_begin=1
    grep -qxF "$end"   "$file" && has_end=1
    if [[ "$has_begin" != "$has_end" ]]; then
      warn "${file/#$HOME/~} has an unmatched lazy-starter-kit '$tag' marker; refusing to modify it. Fix or delete the stray marker line by hand."
      return 0
    fi
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    if [[ -f "$file" ]] && grep -qF "$begin" "$file"; then
      info "[dry-run] would update '$tag' block in ${file/#$HOME/~}"
    else
      info "[dry-run] would add '$tag' block to ${file/#$HOME/~}"
    fi
    return 0
  fi

  run mkdir -p "$(dirname "$file")"
  [[ -f "$file" ]] || : > "$file"

  # one-time safety backup before the first rewrite of a non-empty user file
  local bak="$file.lazy-starter-kit.bak"
  if [[ -s "$file" && ! -e "$bak" ]]; then
    cp "$file" "$bak"
    info "backed up ${file/#$HOME/~} -> ${bak/#$HOME/~} (first change)"
  fi

  local tmp; tmp="$(mktemp)"
  # copy everything outside the existing block
  awk -v b="$begin" -v e="$end" '
    $0==b {skip=1} skip && $0==e {skip=0; next} !skip {print}
  ' "$file" > "$tmp"

  {
    cat "$tmp"
    printf '%s\n%s\n%s\n' "$begin" "$content" "$end"
  } > "$file"
  rm -f "$tmp"
  ok "wrote '$tag' block -> ${file/#$HOME/~}"
}

# remove_block <file> <tag>  — delete a managed block (markers + content). Idempotent.
remove_block() {
  local file="$1" tag="$2"
  local begin="# >>> ${tag} >>>"
  local end="# <<< ${tag} <<<"
  [[ -f "$file" ]] || { info "no ${file/#$HOME/~} (skip '$tag')"; return 0; }

  # Refuse on unbalanced markers (see inject_block): a lone begin marker would
  # make awk skip to EOF and delete the user's own config below it.
  local has_begin=0 has_end=0
  grep -qxF "$begin" "$file" && has_begin=1
  grep -qxF "$end"   "$file" && has_end=1
  if [[ "$has_begin" != "$has_end" ]]; then
    warn "${file/#$HOME/~} has an unmatched lazy-starter-kit '$tag' marker; refusing to modify it. Fix or delete the stray marker line by hand."
    return 0
  fi
  [[ "$has_begin" == 1 ]] || { info "no '$tag' block in ${file/#$HOME/~}"; return 0; }

  if [[ "$DRY_RUN" == "1" ]]; then
    info "[dry-run] would remove '$tag' block from ${file/#$HOME/~}"
    return 0
  fi

  # one-time safety backup before the first rewrite of a non-empty user file
  local bak="$file.lazy-starter-kit.bak"
  if [[ -s "$file" && ! -e "$bak" ]]; then
    cp "$file" "$bak"
    info "backed up ${file/#$HOME/~} -> ${bak/#$HOME/~} (first change)"
  fi

  local tmp; tmp="$(mktemp)"
  awk -v b="$begin" -v e="$end" '
    $0==b {skip=1} skip && $0==e {skip=0; next} !skip {print}
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
  ok "removed '$tag' block from ${file/#$HOME/~}"
}
