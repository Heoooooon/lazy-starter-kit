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

# safe_rm_rf_under <allowed-root> <absolute-target>...
#
# The only recursive filesystem deletion primitive in the Bash kits lives here.
# Every target is validated before any deletion starts, so a mixed safe/unsafe
# batch cannot be partially applied.  Existing symlink components are refused:
# physical containment is required, not just a matching string prefix.
safe_rm_rf_under() {
  if [[ "$#" -lt 2 ]]; then
    err "safe recursive delete requires an allowed root and at least one target"
    return 1
  fi

  local allowed_root="$1" root_physical home_physical="" target relative
  local current rest component probe parent_physical
  local -a validated=()
  shift

  if [[ -z "$allowed_root" || "$allowed_root" != /* ]]; then
    err "safe recursive delete root must be a non-empty absolute path"
    return 1
  fi
  [[ "$allowed_root" == "/" ]] || allowed_root="${allowed_root%/}"
  case "/${allowed_root#/}/" in
    *'//'*) err "safe recursive delete root contains an empty path component: $allowed_root"; return 1 ;;
    *'/./'*|*'/../'*) err "safe recursive delete root contains a dot path component: $allowed_root"; return 1 ;;
  esac
  if [[ ! -d "$allowed_root" ]]; then
    err "safe recursive delete root is not an existing directory: $allowed_root"
    return 1
  fi
  root_physical="$(cd -P "$allowed_root" 2>/dev/null && pwd -P)" || {
    err "could not resolve safe recursive delete root: $allowed_root"
    return 1
  }
  if [[ "$root_physical" == "/" ]]; then
    err "refusing recursive delete with filesystem root as the allowed boundary"
    return 1
  fi
  if [[ -d "${HOME:-}" ]]; then
    home_physical="$(cd -P "$HOME" 2>/dev/null && pwd -P || true)"
  fi

  for target in "$@"; do
    if [[ -z "$target" || "$target" != /* ]]; then
      err "safe recursive delete target must be a non-empty absolute path: ${target:-<empty>}"
      return 1
    fi
    [[ "$target" == "/" ]] || target="${target%/}"
    case "/${target#/}/" in
      *'//'*) err "safe recursive delete target contains an empty path component: $target"; return 1 ;;
      *'/./'*|*'/../'*) err "safe recursive delete target contains a dot path component: $target"; return 1 ;;
    esac
    if [[ "$target" == "/" || "$target" == "$allowed_root" || "$target" == "${HOME:-}" ]]; then
      err "refusing recursive delete of a protected boundary: $target"
      return 1
    fi
    case "$target" in
      "$allowed_root"/*) relative="${target#"$allowed_root"/}" ;;
      *) err "recursive delete target escapes allowed root $allowed_root: $target"; return 1 ;;
    esac

    current="$allowed_root"
    rest="$relative"
    while [[ -n "$rest" ]]; do
      if [[ "$rest" == */* ]]; then
        component="${rest%%/*}"
        rest="${rest#*/}"
      else
        component="$rest"
        rest=""
      fi
      if [[ -z "$component" || "$component" == "." || "$component" == ".." ]]; then
        err "unsafe path component in recursive delete target: $target"
        return 1
      fi
      current="$current/$component"
      if [[ -L "$current" ]]; then
        err "refusing recursive delete through symbolic link: $current"
        return 1
      fi
      if [[ -n "$rest" && -e "$current" && ! -d "$current" ]]; then
        err "recursive delete target crosses a non-directory component: $current"
        return 1
      fi
    done

    probe="$target"
    while [[ ! -e "$probe" ]]; do
      probe="${probe%/*}"
      [[ -n "$probe" ]] || probe="/"
    done
    if [[ -d "$probe" ]]; then
      parent_physical="$(cd -P "$probe" 2>/dev/null && pwd -P)" || {
        err "could not resolve recursive delete target: $target"
        return 1
      }
    else
      parent_physical="$(cd -P "${probe%/*}" 2>/dev/null && pwd -P)" || {
        err "could not resolve recursive delete target parent: $target"
        return 1
      }
    fi
    case "$parent_physical" in
      "$root_physical"|"$root_physical"/*) ;;
      *) err "recursive delete target resolves outside allowed root: $target"; return 1 ;;
    esac
    if [[ -n "$home_physical" && "$parent_physical" == "$home_physical" && -d "$target" ]]; then
      local target_physical
      target_physical="$(cd -P "$target" 2>/dev/null && pwd -P)" || return 1
      if [[ "$target_physical" == "$home_physical" ]]; then
        err "refusing recursive delete of HOME through an alternate path: $target"
        return 1
      fi
    fi
    validated+=("$target")
  done

  run rm -rf -- "${validated[@]}"
}

# ---------------------------------------------------------------------------
# Predicates
# ---------------------------------------------------------------------------
have()        { command -v "$1" >/dev/null 2>&1; }
is_tty()      { [[ -t 0 ]]; }

shell_quote() { printf '%q' "$1"; }

_KIT_ZSH_CONFIG_DIR=""
_KIT_ZSH_CONFIG_DIR_RESOLVED=0

cache_zsh_config_dir() {
  [[ "$_KIT_ZSH_CONFIG_DIR_RESOLVED" == "1" ]] && return 0
  local dir="${ZDOTDIR-$HOME}" output marker
  if have zsh; then
    if output="$(command zsh -c 'builtin print; builtin print -r -- "__LSK_ZDOTDIR__${ZDOTDIR-$HOME}"' 2>/dev/null)"; then
      marker="$(printf '%s\n' "$output" | LC_ALL=C sed -n '/^__LSK_ZDOTDIR__/p' | tail -n 1)"
      [[ "$marker" == __LSK_ZDOTDIR__* ]] && dir="${marker#__LSK_ZDOTDIR__}"
    else
      warn "could not resolve ZDOTDIR through zsh; using ${dir:-$HOME}"
    fi
  elif [[ -z "${ZDOTDIR+x}" && -e "$HOME/.zshenv" ]]; then
    err "cannot resolve ZDOTDIR from ~/.zshenv because zsh is unavailable"
    return 1
  fi
  if [[ -z "$dir" ]]; then
    err "ZDOTDIR must not be empty; set it to an absolute directory or unset it"
    return 1
  fi
  if [[ "$dir" != /* ]]; then
    err "ZDOTDIR must be absolute (got: $dir)"
    return 1
  fi
  [[ "$dir" == "/" ]] || dir="${dir%/}"
  _KIT_ZSH_CONFIG_DIR="$dir"
  _KIT_ZSH_CONFIG_DIR_RESOLVED=1
}

zsh_config_dir() {
  cache_zsh_config_dir || return 1
  printf '%s\n' "$_KIT_ZSH_CONFIG_DIR"
}

zsh_config_file() {
  local dir
  dir="$(zsh_config_dir)" || return 1
  if [[ "$dir" == "/" ]]; then
    printf '/%s\n' "${1#/}"
  else
    printf '%s/%s\n' "$dir" "${1#/}"
  fi
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
_managed_block_state() {
  local file="$1" tag="$2"
  local begin="# >>> ${tag} >>>" end="# <<< ${tag} <<<"
  local begin_count end_count begin_line end_line

  [[ -f "$file" ]] || { printf 'absent\n'; return 0; }
  begin_count="$(grep -cxF "$begin" "$file" || true)"
  end_count="$(grep -cxF "$end" "$file" || true)"
  if [[ "$begin_count" == "0" && "$end_count" == "0" ]]; then
    printf 'absent\n'
    return 0
  fi
  if [[ "$begin_count" != "1" || "$end_count" != "1" ]]; then
    printf 'damaged\n'
    return 0
  fi
  begin_line="$(grep -nxF "$begin" "$file" | cut -d: -f1)"
  end_line="$(grep -nxF "$end" "$file" | cut -d: -f1)"
  if [[ "$begin_line" -lt "$end_line" ]]; then
    printf 'present\n'
  else
    printf 'damaged\n'
  fi
}

inject_block() {
  local file="$1" tag="$2"
  local begin="# >>> ${tag} >>>"
  local end="# <<< ${tag} <<<"
  local content state; content="$(cat)"

  # Refuse to touch a file whose markers are unbalanced (crashed run / hand-edit):
  # rewriting would drop everything between the lone marker and EOF — the user's
  # own config. grep -qxF = whole-line fixed match, mirroring awk's $0==b/$0==e.
  state="$(_managed_block_state "$file" "$tag")"
  if [[ "$state" == "damaged" ]]; then
    warn "${file/#$HOME/~} has duplicate, unmatched, or out-of-order lazy-starter-kit '$tag' markers; refusing to modify it. Fix the marker lines by hand."
    return 0
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    if [[ "$state" == "present" ]]; then
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
  local tool="$1" step="$2" alt="${3:-}" ver dir zshrc
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
    zshrc="${_DOCTOR_ZSHRC:-}"
    [[ -n "$zshrc" ]] || zshrc="$(zsh_config_file .zshrc)"
    warn "$tool — installed at $dir but not on PATH (open a new terminal, or: source $(shell_quote "$zshrc"))"
    _DOCTOR_PATHONLY=$((_DOCTOR_PATHONLY + 1)); return 0
  fi
  err "$tool — missing (install: ./install.sh --only $step)"
  _DOCTOR_MISSING=$((_DOCTOR_MISSING + 1))
}

# _doctor_runtime <tool> <step>  — a mise-managed runtime (node/python/go).
# Resolution goes through `mise which` when mise is present (so it's found even
# when the shims dir isn't on PATH yet), else falls back to a plain PATH probe.
_doctor_runtime() {
  local tool="$1" step="$2" p ver zshrc
  if have mise; then
    p="$(mise which "$tool" 2>/dev/null || true)"
    if [[ -n "$p" ]]; then
      if have "$tool"; then
        ver="$("$tool" --version 2>/dev/null | head -1 || true)"
        ok "$tool${ver:+ $ver}"
      else
        zshrc="${_DOCTOR_ZSHRC:-}"
        [[ -n "$zshrc" ]] || zshrc="$(zsh_config_file .zshrc)"
        warn "$tool — installed at $(dirname "$p") but not on PATH (open a new terminal, or: source $(shell_quote "$zshrc"))"
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
  local state
  [[ -f "$file" ]] || { info "no ${file/#$HOME/~} (skip '$tag')"; return 0; }

  # Refuse on unbalanced markers (see inject_block): a lone begin marker would
  # make awk skip to EOF and delete the user's own config below it.
  state="$(_managed_block_state "$file" "$tag")"
  if [[ "$state" == "damaged" ]]; then
    warn "${file/#$HOME/~} has duplicate, unmatched, or out-of-order lazy-starter-kit '$tag' markers; refusing to modify it. Fix the marker lines by hand."
    return 0
  fi
  [[ "$state" == "present" ]] || { info "no '$tag' block in ${file/#$HOME/~}"; return 0; }

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
  cat "$tmp" > "$file"
  rm -f "$tmp"
  ok "removed '$tag' block from ${file/#$HOME/~}"
}
