#!/usr/bin/env bash
# common.sh — OS-agnostic shared helpers for lazy-starter-kit.
#
# Sourced by scripts/lib.sh (macOS) and linux/scripts/lib.sh, each of which adds
# its own OS-specific bits. Kept in ONE place so a fix can't accidentally land in
# only one tree (that has caused real one-sided bugs in the past).
#
# bash 3.2 compatible (macOS ships bash 3.2); expects a `set -euo pipefail` caller.

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
#   --yes (ASSUME_YES): always yes.  non-interactive without --yes: decline (skip optional/heavy action).
confirm() {
  local q="$1"
  [[ "$ASSUME_YES" == "1" ]] && return 0
  is_tty || return 1
  local ans; read -r -p "$q [Y/n] " ans || true
  [[ -z "$ans" || "$ans" =~ ^[Yy] ]]
}

# confirm_default_no "Question?"  -> yes(0)/no(1). Bare Enter DECLINES, and both
# --yes and non-interactive runs decline too — for purely optional extras (like
# the GitHub star ask) that must never happen without an explicit yes.
confirm_default_no() {
  local q="$1"
  [[ "$ASSUME_YES" == "1" ]] && return 1
  is_tty || return 1
  local ans; read -r -p "$q [y/N] " ans || true
  [[ "$ans" =~ ^[Yy] ]]
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

  # trim a single trailing blank line for tidiness, then append the block
  {
    cat "$tmp"
    printf '%s\n%s\n%s\n' "$begin" "$content" "$end"
  } > "$file"
  rm -f "$tmp"
  ok "wrote '$tag' block -> ${file/#$HOME/~}"
}

# ---------------------------------------------------------------------------
# Doctor — installation health probe (install.sh --doctor).
# OS-agnostic mechanism only; each install.sh supplies its own tool→step lists
# (and, on macOS, seeds _DOCTOR_BINS with $(brew_prefix)/bin). NEVER modifies
# anything — no step files are sourced and no installers run.
# ---------------------------------------------------------------------------
: "${_DOCTOR_BINS:=}"   # extra kit bin dirs to search (macOS seeds brew prefix)
_DOCTOR_MISSING=0       # count of ✗ (nowhere) tools — drives the exit code
_DOCTOR_PATHONLY=0      # count of ! (installed but off-PATH) tools

# _doctor_find_off_path <tool> — echo the first kit bin dir holding an
# executable <tool> (only meaningful when <tool> is NOT on PATH), else nothing.
_doctor_find_off_path() {
  local tool="$1" d
  # shellcheck disable=SC2086
  for d in ${_DOCTOR_BINS:-} \
           "$HOME/.local/bin" "$HOME/.bun/bin" "$HOME/.cargo/bin" \
           "$HOME/.local/share/mise/shims"; do
    [[ -n "$d" && -x "$d/$tool" ]] && { echo "$d"; return 0; }
  done
  return 1
}

# _doctor_tool <tool> <step> [altname]  — report one tool's state:
#   ok  on the current PATH   |   !  installed in a kit bin but off PATH
#   ✗   nowhere (missing)
# [altname] lets Debian's fdfind/batcat count as fd/bat.
_doctor_tool() {
  local tool="$1" step="$2" alt="${3:-}" ver dir
  if have "$tool"; then
    ver="$("$tool" --version 2>/dev/null | head -1 || true)"
    ok "$tool${ver:+ $ver}"; return 0
  fi
  if [[ -n "$alt" ]] && have "$alt"; then
    ver="$("$alt" --version 2>/dev/null | head -1 || true)"
    ok "$tool${ver:+ $ver}"; return 0
  fi
  if dir="$(_doctor_find_off_path "$tool")" \
     || { [[ -n "$alt" ]] && dir="$(_doctor_find_off_path "$alt")"; }; then
    warn "$tool — installed at $dir but not on PATH (open a new terminal, or: source ~/.zshrc)"
    _DOCTOR_PATHONLY=$((_DOCTOR_PATHONLY + 1)); return 0
  fi
  err "$tool — missing (install: ./install.sh --only $step)"
  _DOCTOR_MISSING=$((_DOCTOR_MISSING + 1))
}

# _doctor_runtime <tool> <step>  — a mise-managed runtime (node/python/go).
# Resolution goes through `mise which` when mise is present (so it's found even
# when the shims dir isn't on PATH yet), else falls back to a plain PATH probe.
_doctor_runtime() {
  local tool="$1" step="$2" p ver
  if have mise; then
    p="$(mise which "$tool" 2>/dev/null || true)"
    if [[ -n "$p" ]]; then
      if have "$tool"; then
        ver="$("$tool" --version 2>/dev/null | head -1 || true)"
        ok "$tool${ver:+ $ver}"
      else
        warn "$tool — installed at $(dirname "$p") but not on PATH (open a new terminal, or: source ~/.zshrc)"
        _DOCTOR_PATHONLY=$((_DOCTOR_PATHONLY + 1))
      fi
      return 0
    fi
  fi
  _doctor_tool "$tool" "$step"
}

# _doctor_managed <file> <tag>  — report whether a managed block is present.
_doctor_managed() {
  local file="$1" tag="$2" begin="# >>> $2 >>>"
  if [[ -f "$file" ]] && grep -qxF "$begin" "$file"; then
    ok "${file/#$HOME/~} has '$tag' block"
  else
    err "${file/#$HOME/~} missing '$tag' block (install: ./install.sh --only shell)"
    _DOCTOR_MISSING=$((_DOCTOR_MISSING + 1))
  fi
}

# _doctor_exists <path>  — report whether a config file is present.
_doctor_exists() {
  local path="$1"
  if [[ -e "$path" ]]; then
    ok "${path/#$HOME/~} present"
  else
    err "${path/#$HOME/~} missing (install: ./install.sh --only shell)"
    _DOCTOR_MISSING=$((_DOCTOR_MISSING + 1))
  fi
}

# ---------------------------------------------------------------------------
# Update — git-pull the kit in place (install.sh --update).
# update_kit <repo_dir>  fetches + fast-forwards the checkout and prints the
# version delta. The caller re-execs the freshly-pulled installer afterwards,
# so stale step files never run. Touches nothing but the git checkout.
# ---------------------------------------------------------------------------
update_kit() {
  local repo="$1" old new
  [[ -d "$repo/.git" ]] || die "not a git checkout — re-run the curl installer or git pull manually"
  old="$(cat "$repo/VERSION" 2>/dev/null || echo dev)"
  step "Updating lazy-starter-kit"
  git -C "$repo" fetch --quiet || die "git fetch failed — check your network and try again"
  git -C "$repo" pull --ff-only \
    || die "git pull --ff-only failed (diverged history or local changes) — resolve manually: git -C \"$repo\" pull"
  new="$(cat "$repo/VERSION" 2>/dev/null || echo dev)"
  if [[ "$old" == "$new" ]]; then
    ok "already up to date ($new)"
  else
    ok "updated $old -> $new"
  fi
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
