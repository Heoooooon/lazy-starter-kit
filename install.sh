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

REPO_URL="${STARTER_KIT_REPO:-https://github.com/Heoooooon/lazy-starter-kit.git}"
CLONE_DIR="${STARTER_KIT_DIR:-$HOME/.lazy-starter-kit}"
# STARTER_KIT_BRANCH pins an explicit ref (a tag like v0.9.0, or "main" to ride
# the development branch). Left unset, the bootstrap resolves the newest release
# tag instead of main — a fresh machine should get a ref CI actually verified
# end-to-end, not whatever landed on main minutes ago.
REPO_BRANCH="${STARTER_KIT_BRANCH:-}"
REPO_COMMIT="${STARTER_KIT_COMMIT:-}"
EPHEMERAL_ROOT="${STARTER_KIT_EPHEMERAL_ROOT:-}"
if [[ -n "$REPO_COMMIT" && ! "$REPO_COMMIT" =~ ^[0-9a-f]{40}$ ]]; then
  echo "Invalid STARTER_KIT_COMMIT: expected a full 40-character commit SHA." >&2
  exit 1
fi

# kit_latest_ref — newest vX.Y.Z tag on the remote; "main" when a repo has no
# release tags yet (forks, first-ever run before v0.1.0).
kit_latest_ref() {
  local tag
  tag="$(git ls-remote --tags --refs --sort=-v:refname "$REPO_URL" 'v*' 2>/dev/null \
         | head -1 | sed 's#.*refs/tags/##')"
  if [[ -n "$tag" ]]; then echo "$tag"; else echo main; fi
}

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
  if [[ "$BOOTSTRAP_PREVIEW" == 1 ]]; then
    printf '%s\n' "${dir:-$PWD}"
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
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)/$(basename "${BASH_SOURCE[0]}")"
fi
# If we bootstrapped (cloned), hand off to the cloned copy with the original args.
if [[ "$SELF" != "$ROOT/install.sh" && -f "$ROOT/install.sh" ]]; then
  exec bash "$ROOT/install.sh" "$@"
fi

OFFLINE_PREVIEW=0
if [[ -f "$ROOT/scripts/lib.sh" ]]; then
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
  _doctor_managed "$_DOCTOR_ZSHRC"    "lazy-starter-kit:main"
  _doctor_managed "$_DOCTOR_ZPROFILE" "lazy-starter-kit:brew"
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
# updated step files rather than the stale ones already on disk.
# ---------------------------------------------------------------------------
DO_UPDATE=0; PASS_ARGS=()
for arg in "$@"; do
  if [[ "$arg" == "--update" ]]; then DO_UPDATE=1; else PASS_ARGS+=("$arg"); fi
done
if [[ "$DO_UPDATE" == "1" ]]; then
  [[ "$OFFLINE_PREVIEW" == 0 ]] || die "offline preview cannot update a checkout"
  update_kit "$ROOT"
  exec bash "$ROOT/install.sh" ${PASS_ARGS[@]+"${PASS_ARGS[@]}"}
fi

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------
ONLY=""; SKIP=""; PROFILE=""; DOCTOR=0; DOCTOR_FORMAT=text
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
    --no-agents) SKIP="${SKIP:+$SKIP,}agents" ;;
    --doctor)    DOCTOR=1 ;;
    --doctor-json) DOCTOR=1; DOCTOR_FORMAT=json ;;
    --list)      printf '%s\n' "${STEP_IDS[@]}"; exit 0 ;;
    -V|--version) echo "lazy-starter-kit $KIT_VERSION"; exit 0 ;;
    -h|--help)   usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
  shift
done

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

is_macos || die "This kit targets macOS only."
is_arm   || warn "Not Apple Silicon (arm64) — proceeding, but only tested on M-series."
[[ "$DRY_RUN" == "1" ]] && warn "DRY-RUN: no changes will be made."
cache_zsh_config_dir

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
KIT_INSTALL_FAILED=0
for id in $(selected); do
  file="$ROOT/scripts/$(step_file "$id")"
  fn="step_$id"
  [[ -f "$file" ]] || die "missing step file: $file"
  # shellcheck disable=SC1090
  source "$file"
  "$fn"
done

if [[ "$PROFILE" == ai && "$DRY_RUN" != 1 ]]; then
  step "Checking required commands"
  ai_check || KIT_INSTALL_FAILED=1
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
