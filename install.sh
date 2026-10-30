#!/usr/bin/env bash
#
# lazy-starter-kit — install a complete macOS dev environment from scratch.
# From nothing → Xcode CLT, Homebrew, runtimes, shell, Docker, AI agents
# (Claude Code + codex; Hermes opt-in).
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
#   --profile NAME   Preset: ai (default) · recommended (developer tools) · full · minimal · work.
#   --no-agents      Shortcut for --skip agents.
#   --doctor-json    Machine-readable AI readiness (--profile ai); read-only.
#   --doctor         Diagnose the install (health report), change nothing, exit.
#   --update         Git-pull the latest kit, then continue the run.
#   --list           List step ids and exit.
#   --version, -V    Print the kit version and exit.
#   --help, -h       Show this help.
#
# Steps (in order): prereqs brew runtimes shell docker git agents
#
set -euo pipefail

# A bundled/piped preview must not touch Git's CLT shim or clone a checkout.
# Reuse the normal argument validation and step registry below, offline.
BOOTSTRAP_PREVIEW="${DRY_RUN:-0}"
for bootstrap_arg in "$@"; do
  [[ "$bootstrap_arg" != --dry-run ]] || BOOTSTRAP_PREVIEW=1
done

SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"
REPO_URL="${STARTER_KIT_REPO:-https://github.com/Heoooooon/lazy-starter-kit.git}"
CLONE_DIR="${STARTER_KIT_DIR:-$HOME/.lazy-starter-kit}"
# STARTER_KIT_BRANCH pins an explicit ref (a tag like v0.9.0, or "main" to ride
# the development branch). Left unset, the bootstrap resolves the newest
# published GitHub Release instead of merely taking the newest v* tag. A tag
# that is still building or whose release failed must never become the default.
REPO_BRANCH="${STARTER_KIT_BRANCH:-}"
REPO_COMMIT="${STARTER_KIT_COMMIT:-}"
EPHEMERAL_ROOT="${STARTER_KIT_EPHEMERAL_ROOT:-}"
if [[ -n "$REPO_COMMIT" && ! "$REPO_COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Invalid STARTER_KIT_COMMIT: expected a full 40-character commit SHA." >&2
  exit 1
fi

# kit_latest_ref — newest published GitHub Release tag. For the official repo,
# failure to resolve a published release is fatal: silently falling back to main
# would defeat the release/CI trust boundary. Non-GitHub custom repos retain the
# legacy tag/main fallback for local forks and tests.
kit_latest_ref() {
  local repo_web="" final="" tag=""
  case "$REPO_URL" in
    https://github.com/*)
      repo_web="${REPO_URL%.git}" ;;
    git@github.com:*)
      repo_web="https://github.com/${REPO_URL#git@github.com:}"
      repo_web="${repo_web%.git}" ;;
    ssh://git@github.com/*)
      repo_web="https://github.com/${REPO_URL#ssh://git@github.com/}"
      repo_web="${repo_web%.git}" ;;
  esac
  repo_web="${repo_web%/}"

  if [[ -n "$repo_web" ]] && command -v curl >/dev/null 2>&1; then
    final="$(curl -fsSL -o /dev/null -w '%{url_effective}' "$repo_web/releases/latest" 2>/dev/null || true)"
    case "$final" in
      "$repo_web"/releases/tag/*)
        tag="${final#"$repo_web"/releases/tag/}"
        if [[ -n "$tag" && "$tag" != */* ]]; then
          printf '%s\n' "$tag"
          return 0
        fi
        ;;
    esac
  fi

  if [[ "$repo_web" == "https://github.com/Heoooooon/lazy-starter-kit" ]]; then
    echo "Could not resolve the latest published lazy-starter-kit release; refusing to fall back to main." >&2
    return 1
  fi

  tag="$(git ls-remote --tags --refs --sort=-v:refname "$REPO_URL" 'v*' 2>/dev/null \
         | head -1 | sed 's#.*refs/tags/##')"
  if [[ -n "$tag" ]]; then echo "$tag"; else echo main; fi
}

# ---------------------------------------------------------------------------
# Resolve the repo root, or bootstrap by cloning (supports curl | bash).
# ---------------------------------------------------------------------------
resolve_root() {
  local src="$SCRIPT_SOURCE"
  if [[ -n "$src" ]]; then
    local dir; dir="$(cd "$(dirname "$src")" 2>/dev/null && pwd || true)"
    if [[ -n "$dir" && -f "$dir/scripts/lib.sh" ]]; then
      echo "$dir"; return 0
    fi
  fi
  # Running piped from curl: clone (or update) and hand off.
  if [[ "$BOOTSTRAP_PREVIEW" == 1 ]]; then
    # Piped previews have no trusted source directory; never fall back to cwd.
    printf '%s\n' "${dir:-}"
    return 0
  fi
  echo "==> Bootstrapping lazy-starter-kit into $CLONE_DIR" >&2
  if [[ -n "$EPHEMERAL_ROOT" ]]; then
    [[ "$EPHEMERAL_ROOT" == "$CLONE_DIR" ]] \
      || { echo "STARTER_KIT_EPHEMERAL_ROOT must match STARTER_KIT_DIR." >&2; exit 1; }
    [[ ! -e "$CLONE_DIR" ]] \
      || { echo "Ephemeral checkout path already exists; refusing to trust it." >&2; exit 1; }
  fi
  if ! command -v git >/dev/null 2>&1; then
    echo "==> git not found; triggering Xcode Command Line Tools install…" >&2
    xcode-select --install 2>/dev/null || true
    echo "Re-run this command after the Command Line Tools finish installing." >&2
    exit 1
  fi
  [[ -n "$REPO_BRANCH" ]] || REPO_BRANCH="$(kit_latest_ref)"
  echo "==> Using ${REPO_BRANCH}" >&2
  if [[ -d "$CLONE_DIR/.git" ]]; then
    if [[ -n "$(git -C "$CLONE_DIR" status --porcelain --untracked-files=normal)" ]]; then
      echo "Existing checkout has local changes; refusing to run: $CLONE_DIR" >&2
      exit 1
    fi
    git -C "$CLONE_DIR" fetch --force --depth 1 origin "$REPO_BRANCH" >&2 \
      || { echo "Could not fetch $REPO_BRANCH; refusing to use a stale checkout." >&2; exit 1; }
    fetched_commit="$(git -C "$CLONE_DIR" rev-parse 'FETCH_HEAD^{commit}')"
    if [[ -n "$REPO_COMMIT" && "$fetched_commit" != "$REPO_COMMIT" ]]; then
      echo "Fetched commit $fetched_commit does not match pinned commit $REPO_COMMIT." >&2
      exit 1
    fi
    git -C "$CLONE_DIR" checkout --quiet --detach "$fetched_commit" \
      || { echo "Could not check out verified commit $fetched_commit." >&2; exit 1; }
  else
    # -c advice.detachedHead=false: tag checkouts are detached by design;
    # the 15-line git lecture only alarms first-time users.
    git clone -c advice.detachedHead=false --branch "$REPO_BRANCH" --depth 1 "$REPO_URL" "$CLONE_DIR" >&2
  fi
  resolved_commit="$(git -C "$CLONE_DIR" rev-parse 'HEAD^{commit}')"
  if [[ -n "$REPO_COMMIT" && "$resolved_commit" != "$REPO_COMMIT" ]]; then
    echo "Checkout commit $resolved_commit does not match pinned commit $REPO_COMMIT." >&2
    exit 1
  fi
  echo "$CLONE_DIR"
}

ROOT="$(resolve_root)"
if [[ -n "$EPHEMERAL_ROOT" && "$ROOT" == "$EPHEMERAL_ROOT" ]]; then
  # shellcheck source=lib/common.sh
  source "$ROOT/lib/common.sh"
  cleanup_ephemeral_root() {
    local previous_dry_run="$DRY_RUN"
    DRY_RUN=0
    safe_rm_rf_under "$(dirname "$ROOT")" "$ROOT"
    DRY_RUN="$previous_dry_run"
  }
  trap cleanup_ephemeral_root EXIT
fi
# Resolve this script's own absolute path (empty when piped from curl).
SELF=""
if [[ -n "$SCRIPT_SOURCE" ]]; then
  SELF="$(cd "$(dirname "$SCRIPT_SOURCE")" 2>/dev/null && pwd || true)/$(basename "$SCRIPT_SOURCE")"
fi
# If we bootstrapped (cloned), hand off to the cloned copy with the original args.
if [[ -n "$ROOT" && "$SELF" != "$ROOT/install.sh" && -f "$ROOT/install.sh" ]]; then
  exec bash "$ROOT/install.sh" "$@"
fi

OFFLINE_PREVIEW=0
if [[ -n "$ROOT" && -f "$ROOT/scripts/lib.sh" ]]; then
  # shellcheck source=scripts/lib.sh
  source "$ROOT/scripts/lib.sh"
else
  [[ "$BOOTSTRAP_PREVIEW" == 1 ]] || { printf 'Missing installer helpers.\n' >&2; exit 1; }
  OFFLINE_PREVIEW=1
  DRY_RUN=1
  ASSUME_YES=0
  die() { printf 'error: %s\n' "$*" >&2; exit 1; }
fi

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
  _doctor_managed "$_DOCTOR_ZSHRC"    "lazy-starter-kit:main" "$(cat "$ROOT/config/zshrc.block.sh")"
  _doctor_managed "$_DOCTOR_ZPROFILE" "lazy-starter-kit:brew" "eval \"\$($(brew_prefix)/bin/brew shellenv)\""
  _doctor_exists  "$HOME/.config/starship.toml"
}

doctor() {
  cache_zsh_config_dir
  _DOCTOR_ZSHRC="$(zsh_config_file .zshrc)"
  _DOCTOR_ZPROFILE="$(zsh_config_file .zprofile)"
  # macOS: also search the Homebrew prefix, and brew rustup's keg-only bin —
  # its rustc/cargo proxies live there, not in <prefix>/bin.
  _DOCTOR_BINS="$(brew_prefix)/bin $(brew_prefix)/opt/rustup/bin"
  load_mise                           # so `mise which` resolves node/python/go
  printf '%s\n' "$_C_BOLD== lazy-starter-kit v$KIT_VERSION · doctor ==$_C_RESET"

  step "Tools"
  _doctor_tool brew prereqs
  local t
  for t in git gh jq rg fd fzf bat tree ast-grep zoxide starship mise uv rustup bun colima docker; do
    _doctor_tool "$t" brew
  done
  _doctor_runtime node   runtimes
  _doctor_runtime python runtimes
  _doctor_runtime go     runtimes
  _doctor_tool rustc runtimes
  _doctor_tool zsh   prereqs
  for t in codex claude; do
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
# updated step files rather than the stale ones already on disk. Detached
# release checkouts resolve the newest published release before fetching.
# ---------------------------------------------------------------------------
DO_UPDATE=0; PASS_ARGS=()
for arg in "$@"; do
  if [[ "$arg" == "--update" ]]; then DO_UPDATE=1; else PASS_ARGS+=("$arg"); fi
done
if [[ "$DO_UPDATE" == "1" ]]; then
  [[ "$OFFLINE_PREVIEW" == 0 ]] || die "offline preview cannot update a checkout"
  if ! git -C "$ROOT" symbolic-ref -q HEAD >/dev/null 2>&1 \
     && [[ -z "${STARTER_KIT_BRANCH:-}" ]]; then
    latest_ref="$(kit_latest_ref)" || die "could not resolve latest published release"
    export STARTER_KIT_BRANCH="$latest_ref"
  fi
  update_kit "$ROOT"
  exec bash "$ROOT/install.sh" ${PASS_ARGS[@]+"${PASS_ARGS[@]}"}
fi

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------
ONLY=""; SKIP=""; PROFILE=""; DOCTOR=0; DOCTOR_FORMAT=text; NO_AGENTS=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)   export DRY_RUN=1 ;;
    -y|--yes)    export ASSUME_YES=1 ;;
    --only|--skip|--profile|--only=*|--skip=*|--profile=*)
      option="${1%%=*}"
      if [[ "$1" == *=* ]]; then
        value="${1#*=}"
      else
        [[ $# -ge 2 && "${2:-}" != -* ]] || die "$option requires a value"
        value="$2"; shift
      fi
      [[ -n "${value// /}" ]] || die "$option requires a non-empty value"
      case "$option" in
        --only) ONLY="$value" ;;
        --skip) SKIP="$value" ;;
        --profile) PROFILE="$value" ;;
      esac ;;
    --no-agents) NO_AGENTS=1 ;;
    --doctor)    DOCTOR=1 ;;
    --doctor-json) DOCTOR=1; DOCTOR_FORMAT=json ;;
    --list)      printf '%s\n' "${STEP_IDS[@]}"; exit 0 ;;
    -V|--version) echo "lazy-starter-kit $KIT_VERSION"; exit 0 ;;
    -h|--help)   usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
  shift
done

# Keep this shortcut independent of the order of explicit --skip values.
if [[ "$NO_AGENTS" == 1 ]]; then SKIP="${SKIP:+$SKIP,}agents"; fi

# Normalize --only/--skip (strip spaces so `--only "brew, shell"` works), then
# reject any unknown token up front instead of silently selecting nothing.
ONLY="${ONLY// /}"; SKIP="${SKIP// /}"
INSTALL_PROFILE_FILE="$HOME/.local/share/lazy-starter-kit/install-profile"
if [[ "$DOCTOR" == 1 && -z "$PROFILE" && -z "$ONLY" && -z "$SKIP" && -f "$INSTALL_PROFILE_FILE" ]]; then
  installed_profile="$(<"$INSTALL_PROFILE_FILE")"
  case "$installed_profile" in ai|recommended|full|minimal|work) PROFILE="$installed_profile" ;; esac
fi

# Explicit custom selections retain the original package semantics.
if [[ -z "$PROFILE" && -z "$ONLY" && -z "$SKIP" && "$DOCTOR" == 0 ]]; then
  PROFILE=ai
fi


# --profile NAME — expand a named preset into extra SKIP steps (unioned with any
# --skip), reusing the SKIP machinery below. Mutually exclusive with --only. The
# preset→skip mapping is this file's own (step ids: prereqs brew runtimes shell
# docker git agents).
if [[ -n "$PROFILE" ]]; then
  [[ -n "$ONLY" ]] && die "choose either --profile or --only"
  case "$PROFILE" in
    ai)      PRESET_SKIP="docker" ;;
    full)    PRESET_SKIP="" ;;
    minimal) PRESET_SKIP="docker,agents" ;;
    recommended|work) PRESET_SKIP="docker" ;;
    *) die "unknown profile: '$PROFILE' (valid: ai recommended full minimal work)" ;;
  esac
  [[ -n "$PRESET_SKIP" ]] && SKIP="${SKIP:+$SKIP,}$PRESET_SKIP"
fi

_validate_ids() {
  local list="$1" tok id found valid="${STEP_IDS[*]}"
  [[ "$list" != ,* && "$list" != *, && "$list" != *,,* ]] \
    || die "empty step id in selector: '$list'"
  while [[ -n "$list" ]]; do
    tok="${list%%,*}"
    if [[ "$list" == *,* ]]; then list="${list#*,}"; else list=""; fi
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
  return 0
}

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
if [[ "$OFFLINE_PREVIEW" == 1 ]]; then
  [[ "$DOCTOR" == 0 ]] || die "offline preview cannot probe installed tools; use a local checkout for --doctor"
  printf 'Offline installation preview (no downloads, installs, or project creation).\n'
  printf 'Profile: %s\n' "${PROFILE:-custom}"
  printf 'LSK_PREVIEW_STEPS=%s\n' "$(selected | paste -sd, -)"
  if [[ "$PROFILE" == ai ]]; then
    printf 'Git, Node.js LTS/npm, Claude Code, Codex, safety hooks, and new-terminal PATH only.\n'
  else
    printf 'Advanced selection: %s\n' "$(selected | paste -sd, -)"
  fi
  printf 'Provider accounts and eligible subscription/access or API billing are separate.\n'
  printf 'Re-run without --dry-run to install. No login, agent launch, or prompt submission was performed.\n'
  exit 0
fi

_json_escape() {
  local value="$1" character escaped="" control_code index
  local length="${#value}"
  for ((index = 0; index < length; index++)); do
    character="${value:index:1}"
    case "$character" in
      \\) escaped="${escaped}"$'\\\\' ;;
      '"') escaped="${escaped}"$'\\"' ;;
      $'\b') escaped="${escaped}"$'\\b' ;;
      $'\f') escaped="${escaped}"$'\\f' ;;
      $'\n') escaped="${escaped}"$'\\n' ;;
      $'\r') escaped="${escaped}"$'\\r' ;;
      $'\t') escaped="${escaped}"$'\\t' ;;
      [[:cntrl:]])
        LC_CTYPE=C printf -v control_code '%d' "'$character"
        printf -v escaped '%s\\u%04x' "$escaped" "$control_code"
        ;;
      *) escaped="${escaped}${character}" ;;
    esac
  done
  _JSON_ESCAPED="$escaped"
}

_doctor_record() {
  local id="$1" label="$2" category="$3" state="$4" detail="$5" step="$6"
  [[ "$_DOCTOR_FORMAT" == "json" ]] || return 0

  _json_escape "$id"; id="$_JSON_ESCAPED"
  _json_escape "$label"; label="$_JSON_ESCAPED"
  _json_escape "$category"; category="$_JSON_ESCAPED"
  _json_escape "$state"; state="$_JSON_ESCAPED"
  _json_escape "$detail"; detail="$_JSON_ESCAPED"
  _json_escape "$step"; step="$_JSON_ESCAPED"
  _DOCTOR_JSON_ITEMS+=("{\"id\":\"$id\",\"label\":\"$label\",\"category\":\"$category\",\"state\":\"$state\",\"detail\":\"$detail\",\"step\":\"$step\"}")
  if [[ "$state" == "ok" ]]; then _DOCTOR_OK=$((_DOCTOR_OK + 1)); fi
  return 0
}


_doctor_print_json() {
  local generated_at item separator=""
  generated_at="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"

  _json_escape "$KIT_VERSION"; printf '{"version":"%s","generatedAt":"' "$_JSON_ESCAPED"
  _json_escape "$generated_at"; printf '%s","summary":{"ok":%d,"pathOnly":%d,"missing":%d},"items":[' \
    "$_JSON_ESCAPED" "$_DOCTOR_OK" "$_DOCTOR_PATHONLY" "$_DOCTOR_MISSING"
  for item in "${_DOCTOR_JSON_ITEMS[@]}"; do
    printf '%s%s' "$separator" "$item"
    separator=','
  done
  printf ']}\n'
}

ai_path() {
  local prefix
  prefix="$(brew_prefix)"
  export PATH="$prefix/opt/node@24/bin:$HOME/.local/bin:$prefix/bin:$PATH"
}

# Unlike the legacy inventory doctor, readiness requires a successful execution.
ai_check() {
  local tool version owner failed=0
  ai_path
  for tool in git node npm claude codex; do
    case "$tool" in
      git) owner=git ;;
      node|npm) owner=runtimes ;;
      *) owner=agents ;;
    esac
    if [[ "$DOCTOR" != 1 ]]; then
      selected | grep -qx "$owner" || { [[ "$tool" == git ]] && selected | grep -qx brew; } || continue
    fi
    if version="$(PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/zsh -lic '"$1" --version' -- "$tool" 2>&1)"; then
      if [[ "$DOCTOR" == 1 ]]; then
        _doctor_record "$tool" "$tool" tool ok "$version" "$owner"
      fi
      [[ "${_DOCTOR_FORMAT:-text}" != json ]] && ok "$tool: $version"
    else
      failed=1
      if [[ "$DOCTOR" == 1 ]]; then
        _doctor_record "$tool" "$tool" tool missing "$version" "$owner"
        _DOCTOR_MISSING=$((_DOCTOR_MISSING + 1))
      fi
      [[ "${_DOCTOR_FORMAT:-text}" != json ]] && warn "$tool is missing or cannot run. Re-run --profile ai to repair."
    fi
  done
  return "$failed"
}

if [[ "$DOCTOR" == 1 ]]; then
  _DOCTOR_FORMAT="$DOCTOR_FORMAT"
  if [[ "$PROFILE" == ai ]]; then
    _DOCTOR_MISSING=0; _DOCTOR_PATHONLY=0; _DOCTOR_OK=0; _DOCTOR_JSON_ITEMS=()
    result=0
    ai_check || result=1
    if safety_detail="$(node - "$HOME" 2>&1 <<'JS'
const fs = require('fs');
const path = require('path');
const home = process.argv[2];
const guard = path.join(home, '.local/share/lazy-starter-kit/ai-safety/shell-command-guard.js');
fs.accessSync(guard, fs.constants.R_OK);
const expected = `node "${guard.replace(/"/g, '\\"')}"`;
for (const file of ['.claude/settings.json', '.codex/hooks.json']) {
  const config = JSON.parse(fs.readFileSync(path.join(home, file), 'utf8'));
  if (!config.hooks?.PreToolUse?.some(group => group.matcher === 'Bash'
      && group.hooks?.some(hook => hook.type === 'command' && hook.command === expected))) {
    throw new Error(`AI safety hook is missing in ${file}`);
  }
}
JS
)"; then
      _doctor_record ai-safety "AI safety hooks" config ok "" agents
    else
      result=1
      _doctor_record ai-safety "AI safety hooks" config missing "$safety_detail" agents
      _DOCTOR_MISSING=$((_DOCTOR_MISSING + 1))
      [[ "$DOCTOR_FORMAT" == json ]] || warn "AI safety setup is incomplete. Re-run --profile ai."
    fi
    [[ "$DOCTOR_FORMAT" != json ]] || _doctor_print_json
    exit "$result"
  fi
  [[ "$DOCTOR_FORMAT" == text ]] || die "--doctor-json requires --profile ai (advanced inventory: --doctor)"
  doctor
fi

# ---------------------------------------------------------------------------
# Install log + results board. Every real run tees its full output to
# ~/Library/Logs/lazy-starter-kit/ and ends with a per-step ✅/❌/⏭ board, an
# automatic --doctor summary and one final line, so a first-time user can tell
# whether setup finished and what to do next. Dry-runs write no log.
# ---------------------------------------------------------------------------
KIT_LOG_FILE=""; KIT_TEE_PID=""; KIT_CURRENT_STEP=""
KIT_RESULT_IDS=(); KIT_RESULT_STATES=(); KIT_RESULT_NOTES=()
KIT_DOCTOR_LINE=""; KIT_DOCTOR_PROBLEMS=""; KIT_DOCTOR_ISSUES=0

kit_start_log() {
  [[ "$DRY_RUN" != "1" ]] || return 0
  local dir="${STARTER_KIT_LOG_DIR:-$HOME/Library/Logs/lazy-starter-kit}" fifo
  if ! mkdir -p "$dir" 2>/dev/null; then
    warn "could not create $dir; continuing without an install log"
    return 0
  fi
  KIT_LOG_FILE="$dir/install-$(date +%Y%m%d-%H%M%S).log"
  # A FIFO (not >(tee)) keeps the tee process waitable on bash 3.2.
  fifo="$(mktemp -u "${TMPDIR:-/tmp}/lazy-starter-kit-log.XXXXXX")"
  if ! mkfifo -m 600 "$fifo" 2>/dev/null; then
    warn "could not start the install log; continuing without it"
    KIT_LOG_FILE=""
    return 0
  fi
  exec 3>&1 4>&2
  tee -a "$KIT_LOG_FILE" <"$fifo" >&3 2>/dev/null &
  KIT_TEE_PID=$!
  exec >"$fifo" 2>&1
  rm -f "$fifo"
}

kit_finish_log() {
  [[ -n "$KIT_TEE_PID" ]] || return 0
  exec 1>&3 2>&4 3>&- 4>&-
  # Bounded: a daemon started by a step may still hold the pipe open.
  local waited=0
  while kill -0 "$KIT_TEE_PID" 2>/dev/null && [[ "$waited" -lt 50 ]]; do
    sleep 0.1; waited=$((waited + 1))
  done
  # Keep the log readable in TextEdit/Console: drop terminal color codes.
  kill -0 "$KIT_TEE_PID" 2>/dev/null \
    || perl -pi -e 's/\e\[[0-9;]*m//g' "$KIT_LOG_FILE" 2>/dev/null || true
}

kit_record() {
  KIT_RESULT_IDS+=("$1"); KIT_RESULT_STATES+=("$2"); KIT_RESULT_NOTES+=("${3:-}")
}

# kit_lookup <id> — set _KIT_STATE/_KIT_NOTE from the last record for <id>.
kit_lookup() {
  local i found=1
  for ((i = 0; i < ${#KIT_RESULT_IDS[@]}; i++)); do
    if [[ "${KIT_RESULT_IDS[i]}" == "$1" ]]; then
      _KIT_STATE="${KIT_RESULT_STATES[i]}"; _KIT_NOTE="${KIT_RESULT_NOTES[i]}"; found=0
    fi
  done
  return "$found"
}

kit_step_label() {
  case "$1" in
    precheck) echo "pre-flight check · 사전 점검" ;;
    prereqs)  echo "Xcode Command Line Tools + Homebrew" ;;
    brew)     echo "Homebrew packages · 패키지" ;;
    runtimes) echo "language runtimes · 언어 런타임" ;;
    shell)    echo "zsh + terminal config · 셸 설정" ;;
    docker)   echo "Docker (colima)" ;;
    git)      echo "Git config · Git 설정" ;;
    agents)   echo "AI agents (Claude Code, Codex)" ;;
    check)    echo "required commands run · 필수 명령 실행 확인" ;;
    *)        echo "setup · 설치 진행" ;;
  esac
}

kit_fix_hint() {
  case "$1" in
    precheck) echo "$KIT_PREFLIGHT_FIX" ;;
    prereqs)  echo "run ./install.sh --only prereqs from the Terminal app as an administrator · 터미널 앱에서 관리자 계정으로 다시 실행" ;;
    check)    echo "re-run ./install.sh --profile ai · 다시 실행 (diagnose: ./install.sh --profile ai --doctor)" ;;
    setup)    echo "re-run ./install.sh and check the log · 다시 실행하고 로그 확인" ;;
    *)        echo "re-run ./install.sh --only $1 · 다시 실행" ;;
  esac
}

# kit_run_doctor — run the read-only --doctor in a child process and keep a
# one-line summary plus its problem lines for the board.
kit_run_doctor() {
  local output status ok_count warn_count missing_count
  local -a args=(--doctor)
  [[ "$DRY_RUN" != "1" && "${STARTER_KIT_AUTO_DOCTOR:-1}" != "0" ]] || return 0
  if kit_lookup precheck; then return 0; fi
  if [[ "$PROFILE" == ai ]]; then
    # A partial AI selection must not probe tools the user chose not to install.
    if [[ "$(selected | tr '\n' ',')" != 'prereqs,brew,runtimes,shell,git,agents,' ]]; then
      KIT_DOCTOR_LINE="skipped for a partial selection (run ./install.sh --profile ai --doctor)"
      return 0
    fi
    args+=(--profile ai)
  elif [[ -n "$PROFILE" ]]; then
    args+=(--profile "$PROFILE")
  fi
  info "running ./install.sh ${args[*]} (read-only)…"
  status=0
  # The child must never inherit the launcher's ephemeral-checkout cleanup.
  output="$(env -u STARTER_KIT_EPHEMERAL_ROOT /bin/bash "$ROOT/install.sh" "${args[@]}" </dev/null 2>&1)" || status=$?
  ok_count="$(printf '%s\n' "$output" | grep -c '✓' || true)"
  warn_count="$(printf '%s\n' "$output" | grep -cE '^ +! ' || true)"
  missing_count="$(printf '%s\n' "$output" | grep -c '✗' || true)"
  KIT_DOCTOR_PROBLEMS="$(printf '%s\n' "$output" | grep -E '^ +(✗|!) ' | head -8 || true)"
  if [[ "$status" == 0 && "$warn_count" == 0 ]]; then
    KIT_DOCTOR_LINE="✅ all good · 이상 없음 (✓ $ok_count)"
  else
    KIT_DOCTOR_ISSUES=$((warn_count + missing_count))
    KIT_DOCTOR_LINE="⚠️  ✓ $ok_count · ! $warn_count · ✗ $missing_count — details · 자세히: ./install.sh ${args[*]}"
  fi
  # A custom --only/--skip run still gets the whole-kit inventory; say so.
  [[ -n "$PROFILE" ]] || KIT_DOCTOR_LINE="$KIT_DOCTOR_LINE (whole kit, not only selected steps · 선택한 단계가 아닌 전체 기준)"
}

kit_print_summary() {
  local status="$1" id mark note failed=0 failures="" is_step
  if [[ "$status" != 0 && -n "$KIT_CURRENT_STEP" ]]; then
    kit_record "$KIT_CURRENT_STEP" fail "${_KIT_LAST_ERROR:-stopped with exit code $status}"
    KIT_CURRENT_STEP=""
  fi
  if [[ "$status" != 0 && " ${KIT_RESULT_STATES[*]:-} " != *" fail "* ]]; then
    kit_record setup fail "${_KIT_LAST_ERROR:-stopped with exit code $status}"
  fi
  kit_run_doctor

  step "Install summary · 설치 결과"
  for id in precheck "${STEP_IDS[@]}" check setup; do
    is_step=0
    [[ " ${STEP_IDS[*]} " != *" $id "* ]] || is_step=1
    if kit_lookup "$id"; then
      :
    elif [[ "$is_step" == 1 ]]; then
      if selected | grep -qx "$id"; then
        _KIT_STATE=notrun; _KIT_NOTE="not run · 실행 안 됨"
      else
        _KIT_STATE=skip; _KIT_NOTE="skipped · 건너뜀"
      fi
    else
      continue
    fi
    note="$(kit_step_label "$id")"
    case "$_KIT_STATE" in
      ok)   mark="✅"; [[ "$DRY_RUN" != "1" ]] || note="$note (previewed · 미리보기)" ;;
      fail)
        mark="❌"; note="$note — $_KIT_NOTE"; failed=$((failed + 1))
        failures="${failures:+$failures; }$id → $(kit_fix_hint "$id")" ;;
      *)    mark="⏭ "; note="$note — $_KIT_NOTE" ;;
    esac
    printf '  %s %-9s %s\n' "$mark" "$id" "$note"
  done
  if [[ -n "$KIT_DOCTOR_LINE" ]]; then
    printf '  🩺 %-9s %s\n' doctor "$KIT_DOCTOR_LINE"
    [[ -z "$KIT_DOCTOR_PROBLEMS" ]] || printf '%s\n' "$KIT_DOCTOR_PROBLEMS" | sed 's/^ */       /'
  fi
  printf '\n'
  if [[ "$failed" -gt 0 ]]; then
    printf '%s❌ %s개 실패 · %s failed: %s%s\n' "$_C_BOLD$_C_RED" "$failed" "$failed" "$failures" "$_C_RESET"
  elif [[ "$DRY_RUN" == "1" ]]; then
    printf '%s🎉 미리보기 완료 · Preview complete — nothing was changed · 변경 없음%s\n' "$_C_BOLD$_C_GREEN" "$_C_RESET"
  else
    note=""
    [[ "$KIT_DOCTOR_ISSUES" == 0 ]] \
      || note=" — doctor: ${KIT_DOCTOR_ISSUES}개 확인 필요 · $KIT_DOCTOR_ISSUES to check"
    printf '%s🎉 설치 완료 · Installation complete%s%s\n' "$_C_BOLD$_C_GREEN" "$note" "$_C_RESET"
  fi
  [[ -z "$KIT_LOG_FILE" ]] || printf '📄 Log · 설치 로그: %s\n' "$KIT_LOG_FILE"
}

# shellcheck disable=SC2329 # invoked by the EXIT trap below
kit_on_exit() {
  local status=$?
  set +eu
  trap - EXIT
  kit_print_summary "$status"
  kit_finish_log
  if declare -F cleanup_ephemeral_root >/dev/null; then cleanup_ephemeral_root; fi
  exit "$status"
}

is_macos || die "This kit targets macOS only."
is_arm   || warn "Not Apple Silicon (arm64) — proceeding, but only tested on M-series."
cache_zsh_config_dir
kit_start_log
trap kit_on_exit EXIT
[[ "$DRY_RUN" == "1" ]] && warn "DRY-RUN: no changes will be made."

printf '%s\n' "$_C_BOLD== lazy-starter-kit v$KIT_VERSION ==$_C_RESET"
info "steps: $(selected | tr '\n' ' ')${PROFILE:+(profile: $PROFILE)}"
if selected | grep -qx agents; then
  info "Claude Code: an Anthropic account with an eligible subscription or API billing is required."
  info "Codex: an OpenAI account with eligible access or API billing is required. Provider usage may cost money."
  info "After installation: open a NEW terminal, run claude or codex, and follow that tool's sign-in and trust instructions."
  info "This installer does not log in or submit prompts; executable readiness does not verify account access."
fi


# ---------------------------------------------------------------------------
# Execute
# ---------------------------------------------------------------------------
# Stop before any change when Homebrew must be installed but cannot be.
if selected | grep -qx prereqs && ! homebrew_preflight; then
  kit_record precheck fail "$KIT_PREFLIGHT_REASON"
  exit 1
fi

KIT_INSTALL_FAILED=0
for id in $(selected); do
  file="$ROOT/scripts/$(step_file "$id")"
  fn="step_$id"
  [[ -f "$file" ]] || die "missing step file: $file"
  # shellcheck disable=SC1090
  source "$file"
  KIT_CURRENT_STEP="$id"; failed_before="$KIT_INSTALL_FAILED"
  "$fn"
  KIT_CURRENT_STEP=""
  if [[ "$KIT_INSTALL_FAILED" == 1 && "$failed_before" != 1 ]]; then
    kit_record "$id" fail "some packages failed to install (see the log) · 일부 패키지 설치 실패"
  else
    kit_record "$id" ok
  fi
done

if [[ "$PROFILE" == ai && "$DRY_RUN" != 1 ]]; then
  step "Checking required commands"
  if ai_check; then
    kit_record check ok
  else
    KIT_INSTALL_FAILED=1
    kit_record check fail "a required command is missing or cannot run · 필수 명령을 실행할 수 없음"
  fi
  if [[ "$KIT_INSTALL_FAILED" == 1 ]]; then
    printf 'LSK_AI_READINESS=action-needed\n'
    warn "Setup needs attention. Re-run ./install.sh --profile ai; diagnose with --profile ai --doctor."
    exit 1
  fi
  if [[ "$(selected | tr '\n' ',')" == 'prereqs,brew,runtimes,shell,git,agents,' ]]; then
    mkdir -p "$(dirname "$INSTALL_PROFILE_FILE")"
    printf 'ai\n' > "$INSTALL_PROFILE_FILE"
    printf 'LSK_AI_READINESS=ready\n'
    ok "Required commands run. Account sign-in and service access still need your approval."
    step "Your first coding session"
    info '1) Open a NEW terminal. Create an empty practice folder (existing projects stay untouched):'
    info '   practice="$(mktemp -d "$HOME/AI-Practice.XXXXXX")" && cd "$practice"'
    info '2) Run claude or codex. Sign in to that provider and review its folder-trust request yourself.'
    info '3) Paste a first prompt, review it, then send it yourself: "Create a simple introduction webpage in this empty practice folder. Explain the plan first and do not change files outside this folder."'
    info 'Service access and billing depend on your account; this check did not authenticate or send a prompt.'
  else
    printf 'LSK_AI_READINESS=selected-ready\n'
    info "Selected tools checked; the complete AI environment was not verified."
  fi
  exit 0
fi


step "Done."
if [[ "$DRY_RUN" == "1" ]]; then
  info "That was a dry run — re-run without --dry-run to apply."
else
  step "Next steps"
  zshrc="$(zsh_config_file .zshrc)"
  info "1) Open a NEW terminal (or: source $(shell_quote "$zshrc")) so PATH + prompt load."
  if [[ "$KIT_INSTALL_FAILED" == "0" ]] && selected | grep -x agents >/dev/null; then
    info "Check the agents in that terminal: codex --version and claude --version."
    info "Then cd into a project you trust and run codex or claude; follow its sign-in prompts."
  fi
  if command -v gh >/dev/null 2>&1 && ! gh auth status >/dev/null 2>&1; then
    info "2) Sign in to GitHub:  gh auth login   (also sets your git identity)"
  fi
  info "Set your terminal font to 'JetBrainsMono Nerd Font' for prompt icons."

  # --- optional: ask for a GitHub star (opt-in, default No) ---------------
  # Interactive runs only — --yes and non-interactive/CI never see this, and
  # nothing is ever starred without an explicit 'y' (see confirm_default_no).
  repo_slug="${REPO_URL#https://github.com/}"; repo_slug="${repo_slug%.git}"
  if [[ "$KIT_INSTALL_FAILED" == "0" ]] \
     && have gh && gh auth status >/dev/null 2>&1 \
     && ! gh api "user/starred/$repo_slug" >/dev/null 2>&1; then
    if confirm_default_no "Enjoyed the setup? Star $repo_slug on GitHub? ⭐"; then
      gh api -X PUT "user/starred/$repo_slug" >/dev/null 2>&1 \
        && ok "thanks for the star! ⭐" \
        || info "couldn't star from here — https://github.com/$repo_slug"
    fi
  fi
fi
if [[ "$KIT_INSTALL_FAILED" == "1" ]]; then
  warn "setup finished with package errors — re-run ./install.sh --only brew, then use ./install.sh --doctor for remaining issues"
  exit 1
fi
if [[ "$DRY_RUN" != 1 ]]; then
  case "$PROFILE:$(selected | tr '\n' ',')" in
    recommended:prereqs,brew,runtimes,shell,git,agents,|full:prereqs,brew,runtimes,shell,docker,git,agents,|minimal:prereqs,brew,runtimes,shell,git,|work:prereqs,brew,runtimes,shell,git,agents,)
      mkdir -p "$(dirname "$INSTALL_PROFILE_FILE")"
      printf '%s\n' "$PROFILE" > "$INSTALL_PROFILE_FILE" ;;
  esac
fi
exit 0
