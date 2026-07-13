#!/usr/bin/env bash
#
# lazy-starter-kit — install a complete Linux dev environment from scratch.
# From a fresh box → build tools, CLI, runtimes, shell, Docker, AI agents
# (gajae-code + codex + lazycodex + Hermes).
#
# Usage:
#   ./install.sh [options]
#   curl -fsSL https://raw.githubusercontent.com/Heoooooon/lazy-starter-kit/main/linux/install.sh | bash
#
# Options:
#   --dry-run        Show what would happen, change nothing.
#   --yes, -y        Non-interactive: accept defaults, never prompt.
#   --only  a,b,c    Run only these steps.
#   --skip  a,b,c    Run all steps except these.
#   --profile NAME   Preset step set: full · minimal · work.
#   --no-agents      Shortcut for --skip agents.
#   --doctor         Diagnose the install (health report), change nothing, exit.
#   --update         Git-pull the latest kit, then continue the run.
#   --list           List step ids and exit.
#   --version, -V    Print the kit version and exit.
#   --help, -h       Show this help.
#
# Steps (in order): prereqs packages runtimes shell docker git agents
#
# Supported package managers: apt · dnf/yum · pacman · zypper (glibc distros).
# Alpine/musl (apk) is not supported (upstream node/ast-grep/bun lack musl builds).
#
set -euo pipefail

REPO_URL="${STARTER_KIT_REPO:-https://github.com/Heoooooon/lazy-starter-kit.git}"
REPO_BRANCH="${STARTER_KIT_BRANCH:-main}"
CLONE_DIR="${STARTER_KIT_DIR:-$HOME/.lazy-starter-kit}"

# ---------------------------------------------------------------------------
# Resolve the repo root (the linux/ dir), or bootstrap by cloning (curl | bash).
# ---------------------------------------------------------------------------
resolve_root() {
  local src="${BASH_SOURCE[0]:-}"
  if [[ -n "$src" ]]; then
    local dir; dir="$(cd "$(dirname "$src")" 2>/dev/null && pwd || true)"
    if [[ -n "$dir" && -f "$dir/scripts/lib.sh" ]]; then
      echo "$dir"; return 0
    fi
  fi
  # Running piped from curl: clone (or update) and hand off to linux/install.sh.
  echo "==> Bootstrapping lazy-starter-kit into $CLONE_DIR" >&2
  if ! command -v git >/dev/null 2>&1; then
    echo "==> git not found. Install git first (e.g. sudo apt-get install -y git), then re-run." >&2
    exit 1
  fi
  if [[ -d "$CLONE_DIR/.git" ]]; then
    git -C "$CLONE_DIR" pull --ff-only origin "$REPO_BRANCH" >&2 || true
  else
    git clone --branch "$REPO_BRANCH" --depth 1 "$REPO_URL" "$CLONE_DIR" >&2
  fi
  echo "$CLONE_DIR/linux"
}

ROOT="$(resolve_root)"
# Resolve this script's own absolute path (empty when piped from curl).
SELF=""
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)/$(basename "${BASH_SOURCE[0]}")"
fi
# If we bootstrapped (cloned), hand off to the cloned copy with the original args.
if [[ "$SELF" != "$ROOT/install.sh" && -f "$ROOT/install.sh" ]]; then
  exec bash "$ROOT/install.sh" "$@"
fi

# shellcheck source=scripts/lib.sh
source "$ROOT/scripts/lib.sh"

KIT_VERSION="$(cat "$ROOT/../VERSION" 2>/dev/null || echo dev)"

# ---------------------------------------------------------------------------
# Step registry
# ---------------------------------------------------------------------------
STEP_IDS=(prereqs packages runtimes shell docker git agents)

# step_file <id> -> the scripts/NN-*.sh filename for that step
step_file() {
  case "$1" in
    prereqs)  echo 01-prereqs.sh ;;
    packages) echo 02-packages.sh ;;
    runtimes) echo 03-runtimes.sh ;;
    shell)    echo 04-shell.sh ;;
    docker)   echo 05-docker.sh ;;
    git)      echo 06-git.sh ;;
    agents)   echo 07-agents.sh ;;
    *) return 1 ;;
  esac
}

# usage — print the leading comment block (skip the shebang, stop at the first
# non-comment line) so --help never leaks code that follows the header.
usage() { awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$ROOT/install.sh"; }

# ---------------------------------------------------------------------------
# Doctor (--doctor): print an installation health report and exit; changes
# nothing. The tool→step lists below mirror the CI verify steps; the probing
# mechanism lives in lib/common.sh (_doctor_* helpers). fd/bat accept Debian's
# fdfind/batcat names too.
# ---------------------------------------------------------------------------
_doctor_config() {
  _doctor_managed "$_DOCTOR_ZSHRC" "lazy-starter-kit:main"
  _doctor_exists  "$HOME/.config/starship.toml"
}

doctor() {
  cache_zsh_config_dir
  _DOCTOR_ZSHRC="$(zsh_config_file .zshrc)"
  load_mise   # so `mise which` resolves node/python/go (safe no-op if absent)
  printf '%s\n' "$_C_BOLD== lazy-starter-kit v$KIT_VERSION · doctor ==$_C_RESET"

  step "Tools"
  local t
  for t in git curl zsh; do
    _doctor_tool "$t" prereqs
  done
  _doctor_tool fd  packages fdfind
  _doctor_tool bat packages batcat
  for t in rg fzf jq tree gh; do
    _doctor_tool "$t" packages
  done
  for t in starship mise uv bun rustup; do
    _doctor_tool "$t" packages
  done
  _doctor_runtime node   runtimes
  _doctor_runtime python runtimes
  _doctor_runtime go     runtimes
  for t in gjc codex claude; do
    _doctor_tool "$t" agents
  done

  step "Config"
  _doctor_config

  step "Summary"
  local issues=$((_DOCTOR_MISSING + _DOCTOR_PATHONLY))
  if [[ "$issues" -eq 0 ]]; then
    ok "all good"
  else
    warn "$issues issue(s) — see above"
  fi
  [[ "$_DOCTOR_MISSING" -eq 0 ]] && exit 0 || exit 1
}

# ---------------------------------------------------------------------------
# Update (--update): pull the latest kit, then re-exec the freshly-pulled
# installer with the remaining args. Handled BEFORE normal parsing so it
# composes with any other flag (order-independent) and the run always uses the
# updated step files rather than the stale ones already on disk. $ROOT is the
# linux/ dir here, so the git checkout is its parent.
# ---------------------------------------------------------------------------
DO_UPDATE=0; PASS_ARGS=()
for arg in "$@"; do
  if [[ "$arg" == "--update" ]]; then DO_UPDATE=1; else PASS_ARGS+=("$arg"); fi
done
if [[ "$DO_UPDATE" == "1" ]]; then
  update_kit "$ROOT/.."
  exec bash "$ROOT/install.sh" ${PASS_ARGS[@]+"${PASS_ARGS[@]}"}
fi

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------
ONLY=""; SKIP=""; PROFILE=""; DOCTOR=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)   export DRY_RUN=1 ;;
    -y|--yes)    export ASSUME_YES=1 ;;
    --only)      ONLY="${2:-}"; shift ;;
    --only=*)    ONLY="${1#*=}" ;;
    --skip)      SKIP="${2:-}"; shift ;;
    --skip=*)    SKIP="${1#*=}" ;;
    --profile)   PROFILE="${2:-}"; shift ;;
    --profile=*) PROFILE="${1#*=}" ;;
    --no-agents) SKIP="${SKIP:+$SKIP,}agents" ;;
    --doctor)    DOCTOR=1 ;;
    --list)      printf '%s\n' "${STEP_IDS[@]}"; exit 0 ;;
    -V|--version) echo "lazy-starter-kit $KIT_VERSION"; exit 0 ;;
    -h|--help)   usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
  shift
done

# --doctor: health report, then exit (like --list — before any step runs).
[[ "$DOCTOR" == "1" ]] && doctor

# Normalize --only/--skip (strip spaces so `--only "brew, shell"` works), then
# reject any unknown token up front instead of silently selecting nothing.
ONLY="${ONLY// /}"; SKIP="${SKIP// /}"

# --profile NAME — expand a named preset into extra SKIP steps (unioned with any
# --skip), reusing the SKIP machinery below. Mutually exclusive with --only. The
# preset→skip mapping is this file's own (step ids: prereqs packages runtimes
# shell docker git agents); `work` also disables the heavy Hermes agent via HERMES=0.
if [[ -n "$PROFILE" ]]; then
  [[ -n "$ONLY" ]] && die "choose either --profile or --only"
  case "$PROFILE" in
    full)    PRESET_SKIP="" ;;
    minimal) PRESET_SKIP="docker,agents" ;;
    work)    PRESET_SKIP="docker"; export HERMES=0 ;;
    *) die "unknown profile: '$PROFILE' (valid: full minimal work)" ;;
  esac
  [[ -n "$PRESET_SKIP" ]] && SKIP="${SKIP:+$SKIP,}$PRESET_SKIP"
fi

_validate_ids() {
  local list="$1" tok id found valid="${STEP_IDS[*]}"
  while [[ -n "$list" ]]; do
    tok="${list%%,*}"
    if [[ "$list" == *,* ]]; then list="${list#*,}"; else list=""; fi
    [[ -z "$tok" ]] && continue
    found=0
    for id in "${STEP_IDS[@]}"; do [[ "$id" == "$tok" ]] && found=1; done
    [[ "$found" == 1 ]] || die "unknown step id: '$tok' (valid: $valid)"
  done
}
[[ -n "$ONLY" ]] && _validate_ids "$ONLY"
[[ -n "$SKIP" ]] && _validate_ids "$SKIP"

# Build the active step list honouring --only / --skip
selected() {
  local id keep
  for id in "${STEP_IDS[@]}"; do
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
# Pre-flight
# ---------------------------------------------------------------------------
is_linux || die "This kit targets Linux only (macOS users: use the repo root install.sh)."
[[ "$DRY_RUN" == "1" ]] && warn "DRY-RUN: no changes will be made."

printf '%s\n' "$_C_BOLD== lazy-starter-kit v$KIT_VERSION ==$_C_RESET"
info "steps: $(selected | tr '\n' ' ')${PROFILE:+(profile: $PROFILE)}"

# ---------------------------------------------------------------------------
# Execute
# ---------------------------------------------------------------------------
for id in $(selected); do
  file="$ROOT/scripts/$(step_file "$id")"
  fn="step_$id"
  [[ -f "$file" ]] || die "missing step file: $file"
  # shellcheck disable=SC1090
  source "$file"
  "$fn"
done

step "Done."
if [[ "$DRY_RUN" == "1" ]]; then
  info "That was a dry run — re-run without --dry-run to apply."
else
  step "Next steps"
  zshrc="$(zsh_config_file .zshrc)"
  info "1) Open a NEW terminal (or: source $(shell_quote "$zshrc")) so PATH + prompt load."
  if command -v gh >/dev/null 2>&1 && ! gh auth status >/dev/null 2>&1; then
    info "2) Sign in to GitHub:  gh auth login   (also sets your git identity)"
  fi
  if command -v docker >/dev/null 2>&1 && ! id -nG 2>/dev/null | tr ' ' '\n' | grep -qx docker; then
    info "3) Docker: log out/in (or run 'newgrp docker') so group access applies."
  fi
  info "Set your terminal font to 'JetBrainsMono Nerd Font' for prompt icons."

  # --- optional: ask for a GitHub star (opt-in, default No) ---------------
  # Interactive runs only — --yes and non-interactive/CI never see this, and
  # nothing is ever starred without an explicit 'y' (see confirm_default_no).
  repo_slug="${REPO_URL#https://github.com/}"; repo_slug="${repo_slug%.git}"
  if have gh && gh auth status >/dev/null 2>&1 \
     && ! gh api "user/starred/$repo_slug" >/dev/null 2>&1; then
    if confirm_default_no "Enjoyed the setup? Star $repo_slug on GitHub? ⭐"; then
      gh api -X PUT "user/starred/$repo_slug" >/dev/null 2>&1 \
        && ok "thanks for the star! ⭐" \
        || info "couldn't star from here — https://github.com/$repo_slug"
    fi
  fi
fi
exit 0
