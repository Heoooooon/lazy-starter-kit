#!/usr/bin/env bash
#
# lazy-starter-kit — install a complete macOS dev environment from scratch.
# From nothing → Xcode CLT, Homebrew, runtimes, shell, Docker, AI agents
# (gajae-code + lazycodex).
#
# Usage:
#   ./install.sh [options]
#   curl -fsSL https://raw.githubusercontent.com/Heoooooon/lazy-starter-kit/main/install.sh | bash
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
# Steps (in order): prereqs brew runtimes shell docker git agents
#
set -euo pipefail

REPO_URL="${STARTER_KIT_REPO:-https://github.com/Heoooooon/lazy-starter-kit.git}"
REPO_BRANCH="${STARTER_KIT_BRANCH:-main}"
CLONE_DIR="${STARTER_KIT_DIR:-$HOME/.lazy-starter-kit}"

# ---------------------------------------------------------------------------
# Resolve the repo root, or bootstrap by cloning (supports curl | bash).
# ---------------------------------------------------------------------------
resolve_root() {
  local src="${BASH_SOURCE[0]:-}"
  if [[ -n "$src" ]]; then
    local dir; dir="$(cd "$(dirname "$src")" 2>/dev/null && pwd || true)"
    if [[ -n "$dir" && -f "$dir/scripts/lib.sh" ]]; then
      echo "$dir"; return 0
    fi
  fi
  # Running piped from curl: clone (or update) and hand off.
  echo "==> Bootstrapping lazy-starter-kit into $CLONE_DIR" >&2
  if ! command -v git >/dev/null 2>&1; then
    echo "==> git not found; triggering Xcode Command Line Tools install…" >&2
    xcode-select --install 2>/dev/null || true
    echo "Re-run this command after the Command Line Tools finish installing." >&2
    exit 1
  fi
  if [[ -d "$CLONE_DIR/.git" ]]; then
    git -C "$CLONE_DIR" pull --ff-only origin "$REPO_BRANCH" >&2 || true
  else
    git clone --branch "$REPO_BRANCH" --depth 1 "$REPO_URL" "$CLONE_DIR" >&2
  fi
  echo "$CLONE_DIR"
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

KIT_VERSION="$(cat "$ROOT/VERSION" 2>/dev/null || echo dev)"

# ---------------------------------------------------------------------------
# Step registry
# ---------------------------------------------------------------------------
# Note: kept bash-3.2 compatible (macOS ships bash 3.2) — no associative arrays.
STEP_IDS=(prereqs brew runtimes shell docker git agents)

# step_file <id> -> the scripts/NN-*.sh filename for that step
step_file() {
  case "$1" in
    prereqs)  echo 01-prereqs.sh ;;
    brew)     echo 02-brew.sh ;;
    runtimes) echo 03-runtimes.sh ;;
    shell)    echo 04-shell.sh ;;
    docker)   echo 05-docker.sh ;;
    git)      echo 06-git.sh ;;
    agents)   echo 07-agents.sh ;;
    *) return 1 ;;
  esac
}
# function name for each step is always step_<id>

# usage — print the leading comment block (skip the shebang, stop at the first
# non-comment line) so --help never leaks code that follows the header.
usage() { awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$ROOT/install.sh"; }

# ---------------------------------------------------------------------------
# Doctor (--doctor): print an installation health report and exit; changes
# nothing. The tool→step lists below mirror the CI verify steps + Brewfile; the
# probing mechanism lives in lib/common.sh (_doctor_* helpers).
# ---------------------------------------------------------------------------
_doctor_config() {
  _doctor_managed "$HOME/.zshrc"    "lazy-starter-kit:main"
  _doctor_managed "$HOME/.zprofile" "lazy-starter-kit:brew"
  _doctor_exists  "$HOME/.config/starship.toml"
}

doctor() {
  # macOS: also search the Homebrew prefix, and brew rustup's keg-only bin —
  # its rustc/cargo proxies live there, not in <prefix>/bin.
  _DOCTOR_BINS="$(brew_prefix)/bin $(brew_prefix)/opt/rustup/bin"
  load_mise                           # so `mise which` resolves node/python/go
  printf '%s\n' "$_C_BOLD== lazy-starter-kit v$KIT_VERSION · doctor ==$_C_RESET"

  step "Tools"
  _doctor_tool brew prereqs
  local t
  for t in git gh jq rg fd fzf bat tree wget ast-grep mo starship mise uv rustup bun colima docker; do
    _doctor_tool "$t" brew
  done
  _doctor_runtime node   runtimes
  _doctor_runtime python runtimes
  _doctor_runtime go     runtimes
  _doctor_tool rustc runtimes
  _doctor_tool zsh   prereqs
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
# updated step files rather than the stale ones already on disk.
# ---------------------------------------------------------------------------
DO_UPDATE=0; PASS_ARGS=()
for arg in "$@"; do
  if [[ "$arg" == "--update" ]]; then DO_UPDATE=1; else PASS_ARGS+=("$arg"); fi
done
if [[ "$DO_UPDATE" == "1" ]]; then
  update_kit "$ROOT"
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
# preset→skip mapping is this file's own (step ids: prereqs brew runtimes shell
# docker git agents); `work` also disables the heavy Hermes agent via HERMES=0.
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
is_macos || die "This kit targets macOS only."
is_arm   || warn "Not Apple Silicon (arm64) — proceeding, but only tested on M-series."
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
  info "1) Open a NEW terminal (or: source ~/.zshrc) so PATH + prompt load."
  if command -v gh >/dev/null 2>&1 && ! gh auth status >/dev/null 2>&1; then
    info "2) Sign in to GitHub:  gh auth login   (also sets your git identity)"
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
